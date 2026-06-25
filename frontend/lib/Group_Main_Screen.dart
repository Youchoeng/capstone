import 'dart:async';
import 'package:flutter/material.dart';
import 'Group_Detail_Screen.dart';
import 'Group_Search_Screen.dart';
import 'Personal_Chat_Screen.dart';
import 'Group_Create_Screen.dart';
import 'Group_Model.dart';
import 'api_service.dart';

const String currentUserName = '연승혁';

// ------------------------------------------------------------------
// 1. 데이터 모델
// ------------------------------------------------------------------

class ChatItem {
  final int peerId;
  final String name;
  String lastMessage;
  String timeAgo;
  int unreadCount;
  bool isRead;
  List<Map<String, dynamic>> messages;

  ChatItem({
    required this.peerId,
    required this.name,
    required this.lastMessage,
    required this.timeAgo,
    this.unreadCount = 0,
    this.isRead = false,
    List<Map<String, dynamic>>? messages,
  }) : messages = messages ?? [];
}

// ------------------------------------------------------------------
// 2. 메인 화면
// ------------------------------------------------------------------
class GroupMainScreen extends StatefulWidget {
  const GroupMainScreen({super.key});

  @override
  State<GroupMainScreen> createState() => _GroupMainScreenState();
}

class _GroupMainScreenState extends State<GroupMainScreen> {
  List<Group> _myGroups = [];

  final List<ChatItem> _chatItems = [];

  // ── REST 폴링 기반 쪽지 상태 ──
  List<Map<String, dynamic>> _inboxItems = [];
  int _inboxUnreadTotal = 0;
  int? _myInternalId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadServerGroups();
    _startInboxPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ─── 쪽지 폴링 ────────────────────────────────────────────────
  void _startInboxPolling() async {
    // 함수가 실행되자마자 기존 타이머가 있다면 '즉시' 취소해서 좀비 생성을 막습니다.
    _pollTimer?.cancel();
    _pollTimer = null;

    try {
      await ApiService.loadSavedAuth();
      final me = await ApiService.getMe();

      // 비동기(await) 처리가 끝난 시점에 화면이 이미 꺼졌다면(dispose) 이후 로직을 실행하지 않습니다.
      if (!mounted) return;

      _myInternalId = me?['internal_id'] as int?;
      if (_myInternalId == null) return;

      // await 대기 도중에 다른 함수 통로로 타이머가 이미 생성되었는지 교차 검증합니다.
      if (_pollTimer != null) return;

      // 최초 1회 즉시 실행
      await _pollInbox();

      if (!mounted) return;

      // 정확히 단 하나만 제어 가능한 타이머 생성
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollInbox(),
      );
      debugPrint("🎯 인박스 폴링 타이머가 정상적으로 1개 가동되었습니다.");
    } catch (e) {
      debugPrint('폴링 시작 실패: $e');
    }
  }

  Future<void> _pollInbox() async {
    final id = _myInternalId;
    if (id == null) return;

    try {
      final items = await ApiService.getChatInbox(id);

      // 시간 역순 정렬
      items.sort((a, b) {
        final at = (b['last_message_at'] as String?) ?? '';
        final bt = (a['last_message_at'] as String?) ?? '';
        return at.compareTo(bt);
      });

      final total = items.fold<int>(
        0,
        (s, e) => s + ((e['unread_count'] as int?) ?? 0),
      );

      if (mounted) {
        setState(() {
          _inboxItems = items;
          _inboxUnreadTotal = total;
        });
      }
    } catch (e) {
      debugPrint('인박스 폴링 실패: $e');
    }
  }

  Future<void> _loadServerGroups() async {
    try {
      await ApiService.loadSavedAuth();
      final groups = await ApiService.getMyGroups();
      if (groups != null) {
        setState(() {
          _myGroups = groups
              .map<Group>((json) => Group.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('모임 목록 로드 실패: $e');
    }
  }

  // "새 알림만 남는 구조"이므로 읽지 않은 개수 = 현재 알림 개수
  int get _unreadCount => globalNotifications.length;

  // REST 폴링 기반 실제 쪽지 개수
  int get _unreadChatCount => _inboxUnreadTotal;

  Widget _buildBadge(String count) {
    return Container(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Text(
        count,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _sortChatItemsByLatest() {
    _chatItems.sort((a, b) {
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
      return 0;
    });
  }

  // ------------------------------------------------------------------
  // 쪽지 읽음 처리
  // ------------------------------------------------------------------
  void _markChatAsReadByName(String userName) {
    final index = _chatItems.indexWhere((item) => item.name == userName);
    if (index == -1) return;

    setState(() {
      _chatItems[index].unreadCount = 0;
      _chatItems[index].isRead = true;

      for (final msg in _chatItems[index].messages) {
        if (msg['isMe'] == false) {
          msg['isRead'] = true;
        }
      }

      _sortChatItemsByLatest();
    });
  }

  Map<String, Map<String, dynamic>> _buildChatDataMap() {
    final Map<String, Map<String, dynamic>> data = {};

    for (final chat in _chatItems) {
      data[chat.name] = {
        'lastMessage': chat.lastMessage,
        'lastTime': chat.timeAgo,
        'unreadCount': chat.unreadCount,
        'messages': List<Map<String, dynamic>>.from(
          chat.messages.map((e) => Map<String, dynamic>.from(e)),
        ),
      };
    }

    return data;
  }

  void _updateChatItemFromResult(
    int peerId,
    String userName,
    Map<String, dynamic> chatData,
  ) {
    // 🌟 [추가] 모임 상세 화면에서 넘어온 데이터에 '방 나감' 꼬리표가 있다면?
    if (chatData['didLeaveChat'] == true) {
      setState(() {
        _chatItems.removeWhere((item) => item.name == userName); // 싹둑 잘라냅니다.
      });
      return; // 지웠으니 더 이상 업데이트 할 필요 없음! (함수 종료)
    }

    final index = _chatItems.indexWhere((item) => item.name == userName);
    if (index != -1) {
      setState(() {
        _chatItems[index].lastMessage = chatData['lastMessage'] ?? '';
        _chatItems[index].timeAgo = chatData['lastTime'] ?? '';
        _chatItems[index].unreadCount = chatData['unreadCount'] ?? 0;
        _chatItems[index].messages = List<Map<String, dynamic>>.from(
          chatData['messages'] ?? [],
        );
        _sortChatItemsByLatest();
      });
    }

    final updatedMessages = List<Map<String, dynamic>>.from(
      (chatData['messages'] as List?)?.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ) ??
          [],
    );

    final String updatedLastMessage = (chatData['lastMessage'] ?? '')
        .toString();
    final String updatedLastTime = (chatData['lastTime'] ?? '').toString();
    final int updatedUnreadCount = (chatData['unreadCount'] ?? 0) as int;

    setState(() {
      if (index != -1) {
        //_chatItems[index].peerId = peerId;
        _chatItems[index].messages = updatedMessages;
        _chatItems[index].lastMessage = updatedLastMessage;
        _chatItems[index].timeAgo = updatedLastTime;
        _chatItems[index].unreadCount = updatedUnreadCount;
        _chatItems[index].isRead = updatedUnreadCount == 0;
      } else {
        _chatItems.add(
          ChatItem(
            peerId: peerId,
            name: userName,
            lastMessage: updatedLastMessage,
            timeAgo: updatedLastTime,
            unreadCount: updatedUnreadCount,
            isRead: updatedUnreadCount == 0,
            messages: updatedMessages,
          ),
        );
      }

      _sortChatItemsByLatest();
    });

    // 채팅 메시지 확인 후, 즉시 폴링해서 최신 상태 동기화
    _pollInbox();
  }

  // ignore: unused_element
  Future<void> _openChat(
    ChatItem chat,
    BuildContext context,
    BuildContext bottomSheetContext,
  ) async {
    // 채팅방을 여는 순간 읽음 처리
    _markChatAsReadByName(chat.name);
    Navigator.pop(bottomSheetContext); // 바텀시트 닫기

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalChatScreen(
          userName: chat.name,
          peerId: chat.peerId,
          initialMessages: chat.messages,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      if (result['didLeaveChat'] == true) {
        setState(() {
          // 쪽지 목록에서 날려버림!
          _chatItems.removeWhere((item) => item.name == chat.name);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('쪽지방에서 나갔습니다.')));
      }
      // 나가기가 아니면 원래대로 업데이트
      else {
        _updateChatItemFromResult(chat.peerId, chat.name, result);
      }
    } else {
      setState(() {
        _sortChatItemsByLatest();
      });
    }
  }

  // ------------------------------------------------------------------
  // 일반 알림 바텀시트
  // 읽지 않은 알림만 보여줍니다.
  // 알림을 누르면 읽음 처리되어 목록에서 사라집니다.
  // ------------------------------------------------------------------
  void _removeNotificationAt(int index) {
    if (index < 0 || index >= globalNotifications.length) return;

    setState(() {
      globalNotifications.removeAt(index);
    });
  }

  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SizedBox(
          height: 420,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                '알림',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                // 🌟 _notifications 대신 globalNotifications 사용!
                child: globalNotifications.isEmpty
                    ? const Center(
                        child: Text(
                          '새로운 알림이 없습니다.',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        // 🌟 여기도 변경!
                        itemCount: globalNotifications.length,
                        itemBuilder: (context, index) {
                          // 🌟 여기도 변경!
                          final noti = globalNotifications[index];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[100],
                              child: const Icon(
                                Icons.notifications,
                                color: Colors.green,
                              ),
                            ),
                            title: Text(
                              noti.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(noti.content),
                            trailing: Text(
                              noti.timeAgo,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            onTap: () {
                              // 알림 확인 즉시 목록에서 제거
                              _removeNotificationAt(index);
                              // 바텀시트 닫기
                              Navigator.pop(bottomSheetContext);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) => setState(() {}));
  }

  // ------------------------------------------------------------------
  // 쪽지 알림 바텀시트
  // ------------------------------------------------------------------
  void _showChatBottomSheet() {
    // \ud3f4\ub9c1\uc73c\ub85c \uc774\ubbf8 \ucd5c\uc2e0\ud654\ub41c _inboxItems \uad6c\ub3c0 unread \uc788\ub294 \ud56d\ubaa9\ub9cc \ud45c\uc2dc
    final unreadInbox = _inboxItems
        .where((item) => ((item['unread_count'] as int?) ?? 0) > 0)
        .toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SizedBox(
          height: 420,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text(
                '\ucabd\uc9c0',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: unreadInbox.isEmpty
                    ? const Center(
                        child: Text(
                          '\uc0c8\ub85c\uc6b4 \ucabd\uc9c0\uac00 \uc5c6\uc2b5\ub2c8\ub2e4.',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: unreadInbox.length,
                        itemBuilder: (context, index) {
                          final item = unreadInbox[index];
                          final peerId = item['peer_id'] as int;
                          final peerNickname =
                              (item['peer_nickname'] as String?) ?? '';
                          final lastMessage =
                              (item['last_message'] as String?) ?? '';
                          final unreadCount =
                              (item['unread_count'] as int?) ?? 0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.yellow[100],
                              child: const Icon(
                                Icons.person,
                                color: Colors.orange,
                              ),
                            ),
                            title: Text(
                              peerNickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(bottomSheetContext);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PersonalChatScreen(
                                    userName: peerNickname,
                                    peerId: peerId,
                                  ),
                                ),
                              );
                              // \ucabd\uc9c0 \uc77d\uace0 \ub098\uba74 \uc989\uc2dc \ud3f4\ub9c1\ud558\uc5ec \ubc30\uc9c0 \uac31\uc2e0
                              await _pollInbox();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) => setState(() {}));
  }

  bool _isCurrentUserLeader(Group group) {
    return group.checkIsLeader(currentUserName);
  }

  Widget _buildGroupCard(Group group, {required bool isMember}) {
    final bool isLeader = _isCurrentUserLeader(group);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          _pollTimer?.cancel();
          _pollTimer = null;
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupDetailScreen(
                group: group,
                groupName: group.name,
                userName: currentUserName,
                isMember: isMember,
                isLeader: isLeader,
                initialChatDataByUser: _buildChatDataMap(),
                onChatDataChanged: (userName, chatData) {
                  final int currentPeerId =
                      chatData['peer_id'] ?? chatData['peerId'] ?? 0;
                  _updateChatItemFromResult(currentPeerId, userName, chatData);
                },
              ),
            ),
          );
          if (mounted) {
            // 1. [추가] 메인 화면으로 복귀했으므로 다시 5초 폴링 타이머를 가동합니다.
            debugPrint("🔄 메인 화면 복귀: 인박스 폴링 재시작");
            _startInboxPolling();

            if (result == true) {
              setState(() {
                _myGroups.removeWhere((g) => g.id == group.id);
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('목록에서 모임이 삭제되었습니다.')),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  group.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.group,
                      size: 36,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      group.description,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount}명 참여 중',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isLeader) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '모임장',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindNewGroupCard() {
    return Card(
      margin: const EdgeInsets.only(top: 10, bottom: 30),
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade300, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GroupSearchScreen()),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 30.0),
          child: Column(
            children: [
              Icon(Icons.search, size: 40, color: Colors.green),
              SizedBox(height: 8),
              Text(
                '새로운 모임 찾아보기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '모임',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[100],
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, size: 30),
                onPressed: _showNotificationBottomSheet,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 12,
                  top: 12,
                  child: _buildBadge('$_unreadCount'),
                ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 28),
                onPressed: _showChatBottomSheet,
              ),
              if (_unreadChatCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: _buildBadge('$_unreadChatCount'),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '내 모임',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ..._myGroups.map((group) => _buildGroupCard(group, isMember: true)),
          _buildFindNewGroupCard(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'group_fab',
        onPressed: () async {
          final newGroupData = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const GroupCreateScreen(currentUser: '연승혁'),
            ),
          );

          if (newGroupData != null && newGroupData is Map<String, dynamic>) {
            setState(() {
              _myGroups.add(
                Group(
                  id:
                      (newGroupData['id'] ??
                              DateTime.now().millisecondsSinceEpoch)
                          .toString(),
                  name: newGroupData['name'] ?? '',
                  description: newGroupData['description'] ?? '',
                  imageUrl: 'https://via.placeholder.com/300',
                  memberCount: newGroupData['memberCount'] ?? 1,
                  isMember: true,
                  members: [GroupMember(name: currentUserName, isLeader: true)],
                ),
              );
            });

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('새 모임이 생성되었습니다!')));
          }
        },
        icon: const Icon(Icons.add_circle_outline, size: 28),
        label: const Text(
          '새 모임 만들기',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
    );
  }
}
