import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlmodel import Session, select
from database import get_session
from models.post import Post, Comment, PostLike, CommentLike
from models.user import User
from schemas.post import PostCreate, PostUpdate, PostResponse, PostDetailResponse, CommentCreate, CommentUpdate, CommentResponse
from routers.user import get_current_user

router = APIRouter(prefix="/posts", tags=["posts"])

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB


# ── 이미지 업로드 ─────────────────────────────────────────────
@router.post("/upload", status_code=201)
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    # 확장자 검증
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"허용되지 않는 파일 형식입니다. ({', '.join(ALLOWED_EXTENSIONS)})",
        )

    # 파일 읽기 + 크기 검증
    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="파일 크기는 10MB 이하여야 합니다.")

    # 고유 파일명 생성 후 저장
    unique_name = f"{uuid.uuid4().hex}{ext}"
    file_path = os.path.join(UPLOAD_DIR, unique_name)
    with open(file_path, "wb") as f:
        f.write(contents)

    return {"url": f"/uploads/{unique_name}"}


# ── 게시글 작성 ────────────────────────────────────────────────
@router.post("/", status_code=201)
def create_post(
    data: PostCreate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    post = Post(
        title=data.title,
        content=data.content,
        is_anonymous=data.is_anonymous,
        attachment_url=data.attachment_url,
        author_internal_id=current_user.internal_id,
    )
    session.add(post)
    session.commit()
    session.refresh(post)
    return {"message": "게시글 작성 완료", "post_id": post.id}


# ── 게시글 목록 조회 (수다탭 = group_id가 없는 게시글만) ─────────
@router.get("/", response_model=list[PostResponse])
def get_posts(session: Session = Depends(get_session)):
    posts = session.exec(
        select(Post).where(Post.group_id == None)
    ).all()

    result = []
    for post in posts:
        author = session.get(User, post.author_internal_id)
        result.append(PostResponse(
            id=post.id,
            title=post.title,
            author="익명" if post.is_anonymous else author.user_id,
            likes_count=post.likes_count,
            created_at=post.created_at,
            attachment_url=post.attachment_url,
        ))
    return result


# ── 게시글 상세 조회 ───────────────────────────────────────────
@router.get("/{post_id}", response_model=PostDetailResponse)
def get_post(post_id: int, session: Session = Depends(get_session)):
    post = session.get(Post, post_id)
    if not post :
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")

    author = session.get(User, post.author_internal_id)

    comments = session.exec(
        select(Comment).where(
            Comment.post_id == post_id,
            Comment.is_deleted == False,
            Comment.parent_id == None,
        )
    ).all()

    comment_list = []
    for c in comments:
        comment_author = session.get(User, c.author_internal_id)

        replies = session.exec(
            select(Comment).where(
                Comment.parent_id == c.id,
                Comment.is_deleted == False,
            )
        ).all()

        reply_list = []
        for r in replies:
            reply_author = session.get(User, r.author_internal_id)
            reply_list.append(CommentResponse(
                id=r.id,
                content=r.content,
                author="익명" if r.is_anonymous else reply_author.user_id,
                likes_count=r.likes_count,
                created_at=r.created_at,
            ))

        comment_list.append(CommentResponse(
            id=c.id,
            content=c.content,
            author="익명" if c.is_anonymous else comment_author.user_id,
            likes_count=c.likes_count,
            created_at=c.created_at,
            replies=reply_list,
        ))

    return PostDetailResponse(
        id=post.id,
        title=post.title,
        content=post.content,
        author="익명" if post.is_anonymous else author.user_id,
        likes_count=post.likes_count,
        attachment_url=post.attachment_url,
        created_at=post.created_at,
        comments=comment_list,
    )


# ── 게시글 수정 ────────────────────────────────────────────────
@router.patch("/{post_id}")
def update_post(
    post_id: int,
    data: PostUpdate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    post = session.get(Post, post_id)
    if not post:
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")
    if post.author_internal_id != current_user.internal_id:
        raise HTTPException(status_code=403, detail="본인 게시글만 수정할 수 있습니다.")

    if data.title is not None:
        post.title = data.title
    if data.content is not None:
        post.content = data.content

    session.add(post)
    session.commit()
    return {"message": "게시글 수정 완료"}


# ── 게시글 삭제 ────────────────────────────────────────────────
@router.delete("/{post_id}")
def delete_post(
    post_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    post = session.get(Post, post_id)
    if not post :
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")
    if post.author_internal_id != current_user.internal_id:
        raise HTTPException(status_code=403, detail="본인 게시글만 삭제할 수 있습니다.")

    post.is_deleted = True
    session.add(post)
    session.commit()
    return {"message": "게시글 삭제 완료"}


# ── 게시글 좋아요 ──────────────────────────────────────────────
@router.post("/{post_id}/like", status_code=201)
def like_post(
    post_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    post = session.get(Post, post_id)
    if not post :
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")

    existing = session.exec(
        select(PostLike).where(
            PostLike.post_id == post_id,
            PostLike.user_internal_id == current_user.internal_id,
        )
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 좋아요를 눌렀습니다.")

    like = PostLike(post_id=post_id, user_internal_id=current_user.internal_id)
    session.add(like)
    post.likes_count += 1
    session.add(post)
    session.commit()
    return {"message": "좋아요 완료", "likes_count": post.likes_count}


# ── 게시글 좋아요 취소 ─────────────────────────────────────────
@router.delete("/{post_id}/like")
def unlike_post(
    post_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    post = session.get(Post, post_id)
    if not post :
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")

    like = session.exec(
        select(PostLike).where(
            PostLike.post_id == post_id,
            PostLike.user_internal_id == current_user.internal_id,
        )
    ).first()
    if not like:
        raise HTTPException(status_code=400, detail="좋아요를 누르지 않았습니다.")

    session.delete(like)
    post.likes_count -= 1
    session.add(post)
    session.commit()
    return {"message": "좋아요 취소 완료", "likes_count": post.likes_count}


# ── 댓글 작성 ──────────────────────────────────────────────────
@router.post("/{post_id}/comments", status_code=201)
def create_comment(
    post_id: int,
    data: CommentCreate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    post = session.get(Post, post_id)
    if not post :
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")

    comment = Comment(
        post_id=post_id,
        content=data.content,
        is_anonymous=data.is_anonymous,
        author_internal_id=current_user.internal_id,
    )
    session.add(comment)
    session.commit()
    return {"message": "댓글 작성 완료"}


# ── 댓글 수정 ──────────────────────────────────────────────────
@router.patch("/{post_id}/comments/{comment_id}")
def update_comment(
    post_id: int,
    comment_id: int,
    data: CommentUpdate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    comment = session.get(Comment, comment_id)
    if not comment or comment.is_deleted or comment.post_id != post_id:
        raise HTTPException(status_code=404, detail="댓글을 찾을 수 없습니다.")
    if comment.author_internal_id != current_user.internal_id:
        raise HTTPException(status_code=403, detail="본인 댓글만 수정할 수 있습니다.")

    comment.content = data.content
    session.add(comment)
    session.commit()
    return {"message": "댓글 수정 완료"}


# ── 댓글 삭제 ──────────────────────────────────────────────────
@router.delete("/{post_id}/comments/{comment_id}")
def delete_comment(
    post_id: int,
    comment_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    comment = session.get(Comment, comment_id)
    if not comment or comment.is_deleted or comment.post_id != post_id:
        raise HTTPException(status_code=404, detail="댓글을 찾을 수 없습니다.")
    if comment.author_internal_id != current_user.internal_id:
        raise HTTPException(status_code=403, detail="본인 댓글만 삭제할 수 있습니다.")

    comment.is_deleted = True
    session.add(comment)
    session.commit()
    return {"message": "댓글 삭제 완료"}


# ── 대댓글 작성 ────────────────────────────────────────────────
@router.post("/{post_id}/comments/{comment_id}/replies", status_code=201)
def create_reply(
    post_id: int,
    comment_id: int,
    data: CommentCreate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    post = session.get(Post, post_id)
    if not post :
        raise HTTPException(status_code=404, detail="게시글을 찾을 수 없습니다.")

    parent_comment = session.get(Comment, comment_id)
    if not parent_comment or parent_comment.is_deleted or parent_comment.post_id != post_id:
        raise HTTPException(status_code=404, detail="댓글을 찾을 수 없습니다.")

    if parent_comment.parent_id is not None:
        raise HTTPException(status_code=400, detail="대댓글에는 답글을 달 수 없습니다.")

    reply = Comment(
        post_id=post_id,
        content=data.content,
        is_anonymous=data.is_anonymous,
        author_internal_id=current_user.internal_id,
        parent_id=comment_id,
    )
    session.add(reply)
    session.commit()
    return {"message": "대댓글 작성 완료"}


# ── 대댓글 삭제 ────────────────────────────────────────────────
@router.delete("/{post_id}/comments/{comment_id}/replies/{reply_id}")
def delete_reply(
    post_id: int,
    comment_id: int,
    reply_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    reply = session.get(Comment, reply_id)
    if not reply or reply.is_deleted or reply.parent_id != comment_id or reply.post_id != post_id:
        raise HTTPException(status_code=404, detail="대댓글을 찾을 수 없습니다.")
    if reply.author_internal_id != current_user.internal_id:
        raise HTTPException(status_code=403, detail="본인 대댓글만 삭제할 수 있습니다.")

    reply.is_deleted = True
    session.add(reply)
    session.commit()
    return {"message": "대댓글 삭제 완료"}


# ── 댓글 좋아요 ────────────────────────────────────────────────
@router.post("/{post_id}/comments/{comment_id}/like", status_code=201)
def like_comment(
    post_id: int,
    comment_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    comment = session.get(Comment, comment_id)
    if not comment or comment.is_deleted or comment.post_id != post_id:
        raise HTTPException(status_code=404, detail="댓글을 찾을 수 없습니다.")

    existing = session.exec(
        select(CommentLike).where(
            CommentLike.comment_id == comment_id,
            CommentLike.user_internal_id == current_user.internal_id,
        )
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 좋아요를 눌렀습니다.")

    like = CommentLike(comment_id=comment_id, user_internal_id=current_user.internal_id)
    session.add(like)
    comment.likes_count += 1
    session.add(comment)
    session.commit()
    return {"message": "좋아요 완료", "likes_count": comment.likes_count}


# ── 댓글 좋아요 취소 ───────────────────────────────────────────
@router.delete("/{post_id}/comments/{comment_id}/like")
def unlike_comment(
    post_id: int,
    comment_id: int,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    comment = session.get(Comment, comment_id)
    if not comment or comment.is_deleted or comment.post_id != post_id:
        raise HTTPException(status_code=404, detail="댓글을 찾을 수 없습니다.")

    like = session.exec(
        select(CommentLike).where(
            CommentLike.comment_id == comment_id,
            CommentLike.user_internal_id == current_user.internal_id,
        )
    ).first()
    if not like:
        raise HTTPException(status_code=400, detail="좋아요를 누르지 않았습니다.")

    session.delete(like)
    comment.likes_count -= 1
    session.add(comment)
    session.commit()
    return {"message": "좋아요 취소 완료", "likes_count": comment.likes_count}
