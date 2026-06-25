"""
1:1 채팅 WebSocket 라우터

설계 원칙
---------
- 모든 메시지는 서버 DB(ChatMessage)에 저장된다.
- WebSocket 은 앱 로그인 후 유지해도 되고, **활성 채팅방**은 enter_room / leave_room 으로 구분한다.
- 수신자가 해당 송신자와의 채팅방을 **활성(enter_room)** 상태로 보고 있으면 → WS 즉시 전달, FCM 없음.
- 수신자가 채팅방을 나갔거나(leave_room) WS 미접속이면 → DB 저장 + FCM 푸시.
- 채팅방 재진입(enter_room) 시 → DB 히스토리를 WS 로 내려주고 읽음 처리.

WebSocket 페이로드
------------------
Client → Server:
  { "type": "enter_room", "peer_id": 2 }
  { "type": "leave_room" }
  { "type": "send", "client_msg_id": "uuid", "receiver_id": 2, "content": "...", "sent_at": "..." }
  { "type": "ping" }

Server → Client:
  { "type": "history", "peer_id": 2, "messages": [...] }
  { "type": "message", "client_msg_id": "...", "sender_id": 1, "sender_nickname": "...", "content": "...", "sent_at": "..." }
  { "type": "ack", "client_msg_id": "...", "delivered": true, "pushed": false }
  { "type": "read_receipt", "peer_id": 2, "count": 3 }
  { "type": "pong" }
"""

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException
from sqlmodel import Session
from database import engine, get_session
from models.user import User
from services.push import send_push_notification
from crud.chat import (
    create_chat_message,
    get_chat_history,
    mark_messages_as_read,
    mark_peer_messages_delivered,
    get_inbox,
)
from pydantic import BaseModel
import asyncio
import json
from datetime import datetime, timezone


router = APIRouter(prefix="/chat", tags=["chat"])


class ConnectionManager:
    """단일 프로세스 메모리. 스케일아웃 시 Redis Pub/Sub 등으로 교체."""

    def __init__(self):
        self.active_connections: dict[int, WebSocket] = {}
        # user_id → 현재 화면에서 보고 있는 상대 internal_id (None = 비활성)
        self.active_peers: dict[int, int | None] = {}

    async def connect(self, user_id: int, websocket: WebSocket):
        await websocket.accept()
        old = self.active_connections.get(user_id)
        if old is not None:
            try:
                await old.close()
            except Exception:
                pass
        self.active_connections[user_id] = websocket
        self.active_peers.setdefault(user_id, None)

    def disconnect(self, user_id: int, websocket: WebSocket | None = None):
        current = self.active_connections.get(user_id)
        if current is None:
            return
        if websocket is None or current is websocket:
            self.active_connections.pop(user_id, None)
            self.active_peers.pop(user_id, None)

    def enter_room(self, user_id: int, peer_id: int):
        self.active_peers[user_id] = peer_id

    def leave_room(self, user_id: int):
        self.active_peers[user_id] = None

    def get_active_peer(self, user_id: int) -> int | None:
        return self.active_peers.get(user_id)

    def is_viewing_peer(self, user_id: int, peer_id: int) -> bool:
        return self.get_active_peer(user_id) == peer_id

    async def send_personal(self, user_id: int, payload: dict) -> bool:
        ws = self.active_connections.get(user_id)
        if ws is None:
            return False
        try:
            await ws.send_json(payload)
            return True
        except Exception:
            self.active_connections.pop(user_id, None)
            self.active_peers.pop(user_id, None)
            return False

    def is_online(self, user_id: int) -> bool:
        return user_id in self.active_connections


manager = ConnectionManager()


def _serialize_history(messages: list) -> list[dict]:
    out = []
    for m in messages:
        ts = m.get("timestamp")
        if hasattr(ts, "isoformat"):
            ts = ts.isoformat()
        out.append({**m, "timestamp": ts})
    return out


async def _handle_enter_room(websocket: WebSocket, user_id: int, peer_id: int):
    """채팅방 진입: 활성화 + DB 히스토리 전송 + 읽음 처리"""
    manager.enter_room(user_id, peer_id)

    with Session(engine) as session:
        history = get_chat_history(session, user_id, peer_id)
        read_count = mark_messages_as_read(session, user_id, peer_id)
        mark_peer_messages_delivered(session, user_id, peer_id)

    await websocket.send_json({
        "type": "history",
        "peer_id": peer_id,
        "messages": _serialize_history(history),
    })

    if read_count > 0:
        await manager.send_personal(peer_id, {
            "type": "read_receipt",
            "peer_id": user_id,
            "count": read_count,
        })


async def _handle_send(websocket: WebSocket, user_id: int, data: dict):
    client_msg_id = data.get("client_msg_id")
    receiver_id = data.get("receiver_id")
    content = data.get("content")
    sent_at = data.get("sent_at") or datetime.now(timezone.utc).isoformat()

    if not (isinstance(receiver_id, int) and isinstance(content, str) and content):
        await websocket.send_json({
            "type": "error",
            "client_msg_id": client_msg_id,
            "reason": "invalid_payload",
        })
        return

    with Session(engine) as session:
        sender: User | None = session.get(User, user_id)
        sender_nickname = sender.nickname if sender else ""

        forward_payload = {
            "type": "message",
            "client_msg_id": client_msg_id,
            "sender_id": user_id,
            "sender_nickname": sender_nickname,
            "content": content,
            "sent_at": sent_at,
        }

        # 상대가 이 채팅방을 활성 상태로 보고 있을 때만 WS 실시간 전달
        receiver_in_room = manager.is_viewing_peer(receiver_id, user_id)
        delivered = False
        if receiver_in_room:
            delivered = await manager.send_personal(receiver_id, forward_payload)

        try:
            sent_at_dt = datetime.fromisoformat(sent_at.replace("Z", "+00:00"))
        except (ValueError, TypeError, AttributeError):
            sent_at_dt = datetime.now(timezone.utc)

        create_chat_message(
            session=session,
            content=content,
            sender_id=user_id,
            receiver_id=receiver_id,
            client_msg_id=str(client_msg_id) if client_msg_id else "",
            sent_at=sent_at_dt,
            is_delivered=delivered,
        )

        receiver: User | None = session.get(User, receiver_id)
        fcm_token = receiver.fcm_token if receiver else None

    pushed = False
    if not receiver_in_room and fcm_token:
        try:
            await asyncio.to_thread(
                send_push_notification,
                token=fcm_token,
                title=sender_nickname or "새 메시지",
                body=content,
                data={
                    "type": "chat_message",
                    "client_msg_id": str(client_msg_id) if client_msg_id else "",
                    "sender_id": str(user_id),
                    "sender_nickname": sender_nickname,
                    "content": content,
                    "sent_at": sent_at,
                },
            )
            pushed = True
        except Exception as e:
            print(f"⚠️ [chat] FCM 전송 실패: {e}")

    await websocket.send_json({
        "type": "ack",
        "client_msg_id": client_msg_id,
        "delivered": delivered,
        "pushed": pushed,
    })


@router.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int):
    """
    1:1 채팅 WebSocket. user_id = User.internal_id.

    - 연결만으로는 비활성. Personal_Chat_Screen 진입 시 enter_room, 이탈 시 leave_room.
    - 재진입 시 enter_room 이 DB 히스토리를 type=history 로 내려준다.
    """
    await manager.connect(user_id, websocket)

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "reason": "invalid_json"})
                continue

            msg_type = data.get("type")

            if msg_type == "ping":
                await websocket.send_json({"type": "pong"})
                continue

            if msg_type == "enter_room":
                peer_id = data.get("peer_id")
                if not isinstance(peer_id, int):
                    await websocket.send_json({"type": "error", "reason": "invalid_peer_id"})
                    continue
                try:
                    await _handle_enter_room(websocket, user_id, peer_id)
                except Exception as e:
                    print(f"⚠️ [chat] enter_room 오류: {e}")
                    await websocket.send_json({"type": "error", "reason": "enter_room_failed"})
                continue

            if msg_type == "leave_room":
                manager.leave_room(user_id)
                await websocket.send_json({"type": "room_left"})
                continue

            if msg_type == "send":
                try:
                    await _handle_send(websocket, user_id, data)
                except Exception as e:
                    print(f"⚠️ [chat] send 처리 오류: {e}")
                    await websocket.send_json({
                        "type": "error",
                        "client_msg_id": data.get("client_msg_id"),
                        "reason": "send_failed",
                    })
                continue

            await websocket.send_json({"type": "error", "reason": "unknown_type"})

    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
    except Exception as e:
        manager.disconnect(user_id, websocket)
        try:
            await websocket.close()
        except Exception:
            pass
        print(f"❌ [chat] WS 처리 중 오류: {e}")


@router.get("/online/{user_id}")
def is_user_online(user_id: int):
    return {
        "user_id": user_id,
        "online": manager.is_online(user_id),
        "active_peer_id": manager.get_active_peer(user_id),
    }


@router.get("/history/{user_id}/{peer_id}")
def chat_history(
    user_id: int,
    peer_id: int,
    limit: int = 100,
    session: Session = Depends(get_session),
):
    """REST 로 히스토리 조회 (WS enter_room 과 동일 데이터)"""
    return _serialize_history(get_chat_history(session, user_id, peer_id, limit=limit))


@router.get("/inbox/{user_id}")
def chat_inbox(
    user_id: int,
    session: Session = Depends(get_session),
):
    """쪽지 수신함 — 나에게 온 메시지를 발신자별로 그룹화하여 반환.

    폴링 방식으로 채팅창 밖에서도 새 쪽지 개수를 확인할 수 있다.
    """
    return get_inbox(session, user_id)


class FcmTokenIn(BaseModel):
    user_id: int
    fcm_token: str


@router.post("/fcm-token")
def register_fcm_token(
    payload: FcmTokenIn,
    session: Session = Depends(get_session),
):
    user: User | None = session.get(User, payload.user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="유저를 찾을 수 없습니다.")
    user.fcm_token = payload.fcm_token
    session.add(user)
    session.commit()
    return {"ok": True}
