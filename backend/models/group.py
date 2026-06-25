from datetime import datetime, timezone
from sqlmodel import Field, SQLModel, Relationship
from sqlalchemy.orm import relationship as sa_relationship
from typing import Optional, TYPE_CHECKING
import enum

if TYPE_CHECKING:
    from models.user import User


# ── 가입 요청 상태 ──
class JoinRequestStatus(str, enum.Enum):
    pending = "pending"      # 대기 중
    approved = "approved"    # 승인됨
    rejected = "rejected"    # 거절됨


# ── 모임(Group) 테이블 ──
class Group(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    name: str = Field(max_length=20, nullable=False, index=True)
    description: str = Field(max_length=100, nullable=False)
    image_url: str = Field(default="")

    # 모임 생성자 (자동으로 리더가 됨)
    creator_id: int = Field(foreign_key="user.internal_id", nullable=False)

    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )

    # 관계
    members: list["GroupMember"] = Relationship(back_populates="group")
    join_requests: list["JoinRequest"] = Relationship(back_populates="group")


# ── 모임 멤버 테이블 ──
class GroupMember(SQLModel, table=True):
    __tablename__ = "groupmember"

    id: int | None = Field(default=None, primary_key=True)
    group_id: int = Field(foreign_key="group.id", nullable=False, index=True)
    user_id: int = Field(foreign_key="user.internal_id", nullable=False, index=True)
    is_leader: bool = Field(default=False)
    joined_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )

    group: Optional["Group"] = Relationship(back_populates="members")
    user: Optional["User"] = Relationship()


# ── 가입 요청 테이블 ──
class JoinRequest(SQLModel, table=True):
    __tablename__ = "joinrequest"

    id: int | None = Field(default=None, primary_key=True)
    group_id: int = Field(foreign_key="group.id", nullable=False, index=True)
    user_id: int = Field(foreign_key="user.internal_id", nullable=False, index=True)
    message: str = Field(default="", max_length=200)  # 가입 인사 메시지
    status: JoinRequestStatus = Field(default=JoinRequestStatus.pending)
    created_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc)
    )

    group: Optional["Group"] = Relationship(back_populates="join_requests")
    user: Optional["User"] = Relationship()
