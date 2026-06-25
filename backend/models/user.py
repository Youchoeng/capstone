from models.post import Comment
from models.post import Post
from sqlmodel import Field, SQLModel, Relationship
import enum
from sqlalchemy import Column, Enum as SAEnum

# 유저 정보를 저장하는 테이블

class GenderType(str, enum.Enum):
    male = "male"
    female = "female"


class User(SQLModel, table=True):
    __table_args__ = {"extend_existing": True}
    # 유저 아이디와는 별개로 1부터 올라가는 실제 primary key용 id
    internal_id: int | None = Field(default=None, primary_key = True)
    # 유저 아이디 (로그인할 때와 + 게시글 작성 때 노출되는 아이디)
    user_id: str = Field(index=True, unique=True, nullable=False, max_length=20)
    # 비밀번호, 암호화 후 저장할 예정
    password: str = Field(nullable=False)
    nickname: str = Field(nullable=False, max_length=30)
    age: int = Field(nullable=False)
    gender: GenderType | None = Field(default=None, sa_column=Column(SAEnum(GenderType)))
    # 기저질환 여부, 질환 하나를 0,1로 저장하여 비트 연산을 통해 비교할 예정
    #       당뇨 =  000001
    #       고혈압 = 000010
    #       당뇨&고혈압 = 000011 이런 식
    health_condition: int = Field(default=0)
    # FCM 푸시 알림용 토큰 (채팅 푸시 알림에 사용)
    fcm_token: str | None = Field(default=None)

    posts: list["Post"] = Relationship(back_populates="author")
    comments: list["Comment"] = Relationship(back_populates="author")
    