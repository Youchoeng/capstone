from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


# ── 게시글 ─────────────────────────────────────────────────────

class PostCreate(BaseModel):
    """게시글 작성 시 받는 데이터"""
    title: str = Field(max_length=100)
    content: str
    is_anonymous: bool = False
    is_notice: bool = False
    attachment_url: Optional[str] = None

    @field_validator("title", "content")
    @classmethod
    def whitespace_check(cls, v: str) -> str:
        """공백만 포함된 제목 또는 내용 거부"""
        if not v.strip():
            raise ValueError("공백만 포함된 제목 또는 글을 작성할 수 없습니다")
        return v


class PostUpdate(BaseModel):
    """게시글 수정 시 받는 데이터 (부분 수정 가능)"""
    title: Optional[str] = Field(default=None, max_length=100)
    content: Optional[str] = None
    is_notice: Optional[bool] = None

    @field_validator("title", "content")
    @classmethod
    def whitespace_check(cls, v: Optional[str]) -> Optional[str]:
        """공백만 포함된 제목 또는 내용 거부 (None은 허용)"""
        if not v:
            return v
        if not v.strip():
            raise ValueError("공백만 포함된 제목 또는 글을 작성할 수 없습니다")
        return v


class CommentCreate(BaseModel):
    """댓글/대댓글 작성 시 받는 데이터"""
    content: str
    is_anonymous: bool = False

    @field_validator("content")
    @classmethod
    def whitespace_check(cls, v: str) -> str:
        """공백만 포함된 댓글 거부"""
        if not v.strip():
            raise ValueError("공백만 포함된 댓글을 작성할 수 없습니다")
        return v


class CommentUpdate(BaseModel):
    """댓글 수정 시 받는 데이터"""
    content: str

    @field_validator("content")
    @classmethod
    def whitespace_check(cls, v: str) -> str:
        """공백만 포함된 댓글 거부"""
        if not v.strip():
            raise ValueError("공백만 포함된 댓글을 작성할 수 없습니다")
        return v


# ── 응답 ───────────────────────────────────────────────────────

class CommentResponse(BaseModel):
    id: int
    content: str
    author: str
    likes_count: int
    is_liked: bool = False
    created_at: datetime
    replies: list["CommentResponse"] = []


class PostResponse(BaseModel):
    id: int
    title: str
    author: str
    likes_count: int
    is_liked: bool = False
    is_notice: bool = False
    created_at: datetime
    attachment_url: Optional[str] = None


class PostDetailResponse(BaseModel):
    id: int
    title: str
    content: str
    author: str
    likes_count: int
    is_liked: bool = False
    is_notice: bool = False
    attachment_url: Optional[str] = None
    created_at: datetime
    comments: list[CommentResponse] = []

class ReportCreate(BaseModel):
    reason: str

