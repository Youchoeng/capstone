from datetime import datetime, timezone
from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from models.user import User

class ChatMessageBase(SQLModel):
    content: str = Field(min_length=1)
    # project의 User 테이블은 internal_id를 PK로 사용
    receiver_id: int = Field(foreign_key="user.internal_id")
    sender_id: int = Field(foreign_key="user.internal_id")

class ChatMessage(ChatMessageBase, table=True):
    id: int | None = Field(default=None, primary_key=True)
    client_msg_id: str = Field(default="", index=True)
    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        index=True
    )
    is_read: bool = Field(default=False)
    is_delivered: bool = Field(default=False)

    # foreign_keys 명시: 같은 테이블을 두 번 참조하므로 경로를 명확히 지정
    sender: Optional["User"] = Relationship(
        sa_relationship_kwargs={
            "foreign_keys": "[ChatMessage.sender_id]",
            "overlaps": "sender"
        }
    )
    receiver: Optional["User"] = Relationship(
        sa_relationship_kwargs={
            "foreign_keys": "[ChatMessage.receiver_id]",
            "overlaps": "receiver"
        }
    )

class ChatMessageResponse(ChatMessageBase):
    id: int
    sender_id: int
    timestamp: datetime
    sender_name: Optional[str] = None
    is_read: bool = False

class ChatRoomEventBase(SQLModel):
    event_type: str = Field(index=True) 
    
    user_id: int = Field(foreign_key="user.internal_id")
    
    peer_id: Optional[int] = Field(default=None, foreign_key="user.internal_id")


class ChatRoomEvent(ChatRoomEventBase, table=True):
    __tablename__ = "chat_room_events"
    
    id: int | None = Field(default=None, primary_key=True)
    timestamp: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
        index=True
    )