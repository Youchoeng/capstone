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
  int _reconnectAttempt = 0;
  bool _disposed = false;

  final _connectedController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectedController.stream;
  bool _connected = false;
  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_disposed) return;
    final uri = Uri.parse('$baseUrl/chat/ws/$myUserId');
    try {
      _channel = WebSocketChannel.connect(uri);

      // WebSocketChannel.connect() 는 즉시 반환되므로
      // ready future 가 완료될 때까지 대기하여 실제 연결 확립을 확인한다.
      await _channel!.ready;

      _setConnected(true);
      _reconnectAttempt = 0;

      _sub = _channel!.stream.listen(
        _onData,
        onDone: _onDone,
        onError: (e, _) => _onDone(),
        cancelOnError: true,
      );

      // 실제 연결 확립 후 outbox 비우기
      _flushOutbox();

      // 30 초마다 ping (NAT/keepalive)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      });
    } catch (e) {
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void sendRaw(String rawJson) {
    //추가내용
    if (_channel != null) {
      _channel!.sink.add(rawJson);
    } else {
      print("⚠️ 웹소켓 채널이 비어있어 [sendRaw] 패킷을 전송하지 못했습니다.");
    }
  }

  void _onDone() {
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
      case 'message':
        await _handleIncomingMessage(data);
        break;
      case 'ack':
        await _handleAck(data);
        break;
      case 'pong':
        break;
      case 'enter_room':
      case 'leave_room':
        print("🚪 [수신부] 입장/퇴장 이벤트 발생(${data['type']}) - 화면 표시 생략");
        break;
      case 'error':
        // 서버 측 거부 (예: invalid_payload). 필요시 UI 에 노출.
        break;
    }
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> data) async {
    final senderId = data['sender_id'] as int;
    final senderNickname = (data['sender_nickname'] as String?) ?? '';
    final content = (data['content'] ?? '') as String;
    final clientMsgId = (data['client_msg_id'] as String?) ?? _uuid.v4();
    final sentAt =
        DateTime.tryParse(data['sent_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc();

    // 대화방 닉네임이 비어 있을 수 있으니 서버에서 받은 값으로 보강
    if (senderNickname.isNotEmpty) {
      await LocalChatDb.instance.upsertConversation(
        peerId: senderId,
        peerNickname: senderNickname,
      );
    }

    await LocalChatDb.instance.saveMessage(
      StoredMessage(
        clientMsgId: clientMsgId,
        peerId: senderId, // 1:1 대화에서 상대 = sender
        senderId: senderId,
        content: content,
        sentAt: sentAt,
        status: 'received',
        isMine: false,
      ),
    );
  }

  Future<void> _handleAck(Map<String, dynamic> data) async {
    final clientMsgId = data['client_msg_id'] as String?;
    if (clientMsgId == null) return;
    final delivered = (data['delivered'] as bool?) ?? false;
    final pushed = (data['pushed'] as bool?) ?? false;
    final status = delivered ? 'delivered' : (pushed ? 'sent' : 'sent');
    await LocalChatDb.instance.updateStatus(clientMsgId, status);
  }

  /// 메시지 송신.
  /// - 즉시 SQLite 에 'pending' 으로 저장 후 UI 가 즉시 반영 가능.
  /// - 연결 상태면 서버에 전송, 아니면 outbox 에 남겨두고 재연결 시 자동 전송.
  Future<StoredMessage> send({
    required int peerId,
    required String content,
  }) async {
    final clientMsgId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final stored = StoredMessage(
      clientMsgId: clientMsgId,
      peerId: peerId,
      senderId: myUserId,
      content: content,
      sentAt: now,
      status: 'pending',
      isMine: true,
    );
    await LocalChatDb.instance.saveMessage(stored);

    _sendOverWire(stored);
    return stored;
  }

  void _sendOverWire(StoredMessage msg) {
    if (!_connected || _channel == null) return;
    try {
      _channel!.sink.add(
        jsonEncode({
          'type': 'send',
          'client_msg_id': msg.clientMsgId,
          'receiver_id': msg.peerId,
          'content': msg.content,
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
