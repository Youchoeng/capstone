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

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, HTTPException, File, UploadFile, Query
from sqlmodel import Session
from database import engine, get_session
from models.user import User
from services.push import send_push_notification
from crud.chat import (
    create_chat_message,
    delete_chat_message,
    get_chat_history,
    mark_messages_as_read,
    mark_peer_messages_delivered,
    get_inbox,
    log_room_event,
)
from pydantic import BaseModel
import asyncio
import json
from datetime import datetime, timezone
import os
import shutil
import uuid


router = APIRouter(prefix="/chat", tags=["chat"])


class ConnectionManager:
    """단일 프로세스 메모리. 정수형 강제 변환으로 str/int 타입 미스매치 완벽 방지"""

    def __init__(self):
        self.active_connections: dict[int, WebSocket] = {}
        # user_id → 현재 화면에서 보고 있는 방 (group_id, peer_id)
        self.active_rooms: dict[int, tuple[int, int] | None] = {}

    async def connect(self, user_id: int, websocket: WebSocket):
        u_id = int(user_id)
        await websocket.accept()
        old = self.active_connections.get(u_id)
        if old is not None:
            try:
                await old.close()
            except Exception:
                pass
        self.active_connections[u_id] = websocket
        self.active_rooms.setdefault(u_id, None)

    def disconnect(self, user_id: int, websocket: WebSocket | None = None):
        u_id = int(user_id)
        current = self.active_connections.get(u_id)
        if current is None:
            return
        if websocket is None or current is websocket:
            self.active_connections.pop(u_id, None)
            self.active_rooms.pop(u_id, None)

    def enter_room(self, user_id: int, group_id: int, peer_id: int):
        # 🛠️ 들어오는 모든 ID 자원을 int로 강제 정형화하여 저장
        self.active_rooms[int(user_id)] = (int(group_id), int(peer_id))

    def leave_room(self, user_id: int):
        self.active_rooms[int(user_id)] = None

    def get_active_room(self, user_id: int) -> tuple[int, int] | None:
        return self.active_rooms.get(int(user_id))

    def is_viewing_room(self, user_id: int, group_id: int, peer_id: int) -> bool:
        """대조 시에도 양쪽 모두 정수형으로 캐스팅 후 튜플 비교 진행"""
        try:
            active = self.get_active_room(int(user_id))
            if active is None:
                return False
            return active == (int(group_id), int(peer_id))
        except Exception:
            return False

    async def send_personal(self, user_id: int, payload: dict) -> bool:
        u_id = int(user_id)
        ws = self.active_connections.get(u_id)
        if ws is None:
            return False
        try:
            await ws.send_json(payload)
            return True
        except Exception:
            self.active_connections.pop(u_id, None)
            self.active_rooms.pop(u_id, None)
            return False

    def is_online(self, user_id: int) -> bool:
        return int(user_id) in self.active_connections

manager = ConnectionManager()


def _serialize_history(messages: list) -> list[dict]:
    out = []
    for m in messages:
        ts = m.get("timestamp")
        if hasattr(ts, "isoformat"):
            ts = ts.isoformat()
        out.append({**m, "timestamp": ts})
    return out


async def _handle_enter_room(websocket: WebSocket, user_id: int, peer_id: int, group_id: int):
    """채팅방 진입: 활성화 + 이벤트 기록 + DB 히스토리 전송 + 읽음 처리.

    이벤트는 chat_room_events 테이블에만 기록되며,
    ChatMessage 테이블(히스토리)에는 절대 기록되지 않는다.
    """
    manager.enter_room(user_id, group_id, peer_id)

    with Session(engine) as session:
        # ① 입장 이벤트를 전용 테이블에 기록 (ChatMessage 와 완전 분리)
        log_room_event(session, event_type="enter", user_id=user_id, peer_id=peer_id)

        # ② 순수 채팅 메시지만 조회 — 이벤트 로그는 포함되지 않음
        history = get_chat_history(session, user_id, peer_id, group_id)
        read_count = mark_messages_as_read(session, user_id, peer_id, group_id)
        mark_peer_messages_delivered(session, user_id, peer_id)

    await websocket.send_json({
        "type": "history",
        "group_id": group_id,
        "peer_id": peer_id,
        "messages": _serialize_history(history),
    })

    if read_count > 0:
        if manager.is_online(peer_id):
            await manager.send_personal(peer_id, {
                "type": "messages_read",
                "group_id": group_id,
                "peer_id": user_id,
            })


async def _handle_send(websocket: WebSocket, user_id: int, data: dict):
    client_msg_id = data.get("client_msg_id")
    receiver_id = data.get("receiver_id")
    group_id = data.get("group_id", 0)
    content = data.get("content")
    message_type = data.get("message_type") or "text"
    media_url = data.get("media_url")
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

        try:
            sent_at_dt = datetime.fromisoformat(sent_at.replace("Z", "+00:00"))
        except (ValueError, TypeError, AttributeError):
            sent_at_dt = datetime.now(timezone.utc)

        receiver_online = manager.is_online(receiver_id)
        receiver_in_room = manager.is_viewing_room(receiver_id, group_id, user_id)
        
        msg_status = "read" if receiver_in_room else "sent"

        # 1. DB에 메시지 먼저 저장하여 고유 ID(PK) 생성
        db_msg = create_chat_message(
            session=session,
            content=content,
            sender_id=user_id,
            receiver_id=receiver_id,
            group_id=group_id,
            client_msg_id=str(client_msg_id) if client_msg_id else "",
            sent_at=sent_at_dt,
            is_delivered=False,  # 임시로 False 저장 후 전송 완료 시 업데이트
            is_read=receiver_in_room,
            message_type=message_type,
            media_url=media_url,
        )

        db_id = db_msg.id

        # 2. 전송할 페이로드 구성 (DB 고유 ID 포함)
        forward_payload = {
            "type": "message",
            "id": db_id,
            "group_id": group_id,
            "client_msg_id": client_msg_id,
            "sender_id": user_id,
            "sender_nickname": sender_nickname,
            "content": content,
            "message_type": message_type,
            "media_url": media_url,
            "sent_at": sent_at,
        }

        delivered = False
        if receiver_online:
            delivered = await manager.send_personal(receiver_id, forward_payload)
            if delivered:
                # 3. 실시간 전송 성공 시 전달 완료 상태로 갱신
                db_msg.is_delivered = True
                session.add(db_msg)
                session.commit()

        receiver: User | None = session.get(User, receiver_id)
        fcm_token = receiver.fcm_token if receiver else None
# [수정] 상대방이 현재 대화방을 보고 있지 않을 때만 (오프라인이거나 다른 화면일 때) FCM 푸시 발송
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
                        "group_id": str(group_id),
                        "client_msg_id": str(client_msg_id) if client_msg_id else "",
                        "sender_id": str(user_id),
                        "sender_nickname": sender_nickname,
                        "content": content,
                        "msg_type": message_type,
                        "media_url": media_url or "",
                        "sent_at": sent_at,
                    },
                )
                pushed = True
            except Exception as e:
                print(f"⚠️ [chat] FCM 전송 실패: {e}")

        # 송신자에게 최종 상태 피드백 반환
        await websocket.send_json({
            "type": "ack",
            "client_msg_id": client_msg_id,
            "delivered": delivered,
            "status": msg_status,
            "pushed": pushed,
        })


async def _handle_delete_message(websocket: WebSocket, user_id: int, data: dict):
    client_msg_id = data.get("client_msg_id")
    peer_id = data.get("peer_id")
    
    if not (isinstance(client_msg_id, str) and isinstance(peer_id, int)):
        await websocket.send_json({
            "type": "error",
            "client_msg_id": client_msg_id,
            "reason": "invalid_payload",
        })
        return

    with Session(engine) as session:
        # DB에 삭제 상태 반영 (Soft Delete)
        success = delete_chat_message(session, client_msg_id, user_id)
        
    if success:
        payload = {
            "type": "delete_message",
            "client_msg_id": client_msg_id,
            "peer_id": user_id,
        }
        # 상대방이 방에 접속해 있으면 릴레이
        if manager.is_online(peer_id):
            await manager.send_personal(peer_id, payload)
        
        # 내 다른 기기 혹은 자신에게 확인차 전송
        await websocket.send_json(payload)
    else:
        await websocket.send_json({
            "type": "error",
            "client_msg_id": client_msg_id,
            "reason": "delete_failed",
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
                try:
                    group_id = int(data.get("group_id", 0))
                    peer_id = int(data.get("peer_id"))
                except (ValueError, TypeError):
                    await websocket.send_json({"type": "error", "reason": "invalid_peer_or_group_id"})
                    continue
                
                manager.enter_room(user_id, group_id, peer_id)

                try:
                    await _handle_enter_room(websocket, user_id, peer_id, group_id)
                except Exception as e:
                    print(f"⚠️ [chat] enter_room 오류: {e}")
                    await websocket.send_json({"type": "error", "reason": "enter_room_failed"})
                continue

            if msg_type == "leave_room":
                manager.leave_room(user_id)
                # 퇴장 이벤트를 전용 테이블에 기록 (ChatMessage 와 완전 분리)
                '''
                peer_id_for_log = data.get("peer_id")
                with Session(engine) as session:
                    log_room_event(
                        session,
                        event_type="leave",
                        user_id=user_id,
                        peer_id=peer_id_for_log if isinstance(peer_id_for_log, int) else None,
                    )
                '''
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
                
            if msg_type == "delete_message":
                try:
                    await _handle_delete_message(websocket, user_id, data)
                except Exception as e:
                    print(f"⚠️ [chat] delete_message 처리 오류: {e}")
                    await websocket.send_json({
                        "type": "error",
                        "client_msg_id": data.get("client_msg_id"),
                        "reason": "delete_failed",
                    })
                continue

            await websocket.send_json({"type": "error", "reason": "unknown_type"})

    except WebSocketDisconnect:
        manager.disconnect(user_id, websocket)
        # 비정상/정상 연결 종료 이벤트 기록
        try:
            with Session(engine) as session:
                log_room_event(session, event_type="disconnect", user_id=user_id)
        except Exception:
            pass
    except Exception as e:
        manager.disconnect(user_id, websocket)
        # 오류로 인한 연결 종료 이벤트 기록
        try:
            with Session(engine) as session:
                log_room_event(session, event_type="disconnect", user_id=user_id)
        except Exception:
            pass
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
        "active_room": manager.get_active_room(user_id),
    }


@router.get("/history/{user_id}/{peer_id}")
def chat_history(
    user_id: int,
    peer_id: int,
    group_id: int = Query(...),
    limit: int = 100,
    session: Session = Depends(get_session),
):
    """REST 로 히스토리 조회 (WS enter_room 과 동일 데이터)"""
    return _serialize_history(get_chat_history(session, user_id, peer_id, group_id, limit=limit))


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


@router.post("/upload")
async def upload_chat_image(file: UploadFile = File(...)):
    """채팅방에서 사용할 이미지 업로드 엔드포인트. 
    로컬 /uploads 폴더에 저장하고 URL을 반환한다."""
    try:
        # 파일 확장자 추출 및 새 이름 생성
        ext = file.filename.split('.')[-1] if '.' in file.filename else 'jpg'
        new_filename = f"chat_{uuid.uuid4().hex}.{ext}"
        
        # uploads 디렉토리가 없으면 생성
        upload_dir = "uploads"
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)
            
        file_path = os.path.join(upload_dir, new_filename)
        
        # 파일 저장
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # 프론트엔드가 접근할 수 있는 URL 반환 (main.py에서 /uploads 로 StaticFiles 마운트 되어있음)
        return {"ok": True, "url": f"/uploads/{new_filename}"}
        
    except Exception as e:
        print(f"❌ [chat] 파일 업로드 실패: {e}")
        raise HTTPException(status_code=500, detail="이미지 업로드에 실패했습니다.")
