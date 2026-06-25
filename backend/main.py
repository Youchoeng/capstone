from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from database import engine, get_session
import models
from sqlmodel import SQLModel # 작성한 모델들이 SQLModel을 상속받았으므로 이를 통해 생성
from routers import user, post
from routers.chat import router as chat_router
from routers.group import router as group_router
from crud.chat import delete_old_messages
import asyncio

# ── 채팅 메시지 7일 자동 삭제 백그라운드 태스크 ──
async def _chat_cleanup_loop():
    """1시간마다 7일 이상 된 채팅 메시지를 DB에서 삭제한다.
    서버 DB는 웹소켓 미접속 시 임시 저장용이므로 오래된 데이터는 정리."""
    while True:
        try:
            session = next(get_session())
            deleted = delete_old_messages(session, days=7)
            if deleted > 0:
                print(f"🗑️ [chat-cleanup] {deleted}개의 7일 지난 채팅 메시지 삭제 완료")
            session.close()
        except Exception as e:
            print(f"⚠️ [chat-cleanup] 오류: {e}")
        await asyncio.sleep(3600)  # 1시간마다 실행

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 서버 시작 시 models에 정의된 테이블이 없으면 생성
    SQLModel.metadata.create_all(engine)
    print("✅ DB 구조 동기화 완료!")

    # 채팅 메시지 정리 백그라운드 태스크 시작
    cleanup_task = asyncio.create_task(_chat_cleanup_loop())
    print("🔄 채팅 메시지 자동 정리 스케줄러 시작 (7일 초과 메시지 삭제, 1시간 간격)")

    yield

    # 서버 종료 시 태스크 정리
    cleanup_task.cancel()
    try:
        await cleanup_task
    except asyncio.CancelledError:
        pass

app = FastAPI(lifespan=lifespan)

# CORS 설정 - 웹에서의 요청 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 모든 출처 허용 (개발 환경용)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 파일은 http://siondk.home.kg:8000/uploads/파일명 이렇게 저장됨 
# but 현재는 이 프로젝트 폴더의 /uploads 폴더에 저장해야 함
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
app.include_router(user.router)
app.include_router(post.router)
app.include_router(chat_router)
app.include_router(group_router)


@app.get("/")
def root():
    return {"message": "Hello FastAPI with PostgreSQL"}