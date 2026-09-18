"""
모임(Group) 라우터
- 모임 CRUD
- 가입 요청/승인/거절
- 모임 내부 게시글 (Post 테이블의 group_id를 활용)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlmodel import Session, select
from database import get_session
from models.user import User
from models.post import Post, Comment, PostLike, CommentLike
from models.group import Group, GroupMember, JoinRequest
from schemas.post import (
    PostCreate, PostUpdate, PostResponse, PostDetailResponse,
    CommentCreate, CommentUpdate, CommentResponse,
)
from routers.user import get_current_user, get_current_user_optional
from crud.group import (
    create_group, get_group, list_all_groups, search_groups,
    get_my_groups, get_group_detail, is_member, is_leader,
    create_join_request, get_pending_join_requests,
    approve_join_request, reject_join_request,
    leave_group, delete_group, kick_member, transfer_leader,
)
from pydantic import BaseModel, Field
from typing import Optional

router = APIRouter(prefix="/groups", tags=["groups"])


# ── 스키마 ──────────────────────────────────────────────────────
class GroupCreate(BaseModel):
    name: str = Field(max_length=20)
    description: str = Field(max_length=100)
    image_url: str = ""


class JoinRequestCreate(BaseModel):
    message: str = Field(default="", max_length=200)


# ── 모임 생성 ──────────────────────────────────────────────────
@router.post("/", status_code=201)
def api_create_group(
    data: GroupCreate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    group = create_group(
        session,
        name=data.name,
        description=data.description,
        creator_id=current_user.internal_id,
        image_url=data.image_url,
    )
    return {"message": "모임 생성 완료", "group_id": group.id}


# ── 전체 모임 목록 (검색 포함) ──────────────────────────────────
@router.get("/")
def api_list_groups(
    q: str = Query(default="", description="검색어"),
    session: Session = Depends(get_session),
):
    if q.strip():
        return search_groups(session, q.strip())
    return list_all_groups(session)


# ── 내 모임 목록 ───────────────────────────────────────────────
@router.get("/my")
def api_my_groups(
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    return get_my_groups(session, current_user.internal_id)


# ── 모임 상세 정보 ─────────────────────────────────────────────
@router.get("/{group_id}")
def api_group_detail(
    group_id: int,
    session: Session = Depends(get_session),
):
    detail = get_group_detail(session, group_id)
    if detail is None:
        raise HTTPException(status_code=404, detail="모임을 찾을 수 없습니다.")
    return detail


# ── 가입 요청 ──────────────────────────────────────────────────
@router.post("/{group_id}/join", status_code=201)
def api_join_request(
    group_id: int,
    data: JoinRequestCreate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    group = get_group(session, group_id)
    if group is None:
        raise HTTPException(status_code=404, detail="모임을 찾을 수 없습니다.")

    req = create_join_request(
        session, group_id, current_user.internal_id, data.message
    )
    if req is None:
        raise HTTPException(
            status_code=400,
            detail="이미 멤버이거나 대기 중인 가입 요청이 있습니다.",
        )
    return {"message": "가입 요청 완료", "request_id": req.id}


# ── 가입 요청 목록 (리더 전용) ─────────────────────────────────
@router.get("/{group_id}/join-requests")
def api_join_requests(
    group_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not is_leader(session, group_id, current_user.internal_id):
        raise HTTPException(status_code=403, detail="모임장만 확인할 수 있습니다.")
    return get_pending_join_requests(session, group_id)


# ── 가입 승인 (리더 전용) ──────────────────────────────────────
@router.post("/{group_id}/join-requests/{request_id}/approve")
def api_approve(
    group_id: int,
    request_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not is_leader(session, group_id, current_user.internal_id):
        raise HTTPException(status_code=403, detail="모임장만 승인할 수 있습니다.")
    ok = approve_join_request(session, request_id)
    if not ok:
        raise HTTPException(status_code=400, detail="승인할 수 없는 요청입니다.")
    return {"message": "가입 승인 완료"}


# ── 가입 거절 (리더 전용) ──────────────────────────────────────
@router.post("/{group_id}/join-requests/{request_id}/reject")
def api_reject(
    group_id: int,
    request_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not is_leader(session, group_id, current_user.internal_id):
        raise HTTPException(status_code=403, detail="모임장만 거절할 수 있습니다.")
    ok = reject_join_request(session, request_id)
    if not ok:
        raise HTTPException(status_code=400, detail="거절할 수 없는 요청입니다.")
    return {"message": "가입 거절 완료"}


# ── 모임 탈퇴 ──────────────────────────────────────────────────
@router.post("/{group_id}/leave")
def api_leave(
    group_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    ok = leave_group(session, group_id, current_user.internal_id)
    if not ok:
        raise HTTPException(
            status_code=400,
            detail="탈퇴할 수 없습니다. (멤버가 아니거나 모임장입니다)",
        )
    return {"message": "모임 탈퇴 완료"}


# ── 모임 삭제 (리더 전용) ──────────────────────────────────────
@router.delete("/{group_id}")
def api_delete_group(
    group_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    ok = delete_group(session, group_id, current_user.internal_id)
    if not ok:
        raise HTTPException(status_code=403, detail="모임장만 삭제할 수 있습니다.")
    return {"message": "모임 삭제 완료"}


# ── 멤버 강퇴 (리더 전용) ──────────────────────────────────────
@router.delete("/{group_id}/members/{target_user_id}")
def api_kick_member(
    group_id: int,
    target_user_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    ok = kick_member(session, group_id, target_user_id, current_user.internal_id)
    if not ok:
        raise HTTPException(
            status_code=400,
            detail="강퇴할 수 없습니다. (모임장 권한 필요 또는 대상이 유효하지 않음)",
        )
    return {"message": "멤버 강퇴 완료"}

# ── 방장 권한 위임 (리더 전용) ──────────────────────────────────
@router.patch("/{group_id}/transfer-leader")
def api_transfer_leader(
    group_id: int,
    target_user_id: int = Query(..., description="위임받을 멤버의 user_id"),
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    ok = transfer_leader(session, group_id, current_user.internal_id, target_user_id)
    if not ok:
        raise HTTPException(
            status_code=400,
            detail="권한 위임 실패. (모임장이 아니거나 유효하지 않은 대상입니다)",
        )
    return {"message": "방장 권한 위임 완료"}

# ════════════════════════════════════════════════════════════════
# 모임 내부 게시판 (수다탭과 동일한 구조, group_id로 필터)
# ════════════════════════════════════════════════════════════════

# ── 모임 게시글 작성 ───────────────────────────────────────────
@router.post("/{group_id}/posts", status_code=201)
def create_group_post(
    group_id: int,
    data: PostCreate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if not is_member(session, group_id, current_user.internal_id):
        raise HTTPException(status_code=403, detail="모임 멤버만 글을 작성할 수 있습니다.")

    if data.is_notice and not is_leader(session, group_id, current_user.internal_id):
        raise HTTPException(status_code=403, detail="모임장만 공지사항을 등록할 수 있습니다.")

    post = Post(
        title=data.title,
        content=data.content,
        is_anonymous=data.is_anonymous,
        is_notice=data.is_notice,
        attachment_url=data.attachment_url,
        author_internal_id=current_user.internal_id,
        group_id=group_id,
    )
    session.add(post)
    session.commit()
    session.refresh(post)
    return {"message": "게시글 작성 완료", "post_id": post.id}


# ── 모임 게시글 목록 조회 ──────────────────────────────────────
@router.get("/{group_id}/posts", response_model=list[PostResponse])
def get_group_posts(
    group_id: int,
    session: Session = Depends(get_session),
    current_user: User | None = Depends(get_current_user_optional)
):
    posts = session.exec(
        select(Post)
        .where(Post.group_id == group_id)
        .order_by(Post.is_notice.desc(), Post.created_at.desc())
    ).all()

    liked_post_ids = set()
    if current_user and posts:
        post_ids = [p.id for p in posts if p.id is not None]
        if post_ids:
            likes = session.exec(
                select(PostLike.post_id).where(
                    PostLike.user_internal_id == current_user.internal_id,
                    PostLike.post_id.in_(post_ids)
                )
            ).all()
            liked_post_ids = set(likes)

    result = []
    for post in posts:
        author = session.get(User, post.author_internal_id)
        result.append(PostResponse(
            id=post.id,
            title=post.title,
            author="익명" if post.is_anonymous else (author.nickname if author else "알 수 없음"),
            likes_count=post.likes_count,
            is_liked=post.id in liked_post_ids,
            is_notice=post.is_notice,
            created_at=post.created_at,
            attachment_url=post.attachment_url,
        ))
    return result
