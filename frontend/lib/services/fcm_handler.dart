// ─────────────────────────────────────────────────────────────
// Firebase Cloud Messaging 핸들러
// ─────────────────────────────────────────────────────────────
//
// 메시지는 서버 DB 가 아닌 클라 SQLite 에 저장된다는 전제를 바탕으로,
// FCM 의 역할을 다음과 같이 한정한다.
//   1) 토큰 등록 / 갱신을 백엔드로 전달
//   2) 수신 측이 오프라인일 때 서버가 보낸 "data 페이로드" 메시지를
//      백그라운드에서 받아 로컬 SQLite 에 저장
//   3) 사용자에게 보일 시스템 알림을 로컬 알림으로 띄움
//
// 서버 → 클라 데이터 페이로드 스키마 (routers/chat.py 와 동기화)
//   {
//     "type": "chat_message",
//     "client_msg_id": "...",
//     "sender_id": "1",
//     "sender_nickname": "홍길동",
//     "content": "안녕!",
//     "sent_at": "2026-04-28T01:23:45+00:00"
//   }
//
// ※ Background handler 는 반드시 top-level 함수여야 한다.

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../main.dart'; // navigatorKey 참조
import '../Personal_Chat_Screen.dart';
import 'chat_runtime.dart';
import 'local_chat_db.dart';

/// 백그라운드/종료 상태에서 호출되는 핸들러 (top-level 필수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  // 백그라운드 isolate 에서도 Firebase / SQLite 사용 가능하도록 초기화
  await Firebase.initializeApp();
  await _persistChatMessage(message);
}

Future<void> _persistChatMessage(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] != 'chat_message') return;

  final senderIdStr = data['sender_id'] as String? ?? '0';
  final senderId = int.tryParse(senderIdStr) ?? 0;
  if (senderId == 0) return;

  final groupIdStr = data['group_id'] as String? ?? '0';
  final groupId = int.tryParse(groupIdStr) ?? 0;

  final content = data['content'] as String? ?? '';
  final clientMsgId =
      data['client_msg_id'] as String? ??
      'fcm-${DateTime.now().millisecondsSinceEpoch}';
  final sentAt =
      DateTime.tryParse(data['sent_at'] as String? ?? '')?.toUtc() ??
      DateTime.now().toUtc();

  final messageType = data['msg_type'] as String? ?? 'text';
  final mediaUrl = data['media_url'] as String?;

  await LocalChatDb.instance.saveMessage(
    StoredMessage(
      groupId: groupId,
      clientMsgId: clientMsgId,
      peerId: senderId,
      senderId: senderId,
      content: content,
      sentAt: sentAt,
      status: 'received',
      isMine: false,
      messageType: messageType,
      mediaUrl: mediaUrl,
    ),
  );

  // 대화방 닉네임을 최초 1회라도 채워두기
  final nick = data['sender_nickname'] as String? ?? '';
  if (nick.isNotEmpty) {
    await LocalChatDb.instance.upsertConversation(
      groupId: groupId,
      peerId: senderId,
      peerNickname: nick,
    );
  }
}

class FcmChatHandler {
  FcmChatHandler({required this.apiBaseUrl, required this.myUserId});

  final String apiBaseUrl; // ex) http://siondk.home.kg:8000
  final int myUserId;

  final FlutterLocalNotificationsPlugin _localNoti =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[FCM] 웹 환경에서는 임시로 FCM 푸시를 비활성화합니다.');
      return;
    }
    final messaging = FirebaseMessaging.instance;

    // 권한 요청 (iOS/Android 13+)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 로컬 알림 초기화 (포그라운드에서 직접 알림 띄우기 위함)
    await _localNoti.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // 토큰 등록
    final token = await messaging.getToken();
    if (token != null) {
      await _registerTokenToBackend(token);
    }
    messaging.onTokenRefresh.listen(_registerTokenToBackend);

    // 백그라운드 핸들러
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 포그라운드 수신
    //  - SQLite 에 저장 (멱등 — WS 와 중복돼도 안전)
    //  - 사용자가 "지금 해당 채팅방을 보고 있는" 상태면 알림은 띄우지 않는다 (중복 제거).
    //  - 그 외(다른 탭, 채팅 목록 등) 일 때만 로컬 알림 표시.
    FirebaseMessaging.onMessage.listen((message) async {
      await _persistChatMessage(message);

      final data = message.data;
      if (data['type'] != 'chat_message') return;
      final senderId = int.tryParse(data['sender_id'] as String? ?? '') ?? 0;

      final activePeer = ChatRuntime.instance.activeChatPeerId;
      if (activePeer != null && activePeer == senderId) {
        // 현재 그 채팅방을 보고 있는 중 — 시스템 알림 띄우지 않음
        return;
      }

      await _showLocalNotification(message);
    });

    // 알림 탭으로 앱이 열린 경우 — 필요 시 채팅방으로 라우팅
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await _persistChatMessage(message);

      final data = message.data;
      if (data.containsKey('group_id') && data.containsKey('sender_id')) {
        final groupId = int.tryParse(data['group_id'].toString()) ?? 0;
        final peerId = int.tryParse(data['sender_id'].toString()) ?? 0;
        final userName = data['sender_nickname'] ?? '상대방';

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => PersonalChatScreen(
              groupId: groupId,
              peerId: peerId,
              userName: userName,
            ),
          ),
        );
      }
    });
  }

  Future<void> _registerTokenToBackend(String token) async {
    try {
      final url = Uri.parse('$apiBaseUrl/chat/fcm-token');
      await http.post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': myUserId, 'fcm_token': token}),
      );
    } catch (e) {
      if (kDebugMode) print('[FCM] 토큰 등록 실패: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final data = message.data;
    if (data['type'] != 'chat_message') return;

    final title = (data['sender_nickname'] as String?)?.isNotEmpty == true
        ? data['sender_nickname'] as String
        : '새 메시지';
    final body = data['content'] as String? ?? '';

    await _localNoti.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_channel',
          '채팅 메시지',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
