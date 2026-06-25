from datetime import datetime, timedelta
from jose import JWTError, jwt
from passlib.context import CryptContext

# 비밀키 (실제 배포 시엔 환경변수로 관리하세요)
SECRET_KEY = "Hello World"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24시간

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    """평문 비밀번호를 bcrypt로 암호화"""
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    """입력한 비밀번호가 저장된 해시와 일치하는지 확인"""
    return pwd_context.verify(plain, hashed)

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """JWT 토큰 생성"""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> str | None:
    """토큰에서 user_id 추출 (유효하지 않으면 None 반환)"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except JWTError:
        return None