// ─────────────────────────────────────────────────────────────
// WebSocket 채팅 클라이언트
// ─────────────────────────────────────────────────────────────
//
// 책임
//  - 서버 WS (/chat/ws/{user_id}) 와의 단일 연결을 유지
//  - 자동 재연결 (지수 백오프)
//  - 송신: client_msg_id 발급 → SQLite 에 pending 으로 저장 → 서버 전송
//  - 수신: 서버에서 온 메시지를 SQLite 에 저장
//  - ack: 송신 메시지의 status 를 sent/delivered/read 로 갱신
//  - 재접속 시 SQLite 의 pending 메시지를 자동 재전송
//
// 사용 예
//   final socket = ChatSocket(
//     baseUrl: 'ws://siondk.home.kg:8000',
//     myUserId: 1,
//   );
//   await socket.connect();
//   await socket.send(peerId: 2, content: '안녕!');

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'local_chat_db.dart';

const _uuid = Uuid();

class ChatSocket {
  ChatSocket({
    required this.baseUrl, // ex) 'ws://siondk.home.kg:8000'
    required this.myUserId,
  });

  final String baseUrl;
  final int myUserId;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int? _lastPongTime;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _isConnecting = false;

  final _connectedController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectedController.stream;
  bool _connected = false;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_disposed) return;

    if (_connected && _channel != null) {
      debugPrint("이미 웹소켓이 연결되어 있어 중복 연결을 건너뜁니다.");
      return;
    }

    if (_isConnecting) {
      debugPrint("이미 웹소켓 연결이 진행 중이므로 중복 연결 시도를 건너뜁니다.");
      return;
    }

    _isConnecting = true;
    final uri = Uri.parse('$baseUrl/chat/ws/$myUserId');
    try {
      _pingTimer?.cancel();
      await _sub?.cancel();

      _channel = WebSocketChannel.connect(uri);

      // WebSocketChannel.connect() 는 즉시 반환되므로
      // ready future 가 완료될 때까지 대기하여 실제 연결 확립을 확인한다.
      await _channel!.ready;

      _setConnected(true);
      _reconnectAttempt = 0;

      _lastPongTime = DateTime.now().millisecondsSinceEpoch;

      _sub = _channel!.stream.listen(
        _onData,
        onDone: _onDone,
        onError: (e, _) => _onDone(),
        cancelOnError: false,
      );

      // 실제 연결 확립 후 outbox 비우기
      _flushOutbox();

      // 30초마다 핑(ping)을 보내고 생존 확인 진행
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          if (!_connected || _channel == null) return;

          final now = DateTime.now().millisecondsSinceEpoch;

          if (_lastPongTime != null && (now - _lastPongTime! > 35000)) {
            debugPrint(
              "❌ [소켓 모니터링] 35초간 서버로부터 Pong 응답이 없습니다. 좀비 세션으로 판단하여 강제 재연결을 시도합니다.",
            );
            _onDone();
            return;
          }

          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });
    } catch (e) {
      _channel = null;
      _setConnected(false);
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void sendRaw(String rawJson) {
    //추가내용
    if (_channel != null) {
      _channel!.sink.add(rawJson);
    } else {
      debugPrint("⚠️ 웹소켓 채널이 비어있어 [sendRaw] 패킷을 전송하지 못했습니다.");
    }
  }

  void _onDone() {
    _channel = null;
    _setConnected(false);
    _pingTimer?.cancel();
    if (!_disposed) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delaySec = (1 << _reconnectAttempt).clamp(1, 30); // 1,2,4,8,16,30...
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 5);
    _reconnectTimer = Timer(Duration(seconds: delaySec), connect);
  }

  void _setConnected(bool v) {
    if (_connected == v) return;
    _connected = v;
    _connectedController.add(v);
  }

  Future<void> _onData(dynamic raw) async {
    if (raw is! String) return;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (data['type']) {
      case 'history':
        // 서버가 enter_room 직후 내려주는 과거 대화 일괄 전달.
        // 각 메시지를 LocalChatDb에 upsert하면 UI가 자동으로 갱신됨.
        await _handleHistory(data);
        break;
      case 'message':
        await _handleIncomingMessage(data);
        break;
      case 'ack':
        await _handleAck(data);
        break;
      case 'messages_read':
        await _handleMessagesRead(data);
        break;
      case 'pong':
        // pong 수신 시간 기록 ➔ 커넥션 생존 신고
        _lastPongTime = DateTime.now().millisecondsSinceEpoch;
        break;
      case 'room_left':
        // 서버가 leave_room에 응답하는 확인 패킷 — 클라이언트 측 처리 불필요.
        break;
      case 'read_receipt':
        // 상대방이 내 메시지를 읽었다는 신호 — 향후 UI 표시 확장용.
        break;
      case 'enter_room':
      case 'leave_room':
        // 클라가 서버로 보낸 패킷이 에코되어 돌아오는 경우 무시.
        debugPrint(
          "🚪 [수신부] 입장/퇴장 이벤트(${data['type']}) — 화면 표시 생략 (이벤트 전용 테이블에만 기록됨)",
        );
        break;
      case 'delete_message':
        final targetMsgId = data['client_msg_id'] as String?;
        debugPrint("🗑️ [수신부] 상대방이 메시지 삭제 요청 전송: $targetMsgId");
        if (targetMsgId != null && targetMsgId.isNotEmpty) {
          // 로컬 DB 수정 및 실시간 UI 스트림 전파 함수 호출
          await LocalChatDb.instance.markMessageAsDeleted(targetMsgId);
        }
        break;
      case 'error':
        // 서버 측 거부 (예: invalid_payload). 필요시 UI 에 노출.
        break;
    }
  }

  /// 서버가 enter_room 직후 보내는 과거 대화 일괄 처리.
  ///
  /// - history 배열 안의 메시지만 처리하며, 입/퇴장 이벤트는 포함되지 않음.
  /// - LocalChatDb.saveMessage()가 멱등(ConflictAlgorithm.replace)이므로
  ///   중복 저장해도 안전.
  /// - 서버에서 이미 읽힌 메시지이므로 status = 'read'로 저장.
  Future<void> _handleHistory(Map<String, dynamic> data) async {
    final peerId = data['peer_id'] as int?;
    final groupId = data['group_id'] as int? ?? 0;
    final messages = data['messages'] as List<dynamic>?;
    if (peerId == null || messages == null) return;

    String actualNickname = '상대방';
    if (messages.isNotEmpty) {
      for (final raw in messages) {
        final m = raw as Map<String, dynamic>?;
        if (m != null &&
            m['sender_id'] != myUserId &&
            m['sender_name'] != null) {
          actualNickname = m['sender_name'] as String;
          break;
        }
      }
    }

    await LocalChatDb.instance.upsertConversation(
      groupId: groupId,
      peerId: peerId,
      peerNickname: actualNickname,
      isExited: 0,
    );

    // 메시지들을 DB에 저장합니다.
    for (final raw in messages) {
      final m = raw as Map<String, dynamic>?;
      if (m == null) continue;

      final senderId = m['sender_id'] as int?;
      if (senderId == null) continue;

      final content = (m['content'] ?? '') as String;

      // 안정적인 ID 매칭
      final clientMsgId = (m['client_msg_id'] as String?)?.isNotEmpty == true
          ? m['client_msg_id'] as String
          : 'server-${m['id'] ?? _uuid.v4()}';

      // 서버 응답의 timestamp 필드 파싱
      final rawTs = m['timestamp'] as String?;
      final sentAt =
          (rawTs != null ? DateTime.tryParse(rawTs) : null)?.toUtc() ??
          DateTime.now().toUtc();

      final isMine = senderId == myUserId;
      final bool serverDeleted = m['is_deleted'] == true;

      final messageType = (m['message_type'] as String?) ?? 'text';
      final mediaUrl = m['media_url'] as String?;

      await LocalChatDb.instance.saveMessage(
        StoredMessage(
          groupId: groupId,
          clientMsgId: clientMsgId,
          peerId: peerId,
          senderId: senderId,
          content: content,
          sentAt: sentAt,
          status: 'read', // 히스토리 메시지는 이미 읽은 대화로 처리
          isMine: isMine,
          isDeleted: serverDeleted,
          messageType: messageType,
          mediaUrl: mediaUrl,
        ),
      );
    }
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> data) async {
    final int? rawSenderId = data['sender_id'] is int
        ? data['sender_id'] as int
        : int.tryParse(data['sender_id']?.toString() ?? '');

    if (rawSenderId == null) {
      debugPrint("⚠️ [수신 오류] sender_id가 올바르지 않아 메시지를 무시합니다.");
      return;
    }
    final int senderId = rawSenderId;
    final int groupId = data['group_id'] as int? ?? 0;

    final senderNickname = (data['sender_nickname'] as String?) ?? '';
    final content = (data['content'] ?? '') as String;
    final messageType = (data['message_type'] as String?) ?? 'text';
    final mediaUrl = data['media_url'] as String?;

    final clientMsgId = (data['client_msg_id'] as String?)?.isNotEmpty == true
        ? data['client_msg_id'] as String
        : 'server-${data['id']}';

    final sentAt =
        DateTime.tryParse(data['sent_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc();

    await LocalChatDb.instance.upsertConversation(
      groupId: groupId,
      peerId: senderId,
      peerNickname: senderNickname.isNotEmpty ? senderNickname : '상대방',
      isExited: 0,
    );

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
  }

  Future<void> _handleAck(Map<String, dynamic> data) async {
    final clientMsgId = data['client_msg_id'] as String?;
    if (clientMsgId == null) return;

    // 서버가 넘겨준 status 필드를 우선 적용
    final serverStatus = data['status'] as String?;
    if (serverStatus != null) {
      await LocalChatDb.instance.updateMessageStatus(clientMsgId, serverStatus);
      return;
    }

    final delivered = (data['delivered'] as bool?) ?? false;
    final pushed = (data['pushed'] as bool?) ?? false;
    final status = delivered ? 'delivered' : (pushed ? 'sent' : 'sent');
    await LocalChatDb.instance.updateMessageStatus(clientMsgId, status);
  }

  Future<void> _handleMessagesRead(Map<String, dynamic> data) async {
    final groupId = data['group_id'] as int?;
    final peerId = data['peer_id'] as int?;
    if (groupId == null || peerId == null) return;

    await LocalChatDb.instance.markMyMessagesAsRead(groupId, peerId);
  }

  /// 메시지 송신.
  /// - 즉시 SQLite 에 'pending' 으로 저장 후 UI 가 즉시 반영 가능.
  /// - 연결 상태면 서버에 전송, 아니면 outbox 에 남겨두고 재연결 시 자동 전송.
  Future<StoredMessage> send({
    required int groupId,
    required int peerId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    final clientMsgId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final stored = StoredMessage(
      groupId: groupId,
      clientMsgId: clientMsgId,
      peerId: peerId,
      senderId: myUserId,
      content: content,
      sentAt: now,
      status: 'pending',
      isMine: true,
      messageType: messageType,
      mediaUrl: mediaUrl,
    );
    await LocalChatDb.instance.saveMessage(stored);

    _sendOverWire(stored);
    return stored;
  }

  /// 메시지 삭제 요청을 서버로 전송하고 내 로컬 DB를 즉시 갱신합니다.
  void deleteMessage(String clientMsgId, int peerId) {
    try {
      if (_channel != null && _connected) {
        _channel!.sink.add(
          jsonEncode({
            'type': 'delete_message',
            'client_msg_id': clientMsgId,
            'peer_id': peerId,
          }),
        );
      } else {
        debugPrint("⚠️ 웹소켓 연결이 원활하지 않아 서버에 삭제 패킷을 보내지 못했습니다.");
      }

      // 서버 응답을 기다리지 않고 내 UI에 즉시 "삭제된 메시지입니다"를 띄우기 위해
      // 방금 우리가 만든 로컬 DB 업데이트 함수를 곧바로 실행합니다.
      LocalChatDb.instance.markMessageAsDeleted(clientMsgId);
    } catch (e) {
      debugPrint("⚠️ 삭제 패킷 전송 중 에러 발생: $e");
    }
  }

  void _sendOverWire(StoredMessage msg) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(
        jsonEncode({
          'type': 'send',
          'group_id': msg.groupId,
          'client_msg_id': msg.clientMsgId,
          'receiver_id': msg.peerId,
          'content': msg.content,
          'message_type': msg.messageType,
          'media_url': msg.mediaUrl,
          'sent_at': msg.sentAt.toUtc().toIso8601String(),
        }),
      );
    } catch (_) {
      // 전송 실패 시 다음 재연결 때 outbox 에서 다시 시도됨
    }
  }

  Future<void> _flushOutbox() async {
    final pending = await LocalChatDb.instance.loadPendingOutbox();
    for (final m in pending) {
      _sendOverWire(m);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _sub?.cancel();
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    await _connectedController.close();
  }
}
