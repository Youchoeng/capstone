# 1. 코드 받기
git clone ...
cd project
-> 지금은 카톡으로 코드 받기

# 2. 가상환경 생성 (선택이지만 강력 추천)
python -m venv venv

# Windows
venv\Scripts\activate
# Mac/Linux
source venv/bin/activate

# 3. 패키지 한 번에 설치
pip install -r requirements.txt

# 4. 실행
uvicorn main:app --reload