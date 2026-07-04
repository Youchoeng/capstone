// 1:1 개인 쪽지(채팅) 화면
//
// - UI 는 기존 디자인을 그대로 유지.
// - 데이터는 LocalChatDb (SQLite) + ChatSocket (WebSocket) 로 연결.
// - 서버는 메시지를 저장하지 않고 단순 릴레이만 함.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/chat_runtime.dart';
import 'services/local_chat_db.dart';
import 'package:flutterproject/api_service.dart';

class PersonalChatScreen extends StatefulWidget {
  /// 모임방 ID (새로운 1:1 채팅 분리 기준)
  final int groupId;

  /// 화면 상단에 표시할 상대 닉네임
  final String userName;

  /// 대화 상대의 internal_id (User.internal_id)
  /// 실제 송수신/저장에 사용되는 핵심 키.
  ///
  /// 기존 호출부 호환을 위해 nullable. null 일 경우 userName 의 해시로 임시 ID 를 만들어
  /// 로컬 저장만 정상 동작 (서버 송수신은 실제 internal_id 가 있어야 한다).
  /// 호출부에서는 가급적 실제 internal_id 를 넘겨주세요.
  final int? peerId;

  /// 추가
  final bool showExitButton;
  final String inputHintText;

  /// (Deprecated) 과거 더미 데이터용 파라미터.
  /// 새 구조에서는 메시지를 SQLite 에서 불러오므로 사용되지 않지만,
  /// 기존 호출부 호환을 위해 시그니처만 유지합니다.
  /// 값이 들어와도 무시됩니다.
  final List<Map<String, dynamic>>? initialMessages;

  const PersonalChatScreen({
    super.key,
    required this.groupId,
    required this.userName,
    this.peerId,
    this.showExitButton = true,
    this.inputHintText = '쪽지를 입력하세요',
    this.initialMessages, // 호환용 (사용 안 함)
  });

  int get effectivePeerId => peerId ?? (userName.hashCode & 0x7fffffff);

  @override
  State<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<StoredMessage> _messages = [];
  StreamSubscription<StoredMessage>? _incomingSub;

  @override
  void initState() {
    super.initState();

    final peerId = widget.effectivePeerId;

    // 이 화면을 보는 동안 "활성 채팅방" 으로 표시 → FCM 알림 중복 제거 트리거
    ChatRuntime.instance.activeChatPeerId = peerId;

    // ──채팅 UI 열림 → WS 연결 ──
    ChatRuntime.instance.connectSocket();

    _syncAndLoadMessages(peerId);

    // 새로 도착하는 메시지 / 상태 변경 구독
    _incomingSub = LocalChatDb.instance.messageStream.listen((msg) {
      if (msg.groupId != widget.groupId || msg.peerId != peerId) return;

      // 1. 이미 화면에 존재하는 메시지인지 clientMsgId로 먼저 찾기
      final idx = _messages.indexWhere((m) => m.clientMsgId == msg.clientMsgId);

      setState(() {
        if (idx >= 0) {
          _messages[idx] = msg;
        } else {
          _messages.add(msg);
        }
      });
      _scrollToBottom();
    });
  }

  Future<void> _syncAndLoadMessages(int peerId) async {
    await LocalChatDb.instance.upsertConversation(
      groupId: widget.groupId,
      peerId: peerId,
      peerNickname: widget.userName,
    );

    // 쪽지방 진입 즉시 안 읽음 배지 숫자를 0으로 청소
    await LocalChatDb.instance.markRead(widget.groupId, peerId);

    final localHistory = await LocalChatDb.instance.loadMessages(
      widget.groupId,
      peerId,
    );
    if (mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(localHistory);
      });
      _scrollToBottom();
    }

    try {
      ChatRuntime.instance.socket.sendRaw(
        jsonEncode({
          "type": "enter_room",
          "group_id": widget.groupId,
          "peer_id": peerId,
        }),
      );
      debugPrint(
        "✅ enter_room 패킷 전송 완료 (group_id: ${widget.groupId}, peer_id: $peerId)",
      );
    } catch (e) {
      debugPrint("⚠️ enter_room 패킷 전송 실패: $e");
    }

    _performBackgroundSync(widget.groupId, peerId);
  }

  Future<void> _performBackgroundSync(int groupId, int peerId) async {
    try {
      final myIdStr = ApiService.currentUserId;
      if (myIdStr == null) return;
      final int? myId = int.tryParse(myIdStr);
      if (myId == null) return;

      final List<dynamic> remoteMessages = await ApiService.getChatHistory(
        myId,
        peerId,
        groupId,
      );
      if (remoteMessages.isEmpty) return;

      final List<StoredMessage> batchList = [];

      for (final msg in remoteMessages) {
        final int senderId = msg['sender_id'] as int;
        final rawTs = msg['timestamp'] as String?;
        final sentAt =
            (rawTs != null ? DateTime.tryParse(rawTs) : null)?.toUtc() ??
            DateTime.now().toUtc();
        final rawId = msg['client_msg_id'] as String?;
        final clientMsgId = (rawId != null && rawId.isNotEmpty)
            ? rawId
            : 'server-${msg['id']}';

        final bool isRead = msg['is_read'] == true;
        final String status = isRead ? 'read' : 'sent';
        final bool serverDeleted = msg['is_deleted'] == true;

        final String messageType = msg['message_type'] as String? ?? 'text';
        final String? mediaUrl = msg['media_url'] as String?;

        batchList.add(
          StoredMessage(
            groupId: widget.groupId,
            clientMsgId: clientMsgId,
            peerId: peerId,
            senderId: senderId,
            content: msg['content'] as String,
            sentAt: sentAt,
            status: status,
            isMine: senderId == myId,
            isDeleted: serverDeleted,
            messageType: messageType,
            mediaUrl: mediaUrl,
          ),
        );
      }

      if (batchList.isNotEmpty) {
        await LocalChatDb.instance.saveMessagesBatch(batchList);

        // 싱크 완료 후 한 번 더 로컬 최신 목록으로 화면 UI 갱신 유도
        final updatedLocalHistory = await LocalChatDb.instance.loadMessages(
          widget.groupId,
          peerId,
        );
        if (mounted) {
          setState(() {
            _messages
              ..clear()
              ..addAll(updatedLocalHistory);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("서버 백로그 백그라운드 동기화 실패: $e");
    }
  }

  @override
  void dispose() {
    try {
      final leavePayload = {
        "type": "leave_room",
        "group_id": widget.groupId,
        "peer_id": widget.effectivePeerId,
      };
      // .send() 메서드를 활용해 leave_room 전송 처리
      ChatRuntime.instance.socket.sendRaw(jsonEncode(leavePayload));
    } catch (e) {
      debugPrint("leave_room 통보 실패: $e");
    }

    _messageController.dispose();
    _scrollController.dispose();
    _incomingSub?.cancel();

    if (ChatRuntime.instance.activeChatPeerId == widget.effectivePeerId) {
      ChatRuntime.instance.activeChatPeerId = null;
    }

    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatLocalTime(DateTime utc) {
    final local = utc.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$period $displayHour:$minute';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 1. 전송 버튼을 누르는 즉시 입력창을 깔끔하게 비웁니다.
    _messageController.clear();

    try {
      // 🌟 [핵심] 복잡한 로컬 DB 선제 저장, 임시 ID 생성, jsonEncode는 이제 전부 필요 없습니다!
      // 아까 고친 ChatSocket의 .send() 함수가 내부에서 자동으로:
      //   ① UUID 생성
      //   ② 로컬 SQLite에 'pending' 상태로 선제 저장 (UI 실시간 반영)
      //   ③ 백엔드 규격('peer_id')에 맞춰 소켓 전송
      // 이 모든 것을 알아서 한 방에 처리해 줍니다.
      await ChatRuntime.instance.socket.send(
        groupId: widget.groupId,
        peerId: widget.effectivePeerId,
        content: text, // 👈 jsonEncode 하지 않은 순수한 문자열(text)만 넘겨야 합니다!
      );

      debugPrint("🚀 메시지 전송 프로세스 성공 완료!");
    } catch (e) {
      // 소켓 자체의 치명적인 에러 캐치 시
      debugPrint("❌ 웹소켓 실시간 릴레이 실패: $e");
    }
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final url = await ApiService.uploadChatImage(file);
    if (url != null) {
      try {
        await ChatRuntime.instance.socket.send(
          groupId: widget.groupId,
          peerId: widget.effectivePeerId,
          content: '(사진)',
          messageType: 'image',
          mediaUrl: url,
        );
        debugPrint("🚀 사진 전송 성공 완료!");
      } catch (e) {
        debugPrint("❌ 사진 웹소켓 실시간 릴레이 실패: $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('사진 업로드에 실패했습니다.')));
      }
    }
  }

  Widget _buildConnectionDot() {
    Stream<bool>? stream;
    bool initial = false;
    try {
      stream = ChatRuntime.instance.socket.connectionStream;
      initial = ChatRuntime.instance.socket.isConnected;
    } on StateError {
      stream = null;
    }

    Widget dot(bool ok) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: ok ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );

    if (stream == null) return dot(false);

    return StreamBuilder<bool>(
      stream: stream,
      initialData: initial,
      builder: (_, snap) => dot(snap.data == true),
    );
  }

  Future<void> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '쪽지 나가기',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('이 쪽지를 나가시겠어요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
              child: const Text('나가기', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      Navigator.pop(context, {'didLeaveChat': true});
    }
  }

  Widget _buildStatusLabel(StoredMessage m) {
    if (!m.isMine || m.status == 'read') return const SizedBox.shrink();
    if (m.status == 'pending') {
      return const Text(
        '...',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      );
    }
    // sent 또는 delivered 상태
    return const Text(
      '1',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFBC02D),
      ),
    );
  }

  Widget _buildMessageBubble(StoredMessage message) {
    final bool isMe = message.isMine;
    final time = _formatLocalTime(message.sentAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusLabel(message),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: isMe && !(message.isDeleted == true)
                  ? () => _showDeleteConfirmationDialog(context, message)
                  : null,
              child: CustomPaint(
                painter: _BubbleTailPainter(isMe: isMe),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: message.isDeleted == true
                        ? Colors.grey[200]
                        : (isMe ? const Color(0xFFFFEB3B) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: message.isDeleted == true
                      ? const Text(
                          '삭제된 메시지입니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : (message.messageType == 'image' &&
                                message.mediaUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  '${ApiService.baseUrl}${message.mediaUrl}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) =>
                                      const Text('이미지 로드 실패'),
                                ),
                              )
                            : Text(
                                message.content,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              )),
                ),
              ),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 6),
            Text(
              time,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    StoredMessage message,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠습니까?\n삭제된 메시지는 상대방 화면에서도 보이지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ChatRuntime.instance.socket.deleteMessage(
                message.clientMsgId,
                widget.effectivePeerId,
              );
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.green[200],
      child: Text(
        widget.userName.isNotEmpty ? widget.userName.substring(0, 1) : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.green[100],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _buildProfileAvatar(),
            const SizedBox(width: 10),
            Text(
              widget.userName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            // 연결 상태 표시 (ChatRuntime 미시작 시 회색)
            _buildConnectionDot(),
          ],
        ),
        actions: [
          if (widget.showExitButton)
            TextButton(
              onPressed: _showExitDialog,
              child: const Text(
                '나가기',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.add_photo_alternate,
                      color: Colors.grey,
                    ),
                    onPressed: _uploadImage,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: widget.inputHintText,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final bool isMe;

  _BubbleTailPainter({required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isMe ? const Color(0xFFFFEB3B) : Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();

    if (isMe) {
      path.moveTo(size.width - 6, size.height - 10);
      path.lineTo(size.width + 6, size.height - 6);
      path.lineTo(size.width - 2, size.height - 2);
    } else {
      path.moveTo(6, size.height - 10);
      path.lineTo(-6, size.height - 6);
      path.lineTo(2, size.height - 2);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
