"""
FCM 푸시 알림 서비스.

채팅용 사용 패턴:
- title/body 를 None 으로 두고 data 만 채워 보내면 "데이터 전용 메시지" 가 된다.
  → 시스템 알림은 뜨지 않고, 앱이 백그라운드/종료 상태여도 OS 가 앱을 깨워
    onBackgroundMessage 핸들러를 실행한다 (Android/iOS 둘 다 가능, iOS 는 추가 설정 필요).
- 알림 표시까지 OS 에 맡기고 싶으면 title/body 도 같이 전달.

iOS 데이터 전용 메시지 주의사항:
- APNs 헤더에 apns-priority=5 또는 10, content-available=1 이 필요.
  (firebase_admin 의 messaging.APNSConfig 로 설정)
"""

import os
from typing import Optional

import firebase_admin
from firebase_admin import credentials, messaging


current_dir = os.path.dirname(os.path.abspath(__file__))
base_dir = os.path.dirname(current_dir)
JSON_KEY_PATH = os.path.join(base_dir, "firebase-key.json")


def initialize_firebase():
    """파이어베이스 초기화: 모듈 로드 시 자동 실행."""
    if not firebase_admin._apps:
        if os.path.exists(JSON_KEY_PATH):
            try:
                cred = credentials.Certificate(JSON_KEY_PATH)
                firebase_admin.initialize_app(cred)
                print(f"✅ [Push] Firebase 초기화 성공! (경로: {JSON_KEY_PATH})")
            except Exception as e:
                print(f"❌ [Push] Firebase 초기화 실패: {e}")
        else:
            print(f"⚠️ [Push] 경고: {JSON_KEY_PATH} 파일을 찾을 수 없습니다. (테스트 모드)")


initialize_firebase()


def send_push_notification(
    token: str,
    title: Optional[str] = None,
    body: Optional[str] = None,
    data: Optional[dict] = None,
):
    """
    FCM 푸시 전송.

    Parameters
    ----------
    token : str
        대상 기기의 FCM registration token.
    title, body : Optional[str]
        시스템 알림 표시용. 둘 다 None 이면 데이터 전용 메시지로 전송.
    data : Optional[dict]
        커스텀 데이터 페이로드. FCM 규약상 모든 값은 문자열이어야 한다.
    """
    if not token:
        print("⚠️ [Push] 토큰이 없어 전송을 취소합니다.")
        return

    notification = None
    if title or body:
        notification = messaging.Notification(title=title, body=body)

    # data payload 의 모든 값은 string 으로 강제
    safe_data = None
    if data:
        safe_data = {str(k): ("" if v is None else str(v)) for k, v in data.items()}

    # iOS 가 데이터 전용 메시지를 받기 위해 content-available=1 필요
    apns_config = messaging.APNSConfig(
        headers={"apns-priority": "10" if notification else "5"},
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                content_available=True if notification is None else None,
                mutable_content=True if notification is not None else None,
            )
        ),
    )

    # Android 데이터 전용 메시지 — high priority 로 깨워야 즉시 도착
    android_config = messaging.AndroidConfig(
        priority="high",
    )

    message = messaging.Message(
        notification=notification,
        data=safe_data,
        token=token,
        apns=apns_config,
        android=android_config,
    )

    try:
        if firebase_admin._apps:
            response = messaging.send(message)
            print(f"🚀 [Push] 푸시 전송 성공: {response}")
        else:
            print(f"📣 [Push] 테스트 로그 (Firebase 미초기화): title={title} body={body} data={safe_data}")
    except Exception as e:
        print(f"❌ [Push] 전송 중 오류 발생: {e}")
