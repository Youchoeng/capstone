// ─────────────────────────────────────────────────────────────
// 채팅 목록 화면 (1:1 쪽지 목록)
// ─────────────────────────────────────────────────────────────
//
// LocalChatDb 의 conversations 테이블을 읽어
// 실제 대화 목록을 표시한다.
// 이 화면이 열려있는 동안 WebSocket 을 연결하여
// 실시간 메시지 수신이 가능하다.

import 'dart:async';
import 'package:flutter/material.dart';

import 'Personal_Chat_Screen.dart';
import 'services/chat_runtime.dart';
import 'services/local_chat_db.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = '';

  List<Conversation> _conversations = [];
  StreamSubscription<StoredMessage>? _messageSub;

  @override
  void initState() {
    super.initState();

    // ── 채팅 목록 화면도 WS 연결 (ref-count) ──
    ChatRuntime.instance.connectSocket();

    _loadConversations();

    // 새 메시지 도착 시 목록 갱신
    _messageSub = LocalChatDb.instance.messageStream.listen((_) {
      _loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSub?.cancel();
    // ── 화면 이탈 → WS 해제 (ref-count) ──
    ChatRuntime.instance.disconnectSocket();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final list = await LocalChatDb.instance.listConversations();
    if (!mounted) return;
    setState(() {
      _conversations = list;
    });
  }

  // 🛠️ [수정] 모임방 식별 번호로도 쪽지방을 검색할 수 있도록 필터링 조건을 확장했습니다.
  List<Conversation> get _filteredConversations {
    final keyword = _searchKeyword.trim().toLowerCase();
    if (keyword.isEmpty) return _conversations;
    return _conversations.where((c) {
      final peerMatch = c.peerNickname.toLowerCase().contains(keyword);
      final msgMatch = (c.lastMessage ?? '').toLowerCase().contains(keyword);
      final groupMatch =
          '모임 ${c.groupId}'.contains(keyword) ||
          c.groupId.toString() == keyword;

      return peerMatch || msgMatch || groupMatch;
    }).toList();
  }

  int get _totalUnreadCount {
    return _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  void _goBackWithUnreadCount() {
    Navigator.pop(context, _totalUnreadCount);
  }

  String _formatTime(DateTime? utc) {
    if (utc == null) return '';
    final local = utc.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) {
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? '오후' : '오전';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$period $displayHour:$minute';
    }
    if (diff.inDays == 1) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${local.month}/${local.day}';
  }

  Future<void> _openChat(Conversation conv) async {
    // 읽음 처리
    await LocalChatDb.instance.markRead(conv.groupId, conv.peerId);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalChatScreen(
          groupId: conv.groupId,
          userName: conv.peerNickname.isEmpty
              ? '사용자 ${conv.peerId}'
              : conv.peerNickname,
          peerId: conv.peerId,
        ),
      ),
    );

    // 돌아왔을 때 목록 새로고침
    _loadConversations();
  }

  Widget _buildUnreadBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conv) {
    final hasUnread = conv.unreadCount > 0;
    final baseName = conv.peerNickname.isEmpty
        ? '사용자 ${conv.peerId}'
        : conv.peerNickname;

    // 🛠️ [핵심 수정]: 단순히 유저 이름만 보여주던 방식에서 앞에 [모임 X] 머리말을 강제로 결합합니다.
    final displayName = '[모임 ${conv.groupId}] $baseName';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: hasUnread ? Colors.green[100] : Colors.grey[200],
        child: Text(
          baseName.isNotEmpty ? baseName.substring(0, 1) : '?',
          style: TextStyle(
            color: hasUnread ? Colors.green[800] : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
          fontSize: 16,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          conv.lastMessage ?? '대화를 시작해보세요.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasUnread ? Colors.black87 : Colors.grey[700],
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      trailing: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(conv.lastMessageAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            _buildUnreadBadge(conv.unreadCount),
          ],
        ),
      ),
      onTap: () => _openChat(conv),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchKeyword = value;
          });
        },
        decoration: InputDecoration(
          hintText: '대화 상대 또는 모임 번호 검색',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchKeyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchKeyword = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredConversations;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackWithUnreadCount();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('쪽지함'),
          backgroundColor: Colors.green[100],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackWithUnreadCount,
          ),
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        '대화가 없습니다.\n상대방의 프로필에서 쪽지를 보내보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, index) {
                        return _buildConversationTile(visible[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
