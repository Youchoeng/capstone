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

  /// WS 연결 참조 카운트 — 여러 채팅 화면이 중첩될 때 안전하게 관리
  int _socketRefCount = 0;

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

  /// 로그인 직후 1회 호출 — FCM 만 초기화, WS 는 연결하지 않음.
  Future<void> start({required int myUserId}) async {
    if (_myUserId == myUserId) return;
    await stop();

    _myUserId = myUserId;

    _fcm = FcmChatHandler(apiBaseUrl: apiBaseUrl, myUserId: myUserId);
    await _fcm!.init();
  }

  /// 채팅 UI 화면 진입 시 호출 — WS 연결 (ref-count 방식).
  Future<void> connectSocket() async {
    final uid = _myUserId;
    if (uid == null) return;

    _socketRefCount++;
    if (_socket != null) return; // 이미 연결 중

    _socket = ChatSocket(baseUrl: wsBaseUrl, myUserId: uid);
    await _socket!.connect();
  }

  /// 채팅 UI 화면 이탈 시 호출 — ref 가 0 이 되면 WS 해제.
  Future<void> disconnectSocket() async {
    _socketRefCount = (_socketRefCount - 1).clamp(0, 999);
    if (_socketRefCount > 0) return; // 아직 다른 채팅 화면이 열려있음

    await _socket?.dispose();
    _socket = null;
  }

  Future<void> stop() async {
    _socketRefCount = 0;
    await _socket?.dispose();
    _socket = null;
    _myUserId = null;
    _fcm = null;
    activeChatPeerId = null;
  }
}
