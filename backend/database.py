from sqlmodel import create_engine, Session

# MySQL 접속 정보
DATABASE_URL = "postgresql+psycopg2://capstone:capstonedesign@siondk.home.kg:5432/capstone_design_db"

# 엔진 생성 (연결 통로)
engine = create_engine(DATABASE_URL, echo=True) # echo=True를 하면 터미널에 실제 SQL문이 출력되어 공부하기 좋습니다.

# DB 세션을 가져오는 함수 (나중에 API에서 사용)
def get_session():
    with Session(engine) as session:
        yield session