from datetime import datetime, timezone
from sqlmodel import Field, SQLModel

class Report(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    user_internal_id: int = Field(foreign_key="user.internal_id", index=True, nullable=False)
    target_type: str = Field(nullable=False) # "post" or "comment"
    target_id: int = Field(nullable=False)
    reason: str = Field(nullable=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
