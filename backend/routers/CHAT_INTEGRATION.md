# 1:1 채팅 통합 가이드 (WebSocket + DB + FCM)

## 핵심 원칙

| 상태 | 조건 | 수신 방식 |
|------|------|-----------|
| **활성** | `enter_room` 으로 해당 `peer_id` 채팅방에 있음 | WS `message` 즉시 전달, **FCM 없음** |
| **비활성** | `leave_room` 했거나, WS 미접속 | DB 저장 + **FCM 푸시** |
| **재진입** | `enter_room` 다시 호출 | DB 히스토리를 WS `history` 로 전송, 읽음 처리 |

- 메시지는 **항상 서버 DB**(`ChatMessage`)에 저장됩니다.
- 7일 지난 메시지는 `main.py` 백그라운드 태스크가 자동 삭제합니다.
- `ConnectionManager` 는 단일 프로세스 메모리입니다. uvicorn 멀티 워커 시 Redis Pub/Sub 교체가 필요합니다.

## 클라이언트 연동 순서

1. 로그인 후 FCM 토큰 등록: `POST /chat/fcm-token`
2. 앱 전역 WebSocket 연결: `ws://host/chat/ws/{my_internal_id}`
3. **채팅 화면 진입** → `{"type":"enter_room","peer_id":<상대 internal_id>}`
4. **채팅 화면 이탈** → `{"type":"leave_room"}` (이후 상대 메시지는 푸시)
5. 메시지 전송 → `{"type":"send", ...}`

## WebSocket 페이로드

### Client → Server

```json
{ "type": "enter_room", "peer_id": 2 }
{ "type": "leave_room" }
{ "type": "send", "client_msg_id": "uuid", "receiver_id": 2, "content": "안녕!", "sent_at": "2026-04-28T01:23:45Z" }
{ "type": "ping" }
```

### Server → Client

```json
{ "type": "history", "peer_id": 2, "messages": [
    { "id": 1, "content": "...", "sender_id": 1, "receiver_id": 2, "is_read": true, "timestamp": "...", "sender_name": "홍길동" }
]}
{ "type": "message", "client_msg_id": "uuid", "sender_id": 1, "sender_nickname": "홍길동", "content": "안녕!", "sent_at": "..." }
{ "type": "ack", "client_msg_id": "uuid", "delivered": true, "pushed": false }
{ "type": "read_receipt", "peer_id": 2, "count": 3 }
{ "type": "room_left" }
{ "type": "pong" }
```

## REST 보조 API

| Method | Path | 설명 |
|--------|------|------|
| GET | `/chat/history/{user_id}/{peer_id}?limit=100` | 히스토리 (WS `history` 와 동일) |
| GET | `/chat/online/{user_id}` | WS 접속 여부 + `active_peer_id` |
| POST | `/chat/fcm-token` | FCM 토큰 등록 |

## FCM (비활성 시만)

```json
{
  "type": "chat_message",
  "client_msg_id": "uuid",
  "sender_id": "1",
  "sender_nickname": "홍길동",
  "content": "안녕!",
  "sent_at": "2026-04-28T01:23:45+00:00"
}
```

포그라운드에서 같은 채팅방을 보고 있으면 서버가 FCM을 보내지 않습니다. 다른 화면이면 `leave_room` 상태이므로 푸시가 옵니다.

## 백엔드 파일

- `routers/chat.py` — WS, 활성/비활성 방, FCM 조건부 발송
- `crud/chat.py` — 저장, 히스토리, 읽음, 전달 상태
- `models/chat.py` — `ChatMessage` 테이블
- `services/push.py` — FCM

## 운영 체크리스트

1. `backend/firebase-key.json` 배치
2. `pip install -r requirements.txt` 후 `uvicorn main:app --reload` (워커 1개 권장)
3. WS 인증: 운영 시 query `?token=` 으로 JWT 검증 후 `user_id` 일치 확인 권장
4. Flutter: 화면 `initState` → `enter_room`, `dispose` → `leave_room`
