from sqlmodel import SQLModel
from models.user import GenderType


class UserRegister(SQLModel):
    user_id: str
    password: str
    nickname: str
    age: int
    gender: GenderType | None = None
    health_condition: int = 0


class UserUpdate(SQLModel):
    nickname: str | None = None
    password: str | None = None
    age: int | None = None
    gender: GenderType | None = None
    health_condition: int | None = None


class UserResponse(SQLModel):
    internal_id: int
    user_id: str
    nickname: str
    age: int
    gender: GenderType | None = None
    health_condition: int