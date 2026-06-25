from typing import Optional
from sqlmodel import Field, SQLModel
from datetime import date, datetime

class HospitalVisit(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_internal_id: int = Field(foreign_key="user.internal_id", index=True, nullable=False)
    
    hospital_name: str = Field(nullable=False, max_length=100)
    scheduled_at: datetime = Field(nullable=False)   # 병원 방문 일정 시각
    alarm_at: datetime = Field(nullable=False)        # 알람 시각 (ex. 15시 방문이면 14시에 알람 울림)

class MedicationSchedule(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_internal_id: int = Field(foreign_key="user.internal_id", index=True, nullable=False)
    
    medication_name: str = Field(nullable=False, max_length=100)  # 일정 이름
    alarm_at: datetime = Field(nullable=False)                     # 알람 시각
    is_taken: bool = Field(default=False)                          # 복약 여부
    # 날짜 추가해서 오늘 날짜 없으면 추가하는 그런 기능 구현해야 함