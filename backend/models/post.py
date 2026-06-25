from datetime import datetime, timezone
from sqlmodel import Field, SQLModel, Relationship
from sqlalchemy.orm import relationship as sa_relationship

# 게시글과 댓글을 저장하는 테이블

class Post(SQLModel, table=True):
    # 각각 게시글 아이디, 제목, 내용
    id: int | None = Field(default=None, primary_key=True)
    title: str = Field(index=True, max_length=100, nullable=False)
    content: str = Field(nullable=False)
    
    # user 테이블의 internal_id를 참조 (게시글 작성자 아이디)
    author_internal_id: int = Field(foreign_key="user.internal_id", index=True, nullable=False)
    
    # 모임 게시글이면 group_id에 해당 모임 ID 저장, 수다탭 글이면 None
    group_id: int | None = Field(default=None, foreign_key="group.id", index=True)

    # 익명 여부
    is_anonymous: bool = Field(default=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    # 밑의 PostLike와 겹치지만 성능을 위해 넣음 / PostLike와 함께 처리해야 함
    likes_count: int = Field(default=0)
    attachment_url: str | None = Field(default=None)

    # 87번째 줄의 주석 참고
    comments: list["Comment"] = Relationship(back_populates="post")

    # 111번째 줄의 주석 참고
    author: "User" = Relationship(back_populates="posts")

class Comment(SQLModel, table=True):
    # 댓글 아이디, 게시글 아이디, 댓글 작성자 아이디, 댓글 내용, 익명 여부, 작성 시각, 좋아요 수
    id: int | None = Field(default=None, primary_key=True)
    post_id: int = Field(foreign_key="post.id", index=True, nullable=False)
    author_internal_id: int = Field(foreign_key="user.internal_id", index=True, nullable=False)
    content: str = Field(nullable=False)
    is_anonymous: bool = Field(default=False)
    is_deleted: bool = Field(default=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    likes_count: int = Field(default=0)

    # 대댓글 기능 / 원댓글이면 parent_id = None으로 하면 됨
    parent_id: int | None = Field(default=None, foreign_key="comment.id")
    
    # Post 테이블과의 관계 설정
    # comment.post로 해당 댓글이 달린 Post 객체에 바로 접근 가능
    # 사용 예시:
    #   comment = session.get(Comment, comment_id)
    #   print(comment.post.title)  # 댓글이 달린 게시글 제목
    post: "Post" = Relationship(back_populates="comments")

    # User 테이블과의 관계 설정
    # comment.author로 댓글 작성자 User 객체에 바로 접근 가능
    # 사용 예시:
    #   comment = session.get(Comment, comment_id)
    #   print(comment.author.username)  # 댓글 작성자 이름
    author: "User" = Relationship(back_populates="comments")

    # 127번째 줄의 주석 참고
    parent: "Comment | None" = Relationship(
        sa_relationship=sa_relationship(
            "Comment",
            back_populates="replies",
            foreign_keys="[Comment.parent_id]",
            remote_side="[Comment.id]",
        )
    )

    # 145번째 줄의 주석 참고
    replies: list["Comment"] = Relationship(
        sa_relationship=sa_relationship(
            "Comment",
            back_populates="parent",
            foreign_keys="[Comment.parent_id]",
        )
    )

class PostLike(SQLModel, table=True):
    # user의 internal_id와 post의 id를 composite key로 사용
    user_internal_id: int = Field(foreign_key="user.internal_id", primary_key=True)
    post_id: int = Field(foreign_key="post.id", primary_key=True)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class CommentLike(SQLModel, table=True):
    user_internal_id: int = Field(foreign_key="user.internal_id", primary_key=True)
    comment_id: int = Field(foreign_key="comment.id", primary_key=True)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

# 해당 게시글에 달린 댓글 목록
# post.comments로 게시글의 모든 댓글 리스트에 바로 접근 가능
# Comment.post와 쌍을 이루는 반대 방향 관계
#
# 사용 예시:
#   post = session.get(Post, post_id)
#   for comment in post.comments:
#       print(comment.content)  # 댓글 내용 순회
#
# API 응답 예시 (게시글 조회 시 댓글 포함):
#   GET /posts/{post_id}
#   {
#     "id": 1,
#     "title": "게시글 제목",
#     "comments": [
#       { "id": 1, "content": "댓글 내용", "author_internal_id": 1 },
#       { "id": 2, "content": "댓글 내용2", "author_internal_id": 2 }
#     ]
#   }
#
# ⚠️ 주의: 댓글 수가 많을 경우 전부 로딩되므로
#    목록 조회 API에서는 comments를 제외하고 likes_count만 반환하는 것을 권장


# 게시글 작성자 User 객체와의 관계 설정
# post.author로 작성자 User 객체에 바로 접근 가능
# author_internal_id(FK)를 기반으로 User를 join해서 가져옴
#
# 사용 예시:
#   post = session.get(Post, post_id)
#   print(post.author.username)  # 작성자 이름
#
# ⚠️ 주의: is_anonymous=True인 경우 API 응답에서
#    author 정보를 노출하지 않도록 별도 처리 필요
#   if not post.is_anonymous:
#       return post.author.username
#   else:
#       return "익명"


# 대댓글의 부모 댓글과의 관계 설정 (자기참조)
# remote_side="[Comment.id]" : Comment.id가 "부모" 쪽 키임을 명시
#   -> parent_id(자식) → id(부모) 방향으로 관계가 설정됨
# foreign_keys="[Comment.parent_id]" : 이 관계에서 FK는 parent_id임을 명시
#   -> 같은 테이블을 참조하므로 어떤 컬럼이 FK인지 SQLAlchemy에 명확히 알려줘야 함
#
# 원댓글이면 parent_id = None이므로 parent = None
# 사용 예시:
#   comment = session.get(Comment, comment_id)
#   if comment.parent:
#       print(comment.parent.content)  # 부모 댓글 내용
#
# API 예시 (대댓글 작성):
#   POST /posts/{post_id}/comments
#   { "content": "대댓글입니다", "parent_id": 1 }  # parent_id 있으면 대댓글
#   { "content": "원댓글입니다", "parent_id": null } # parent_id 없으면 원댓글


# 해당 댓글에 달린 대댓글 목록 (자기참조)
# parent와 쌍을 이루는 반대 방향 관계
# parent_id가 현재 댓글의 id인 댓글들을 모두 가져옴
#
# 사용 예시:
#   comment = session.get(Comment, comment_id)
#   for reply in comment.replies:
#       print(reply.content)  # 대댓글 내용 순회
#
# API 응답 예시 (댓글 목록 조회 시 대댓글 포함):
#   GET /posts/{post_id}/comments
#   [
#     {
#       "id": 1,
#       "content": "원댓글",
#       "parent_id": null,
#       "replies": [
#         { "id": 2, "content": "대댓글", "parent_id": 1 }
#       ]
#     }
#   ]
#
# ⚠️ 주의: 대댓글의 대댓글(depth 3 이상)은 이 구조에서 replies에 포함되지 않음
#    depth를 제한하거나, 재귀적으로 처리하는 로직이 필요함