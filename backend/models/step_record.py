from sqlmodel import Field, SQLModel
from datetime import date

class StepRecord(SQLModel, table=True):
    # 유저 아이디와 날짜를 composite key로
    user_id: int = Field(foreign_key="user.internal_id", primary_key=True)
    record_date: date = Field(primary_key=True)
    # 오늘 걸음 수
    step_count: int = Field(default=0)
    # 목표 걸음 수
    goal_step_count: int = Field(default=0)