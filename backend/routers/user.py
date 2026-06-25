from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlmodel import Session, select
from database import get_session
from models.user import User
from schemas.user import UserRegister, UserUpdate, UserResponse
from auth import hash_password, verify_password, create_access_token, decode_token

router = APIRouter(prefix="/users", tags=["users"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/users/login")


# ── 현재 로그인된 유저를 가져오는 의존성 함수 ──────────────────
def get_current_user(
    token: str = Depends(oauth2_scheme),
    session: Session = Depends(get_session)
) -> User:
    user_id = decode_token(token)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 토큰입니다.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = session.exec(select(User).where(User.user_id == user_id)).first()
    if not user:
        raise HTTPException(status_code=404, detail="유저를 찾을 수 없습니다.")
    return user


# ── 회원가입 ───────────────────────────────────────────────────
@router.post("/register", status_code=201)
def register(data: UserRegister, session: Session = Depends(get_session)):
    existing = session.exec(select(User).where(User.user_id == data.user_id)).first()
    if existing:
        raise HTTPException(status_code=400, detail="이미 사용 중인 아이디입니다.")

    new_user = User(
        user_id=data.user_id,
        password=hash_password(data.password),
        nickname=data.nickname,
        age=data.age,
        health_condition=data.health_condition,
    )
    session.add(new_user)
    session.commit()
    return {"message": "회원가입 완료"}


# ── 로그인 ─────────────────────────────────────────────────────
@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    session: Session = Depends(get_session)
):
    user = session.exec(select(User).where(User.user_id == form_data.username)).first()
    if not user or not verify_password(form_data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="아이디 또는 비밀번호가 틀렸습니다.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(data={"sub": user.user_id})
    return {"access_token": token, "token_type": "bearer"}


# ── 내 정보 조회 ───────────────────────────────────────────────
@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


# ── 내 정보 수정 ───────────────────────────────────────────────
@router.patch("/me", response_model=UserResponse)
def update_me(
    data: UserUpdate,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    if data.nickname is not None:
        current_user.nickname = data.nickname
    if data.age is not None:
        current_user.age = data.age
    if data.health_condition is not None:
        current_user.health_condition = data.health_condition
    if data.password is not None:
        current_user.password = hash_password(data.password)

    session.add(current_user)
    session.commit()
    session.refresh(current_user)
    return current_user


# ── 회원 탈퇴 ──────────────────────────────────────────────────
@router.delete("/me", status_code=200)
def delete_me(
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session),
):
    session.delete(current_user)
    session.commit()
    return {"message": "회원 탈퇴 완료"}