from sqlmodel import Session, select
from models.chat import ChatMessage
from datetime import datetime, timezone, timedelta


def create_chat_message(
    session: Session,
    content: str,
    sender_id: int,
    receiver_id: int,
    client_msg_id: str = "",
    sent_at: datetime | None = None,
    is_delivered: bool = False,
):
    """채팅 메시지를 DB에 저장."""
    db_msg = ChatMessage(
        content=content,
        sender_id=sender_id,
        receiver_id=receiver_id,
        client_msg_id=client_msg_id,
        timestamp=sent_at or datetime.now(timezone.utc),
        is_read=False,
        is_delivered=is_delivered,
    )
    session.add(db_msg)
    session.commit()
    session.refresh(db_msg)
    return db_msg


def get_pending_messages(session: Session, receiver_id: int) -> list[ChatMessage]:
    """수신자가 아직 전달받지 못한 메시지들을 시간순으로 조회"""
    statement = (
        select(ChatMessage)
        .where(
            ChatMessage.receiver_id == receiver_id,
            ChatMessage.is_delivered == False,
        )
        .order_by(ChatMessage.timestamp.asc())
    )
    return list(session.exec(statement).all())


def mark_messages_delivered(session: Session, message_ids: list[int]):
    """메시지들을 전달 완료 상태로 변경"""
    if not message_ids:
        return
    statement = select(ChatMessage).where(ChatMessage.id.in_(message_ids))
    msgs = session.exec(statement).all()
    for m in msgs:
        m.is_delivered = True
    session.add_all(msgs)
    session.commit()


def mark_peer_messages_delivered(
    session: Session, receiver_id: int, sender_id: int
) -> int:
    """특정 상대와의 대화 중 아직 WS로 전달되지 않은 메시지를 전달 완료로 표시"""
    statement = select(ChatMessage).where(
        ChatMessage.receiver_id == receiver_id,
        ChatMessage.sender_id == sender_id,
        ChatMessage.is_delivered == False,
    )
    msgs = list(session.exec(statement).all())
    for m in msgs:
        m.is_delivered = True
    if msgs:
        session.add_all(msgs)
        session.commit()
    return len(msgs)


def get_chat_history(session: Session, user1_id: int, user2_id: int, limit: int = 50):
    """특정 두 사용자 사이의 최근 대화를 시간순으로 조회"""
    statement = select(ChatMessage).where(
        ((ChatMessage.sender_id == user1_id) & (ChatMessage.receiver_id == user2_id)) |
        ((ChatMessage.sender_id == user2_id) & (ChatMessage.receiver_id == user1_id))
    ).order_by(ChatMessage.timestamp.desc()).limit(limit)

    results = session.exec(statement).all()

    history = []
    for m in results[::-1]:
        history.append({
            "id": m.id,
            "content": m.content,
            "sender_id": m.sender_id,
            "receiver_id": m.receiver_id,
            "is_read": m.is_read,
            "timestamp": m.timestamp,
            "sender_name": m.sender.nickname if m.sender else "unknown"
        })
    return history


def mark_messages_as_read(session: Session, user_id: int, target_id: int):
    """상대방이 나에게 보낸 메시지 중 안 읽은 것을 읽음으로 변경"""
    statement = select(ChatMessage).where(
        (ChatMessage.sender_id == target_id),
        (ChatMessage.receiver_id == user_id),
        (ChatMessage.is_read == False)
    )
    unread = session.exec(statement).all()
    for msg in unread:
        msg.is_read = True
    session.add_all(unread)
    session.commit()
    return len(unread)


def delete_old_messages(session: Session, days: int = 7) -> int:
    """지정된 일수보다 오래된 채팅 메시지를 DB에서 삭제.
    서버 DB는 임시 저장소 역할만 하므로 오래된 메시지는 정리한다."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    statement = select(ChatMessage).where(ChatMessage.timestamp < cutoff)
    old_messages = session.exec(statement).all()
    count = len(old_messages)
    for msg in old_messages:
        session.delete(msg)
    if count > 0:
        session.commit()
    return count


def get_inbox(session: Session, user_id: int) -> list[dict]:
    """나에게 온 메시지를 발신자별로 그룹화하여 쪽지 목록 반환.

    각 항목:
      - peer_id         : 상대 internal_id
      - peer_nickname   : 상대 닉네임
      - unread_count    : 읽지 않은 메시지 수
      - last_message    : 가장 최근 메시지 내용
      - last_message_at : 가장 최근 메시지 시각 (ISO 8601)
    """
    from models.user import User

    # 나에게 온 모든 메시지 (최신순)
    statement = (
        select(ChatMessage)
        .where(ChatMessage.receiver_id == user_id)
        .order_by(ChatMessage.timestamp.desc())
    )
    all_received = list(session.exec(statement).all())

    # 발신자(peer_id) 기준으로 집계
    by_peer: dict[int, dict] = {}
    for msg in all_received:
        pid = msg.sender_id
        if pid not in by_peer:
            sender: User | None = session.get(User, pid)
            by_peer[pid] = {
                "peer_id": pid,
                "peer_nickname": sender.nickname if sender else str(pid),
                "unread_count": 0,
                "last_message": msg.content,
                "last_message_at": msg.timestamp.isoformat(),
            }
        if not msg.is_read:
            by_peer[pid]["unread_count"] += 1

    return list(by_peer.values())

