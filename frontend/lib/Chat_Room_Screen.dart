//채팅 화면에서 각 채팅 들어가기

import 'package:flutter/material.dart';

const String currentUserName = '연승혁';

// ------------------------------------------------------------------
// 메시지 모델
// ------------------------------------------------------------------
class ChatMessage {
  String senderName;
  String text;
  bool isMe;
  String time;
  bool isSystem;

  ChatMessage({
    required this.senderName,
    required this.text,
    required this.isMe,
    required this.time,
    this.isSystem = false,
  });
}

// ------------------------------------------------------------------
// 채팅방 모델
// ------------------------------------------------------------------
class ChatRoom {
  List<String> participants;
  String time;
  int unreadCount;
  List<ChatMessage> messages;
  String? customTitle;

  ChatRoom({
    required this.participants,
    required this.time,
    required this.unreadCount,
    required this.messages,
    this.customTitle,
  });

  String get chatTitle {
    if (customTitle != null && customTitle!.trim().isNotEmpty) {
      return customTitle!;
    }
    return autoTitle;
  }

  String get autoTitle {
    final others =
    participants.where((name) => name != currentUserName).toList();

    if (others.isEmpty) return '나와의 채팅';

    if (others.length <= 2) {
      return others.join(', ');
    }

    final firstTwo = others.take(2).join(', ');
    final restCount = others.length - 2;
    return '$firstTwo 외 $restCount명';
  }

  String get lastMessage {
    if (messages.isEmpty) return '대화를 시작해보세요.';
    return messages.last.text;
  }
}

// ------------------------------------------------------------------
// 공용 저장소
// ------------------------------------------------------------------
class ChatRepository {
  ChatRepository._();

  static final List<ChatRoom> chats = [
    ChatRoom(
      participants: [currentUserName, '김철수', '박민수', '김수민'],
      time: '오전 10:30',
      unreadCount: 2,
      messages: [
        ChatMessage(
          senderName: '',
          text: '2026년 3월 20일',
          isMe: false,
          time: '',
          isSystem: true,
        ),
        ChatMessage(
          senderName: '김철수',
          text: '이번 주 토요일 9시 맞죠?',
          isMe: false,
          time: '오전 10:21',
        ),
        ChatMessage(
          senderName: '박민수',
          text: '저는 물이랑 간식 챙겨갈게요.',
          isMe: false,
          time: '오전 10:22',
        ),
        ChatMessage(
          senderName: currentUserName,
          text: '네 맞아요! 등산화 챙겨주세요.',
          isMe: true,
          time: '오전 10:23',
        ),
      ],
    ),
    ChatRoom(
      participants: [currentUserName, '이영희'],
      time: '어제',
      unreadCount: 1,
      messages: [
        ChatMessage(
          senderName: '',
          text: '2026년 3월 19일',
          isMe: false,
          time: '',
          isSystem: true,
        ),
        ChatMessage(
          senderName: '이영희',
          text: '사진 저장하는 방법 알려드릴게요!',
          isMe: false,
          time: '오후 3:10',
        ),
        ChatMessage(
          senderName: currentUserName,
          text: '감사합니다. 그거 꼭 배우고 싶어요.',
          isMe: true,
          time: '오후 3:11',
        ),
      ],
    ),
    ChatRoom(
      participants: [currentUserName, '정유진'],
      time: '3일 전',
      unreadCount: 0,
      messages: [
        ChatMessage(
          senderName: '',
          text: '2026년 3월 17일',
          isMe: false,
          time: '',
          isSystem: true,
        ),
        ChatMessage(
          senderName: '정유진',
          text: '다음 준비물은 붓 3종입니다.',
          isMe: false,
          time: '오전 9:00',
        ),
        ChatMessage(
          senderName: currentUserName,
          text: '혹시 초보도 참여 가능한가요?',
          isMe: true,
          time: '오전 9:04',
        ),
        ChatMessage(
          senderName: '정유진',
          text: '네, 초보분들도 환영입니다!',
          isMe: false,
          time: '오전 9:07',
        ),
      ],
    ),
    ChatRoom(
      participants: [currentUserName, '김철수', '박민수', '김수민', '이영희'],
      time: '방금 전',
      unreadCount: 3,
      messages: [
        ChatMessage(
          senderName: '',
          text: '2026년 3월 20일',
          isMe: false,
          time: '',
          isSystem: true,
        ),
        ChatMessage(
          senderName: '김철수',
          text: '오늘 회의 자료 다들 확인해주세요!',
          isMe: false,
          time: '오전 11:10',
        ),
        ChatMessage(
          senderName: '김수민',
          text: '저는 발표 파트 맡을게요.',
          isMe: false,
          time: '오전 11:12',
        ),
      ],
    ),
  ];

  static int get totalUnreadCount {
    return chats.fold(0, (sum, chat) => sum + chat.unreadCount);
  }
}

// ------------------------------------------------------------------
// 채팅방 화면
// ------------------------------------------------------------------
class ChatRoomScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomScreen({
    super.key,
    required this.chatRoom,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _getCurrentTimeText() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$period $displayHour:$minute';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      widget.chatRoom.messages.add(
        ChatMessage(
          senderName: currentUserName,
          text: text,
          isMe: true,
          time: _getCurrentTimeText(),
        ),
      );
      widget.chatRoom.time = '방금 전';
    });

    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _deleteMyMessage(int index) {
    final msg = widget.chatRoom.messages[index];
    if (msg.isSystem || !msg.isMe) return;

    setState(() {
      widget.chatRoom.messages.removeAt(index);
      widget.chatRoom.time = '방금 전';
    });
  }

  void _showEditTitleDialog() {
    final controller = TextEditingController(text: widget.chatRoom.chatTitle);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('채팅방 이름 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '채팅방 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '기본 이름: ${widget.chatRoom.autoTitle}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.chatRoom.customTitle = null;
                });
                Navigator.pop(context);
              },
              child: const Text('기본값으로'),
            ),
            ElevatedButton(
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isEmpty) return;

                setState(() {
                  widget.chatRoom.customTitle = newTitle;
                });

                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  void _showParticipantsBottomSheet() {
    final TextEditingController newParticipantController =
    TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Wrap(
                children: [
                  const Center(
                    child: Text(
                      '채팅 인원',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...widget.chatRoom.participants.map(
                        (name) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: name == currentUserName
                            ? Colors.green[100]
                            : Colors.grey[200],
                        child: Icon(
                          Icons.person,
                          color: name == currentUserName
                              ? Colors.green
                              : Colors.grey[700],
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(name == currentUserName ? '나' : '참여자'),
                    ),
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: newParticipantController,
                    decoration: const InputDecoration(
                      labelText: '새로운 사람 추가',
                      hintText: '이름 입력',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final newName = newParticipantController.text.trim();

                        if (newName.isEmpty) return;
                        if (widget.chatRoom.participants.contains(newName)) {
                          return;
                        }

                        setState(() {
                          widget.chatRoom.participants.add(newName);
                        });

                        modalSetState(() {});
                        newParticipantController.clear();
                      },
                      child: const Text('추가'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('사진 보내기'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('사진 보내기 기능은 추후 연결 가능합니다.'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('파일 보내기'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('파일 보내기 기능은 추후 연결 가능합니다.'),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildNormalMessage(ChatMessage message, int index) {
    final isMe = message.isMe;

    if (isMe) {
      return GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('메시지 삭제'),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMyMessage(index);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Text(
                  message.time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.yellow[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, size: 16, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chatRoom.messages;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F6),
      appBar: AppBar(
        backgroundColor: Colors.green[100],
        title: GestureDetector(
          onTap: _showParticipantsBottomSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.chatRoom.chatTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                '눌러서 인원 보기',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditTitleDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                if (message.isSystem) {
                  return _buildSystemMessage(message);
                }
                return _buildNormalMessage(message, index);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _showMoreMenu,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.green,
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
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