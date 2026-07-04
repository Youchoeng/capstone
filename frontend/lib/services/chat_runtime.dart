// ─────────────────────────────────────────────────────────────
// 앱 전역 채팅 런타임 (간단 서비스 로케이터)
// ─────────────────────────────────────────────────────────────
//
// 로그인 직후 ChatRuntime.start(myUserId: ...) 를 호출하면
// FCM 만 초기화하고, WebSocket 은 연결하지 않는다.
//
// WebSocket 은 채팅 UI 화면(PersonalChatScreen, ChatListScreen 등)이
// 열릴 때 connectSocket() 으로 연결하고,
// 화면을 떠날 때 disconnectSocket() 으로 해제한다.
//
// 이렇게 하면 건강탭, 수다탭 등 채팅과 무관한 화면에서는
// 서버와 WS 연결이 없고, 서버가 메시지를 DB 에 저장해 두었다가
// 사용자가 다시 채팅 화면을 열면 pending 메시지를 전달한다.

import 'chat_socket.dart';
import 'fcm_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutterproject/api_service.dart';

class ChatRuntime {
  ChatRuntime._();
  static final ChatRuntime instance = ChatRuntime._();

  static String get wsBaseUrl => ApiService.baseUrl.replaceFirst('http', 'ws');
  static String get apiBaseUrl => ApiService.baseUrl;

  ChatSocket? _socket;
  FcmChatHandler? _fcm;
  int? _myUserId;

  /// 현재 사용자가 "보고 있는" 채팅방의 상대 internal_id.
  int? activeChatPeerId;

  ChatSocket get socket {
    final s = _socket;
    if (s == null) {
      throw StateError('ChatRuntime.connectSocket() 먼저 호출하세요.');
    }
    return s;
  }

  int get myUserId {
    final id = _myUserId;
    if (id == null) {
      throw StateError('ChatRuntime.start() 먼저 호출하세요.');
    }
    return id;
  }

  bool get isStarted => _myUserId != null;

  /// 로그인 직후 1회 호출 — FCM 초기화 및 WS 전역 연결
  Future<void> start({required int myUserId}) async {
    await stop();

    _myUserId = myUserId;

    _fcm = FcmChatHandler(apiBaseUrl: apiBaseUrl, myUserId: myUserId);
    await _fcm!.init();

    // 앱 런타임 기동 시 즉시 전역 싱글톤 소켓 연결
    _socket = ChatSocket(baseUrl: wsBaseUrl, myUserId: myUserId);
    await _socket!.connect();

    // FCM 토큰 발급 및 백엔드 동기화
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService.registerFcmToken(myUserId, token);
        print("📲 [ChatRuntime] FCM 토큰 백엔드 동기화 성공");
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        ApiService.registerFcmToken(myUserId, newToken);
        print("🔄 [ChatRuntime] FCM 토큰 갱신 및 백엔드 동기화 성공");
      });
    } catch (e) {
      print("⚠️ [ChatRuntime] FCM 토큰 동기화 실패: $e");
    }

    print("👤 [ChatRuntime] 유저 $myUserId 세션으로 런타임(FCM+WS)이 정상 기동되었습니다.");
  }

  /// 채팅 UI 화면 진입 시 호출 — 이미 전역 소켓이 유지되므로 연결만 확인
  Future<void> connectSocket() async {
    final uid = _myUserId;
    if (uid == null) return;

    // 전역 소켓이 혹시 끊어져 있다면 재연결
    if (_socket != null) {
      await _socket!.connect();
    }
  }

  /// 채팅 UI 화면 이탈 시 호출 — 전역 소켓을 유지하므로 물리적 해제 무효화
  Future<void> disconnectSocket() async {
    // 아무 작업도 하지 않음 (전역 소켓 유지)
  }

  Future<void> stop() async {
    await _socket?.dispose();
    _socket = null;
    _myUserId = null;
    _fcm = null;
    activeChatPeerId = null;
  }
}
