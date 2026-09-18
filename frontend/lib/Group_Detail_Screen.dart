import 'dart:io';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'Group_Post_Detail_Screen.dart';
import 'Group_Model.dart';
import 'Personal_Chat_Screen.dart';
import 'widgets/group_header.dart';
import 'widgets/group_data.dart';
import 'widgets/group_post_card.dart';
import 'widgets/group_notice_banner.dart';
import 'widgets/common_widget.dart';
import 'widgets/group_dialog.dart';
import 'leader_manage_drawer.dart';
import 'api_service.dart';

// ------------------------------------------------------------------
// 2. 모임 상세 화면
// ------------------------------------------------------------------
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  final String groupName;
  final String userName;
  final bool isMember;
  final bool isLeader;
  final Map<String, Map<String, dynamic>>? initialChatDataByUser;
  final void Function(String userName, Map<String, dynamic> chatData)?
  onChatDataChanged;

  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.groupName,
    required this.userName,
    required this.isMember,
    this.isLeader = false,
    this.initialChatDataByUser,
    this.onChatDataChanged,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  File? _headerImage;

  late List<GroupPost> _posts;
  late List<GroupMember> _members;

  final Map<String, Map<String, dynamic>> _chatDataByUser = Map.from(
    initialChatData,
  );

  Widget _buildAppBarTitle() {
    return InkWell(
      onTap: widget.isMember ? _showMembersSheet : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isMember ? '눌러서 인원 보기' : '가입 후 인원 보기 가능',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(GroupPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupPostDetailScreen(
          post: post,
          userName: widget.userName,
          onUpdate: () => setState(() {}),
        ),
      ),
    );
  }

  void _editPost(GroupPost post) {
    GroupDialogs.showEditPostDialog(
      context: context,
      post: post,
      onUpdated: () => setState(() {}),
    );
  }

  void _deletePost(GroupPost post) async {
    final success = await ApiService.deletePost(post.id);
    if (success) {
      if (mounted) setState(() => _posts.remove(post));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('게시글 삭제 실패')));
      }
    }
  }

  Future<void> _openLeaderJoinChat() async {
    final leader = _members.firstWhere(
      (m) => m.isLeader,
      orElse: () => GroupMember(userId: 0, name: '방장', isLeader: true),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalChatScreen(
          groupId: int.parse(widget.group.id),
          userName: leader.name,
          peerId: leader.userId != 0 ? leader.userId : null,
          showExitButton: false,
          inputHintText: '내용을 입력하세요',
          initialMessages: [
            {
              'text': '안녕하세요.\n자기소개 및 가입하고 싶은 이유 등을\n자유롭게 보내주세요!',
              'isMe': false,
              'time': '방금',
              'isRead': true,
            },
          ],
        ),
      ),
    );
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('가입 요청'),
        content: const Text('이 모임에 가입 신청을 보내시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('방장에게 가입 신청 쪽지 화면으로 이동합니다.')),
              );

              await _openLeaderJoinChat();
            },
            child: const Text('신청하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return widget.isMember
        ? FloatingActionButton.extended(
            heroTag: 'group_detail_write_fab',
            onPressed: _showWritePostDialog,
            backgroundColor: Colors.green[600],
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text('글쓰기', style: TextStyle(color: Colors.white)),
          )
        : FloatingActionButton.extended(
            heroTag: 'group_detail_join_fab',
            onPressed: _showJoinDialog,
            backgroundColor: Colors.blue[600],
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('가입하기', style: TextStyle(color: Colors.white)),
          );
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialChatDataByUser != null) {
      widget.initialChatDataByUser!.forEach((key, value) {
        _chatDataByUser[key] = {
          'lastMessage': value['lastMessage'] ?? '',
          'lastTime': value['lastTime'] ?? '',
          'unreadCount': value['unreadCount'] ?? 0,
          'messages': List<Map<String, dynamic>>.from(
            (value['messages'] as List?)?.map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ) ??
                [],
          ),
        };
      });
    }

    _syncMembersAndChat();
    _fetchGroupData();
  }

  Future<void> _fetchGroupData() async {
    try {
      final detail = await ApiService.getGroupDetail(
        int.parse(widget.group.id),
      );
      if (detail != null && mounted) {
        setState(() {
          _members = (detail['members'] as List)
              .map(
                (m) => GroupMember(
                  userId: m['user_id'] ?? 0,
                  name: m['nickname'] ?? '알 수 없음',
                  isLeader: m['is_leader'] == true,
                ),
              )
              .toList();

          for (var member in _members) {
            if (member.name != widget.userName &&
                !_chatDataByUser.containsKey(member.name)) {
              _chatDataByUser[member.name] = {
                'lastMessage': '',
                'lastTime': '',
                'unreadCount': 0,
                'messages': [],
              };
            }
          }
        });
      }

      final posts = await ApiService.getGroupPosts(int.parse(widget.group.id));
      if (posts != null && mounted) {
        setState(() {
          _posts = posts;
        });
      }
    } catch (e) {
      debugPrint('Error fetching group data: $e');
    }
  }

  void _syncMembersAndChat() {
    _members = List.from(widget.group.members);
    _posts = List.from(widget.group.posts);

    for (var member in _members) {
      if (member.name != widget.userName &&
          !_chatDataByUser.containsKey(member.name)) {
        _chatDataByUser[member.name] = {
          'lastMessage': '',
          'lastTime': '',
          'unreadCount': 0,
          'messages': [],
        };
      }
    }
  }

  Future<void> _pickHeaderImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _headerImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('배경 사진 선택 에러: $e');
    }
  }

  void _markMemberChatAsRead(String userName) {
    final chatData = _chatDataByUser[userName];
    if (chatData == null) return;

    final updatedMessages = List<Map<String, dynamic>>.from(
      (chatData['messages'] as List?)?.map(
            (e) => Map<String, dynamic>.from(e as Map),
          ) ??
          [],
    );

    for (final msg in updatedMessages) {
      if (msg['isMe'] == false) {
        msg['isRead'] = true;
      }
    }

    final updatedChatData = {
      'lastMessage': (chatData['lastMessage'] ?? '').toString(),
      'lastTime': (chatData['lastTime'] ?? '').toString(),
      'unreadCount': 0,
      'messages': updatedMessages,
    };

    setState(() {
      _chatDataByUser[userName] = updatedChatData;
    });

    widget.onChatDataChanged?.call(userName, updatedChatData);
  }

  Future<void> _openPersonalChat(GroupMember member) async {
    _markMemberChatAsRead(member.name);

    final chatData = _chatDataByUser[member.name];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalChatScreen(
          groupId: int.parse(widget.group.id),
          userName: member.name,
          peerId: member.userId != 0 ? member.userId : null,
          initialMessages: chatData != null
              ? List<Map<String, dynamic>>.from(
                  (chatData['messages'] as List).map(
                    (e) => Map<String, dynamic>.from(e as Map),
                  ),
                )
              : null,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      // 🌟 [추가] 쪽지방 나가기를 눌렀을 때
      if (result['didLeaveChat'] == true) {
        setState(() {
          // 상세 화면 내부의 기억 초기화 (다시 쪽지 보내면 빈 방부터 시작하도록 싹 비움)
          _chatDataByUser[member.name] = {
            'lastMessage': '',
            'lastTime': '',
            'unreadCount': 0,
            'messages': [],
          };
        });

        // 메인 화면으로도 "이 사람 쪽지방 나갔어!" 하고 신호를 그대로 전달
        widget.onChatDataChanged?.call(member.name, result);
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('쪽지방에서 나갔습니다.')));
      }
      // 일반적인 대화 후 뒤로가기를 눌렀을 때 (기존 로직)
      else {
        final updatedChatData = {
          'lastMessage': result['lastMessage'] ?? '',
          'lastTime': result['lastTime'] ?? '',
          'unreadCount': result['unreadCount'] ?? 0,
          'messages': List<Map<String, dynamic>>.from(
            (result['messages'] as List?)?.map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ) ??
                [],
          ),
        };

        setState(() {
          _chatDataByUser[member.name] = updatedChatData;
        });

        widget.onChatDataChanged?.call(member.name, updatedChatData);
      }
    }
  }

  void _showMembersSheet() {
    final sortedMembers = [..._members]
      ..sort((a, b) {
        if (a.isLeader && !b.isLeader) return -1;
        if (!a.isLeader && b.isLeader) return 1;
        return a.name.compareTo(b.name);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(bottomSheetContext).size.height * 0.72,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.group, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '모임 사람들 (${sortedMembers.length})',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sortedMembers.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72, endIndent: 16),
                    itemBuilder: (context, index) {
                      final member = sortedMembers[index];
                      final chatData = _chatDataByUser[member.name];
                      final lastMessage = (chatData?['lastMessage'] ?? '')
                          .toString();
                      final lastTime = (chatData?['lastTime'] ?? '').toString();
                      final unreadCount =
                          (chatData?['unreadCount'] ?? 0) as int;

                      return ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            buildProfileAvatar(
                              name: member.name,
                              imageUrl: member.profileImageUrl,
                              radius: 22,
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                member.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: member.isLeader
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (member.isLeader) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '(회장)',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: lastMessage.isEmpty
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: unreadCount > 0
                                              ? Colors.black87
                                              : Colors.grey[700],
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (lastTime.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        lastTime,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                        trailing: TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(bottomSheetContext);
                            await _openPersonalChat(member);
                          },
                          icon: const Icon(
                            Icons.mail_outline,
                            size: 18,
                            color: Colors.blue,
                          ),
                          label: const Text(
                            '쪽지',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWritePostDialog() {
    GroupDialogs.showWritePostDialog(
      context: context,
      userName: widget.userName,
      isLeader: widget.isLeader,
      onSubmitted: (newPost) async {
        String? uploadedUrl;
        if (newPost.imageUrl != null && newPost.imageUrl!.isNotEmpty) {
          uploadedUrl = await ApiService.uploadPostImage(
            File(newPost.imageUrl!),
          );
        }

        final postId = await ApiService.createGroupPost(
          int.parse(widget.group.id),
          title: newPost.title,
          content: newPost.content,
          isAnonymous: false,
          isNotice: newPost.isNotice,
          attachmentUrl: uploadedUrl,
        );

        if (postId != null) {
          await _fetchGroupData();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('게시글 작성에 실패했습니다.')));
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = _posts.where((post) {
      if (!widget.isMember && post.isPrivate) return false;
      return true;
    }).toList();

    final notices = visiblePosts.where((p) => p.isNotice).toList();
    final normalPosts = visiblePosts.where((p) => !p.isNotice).toList();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      endDrawer: widget.isLeader
          ? LeaderManageDrawer(
              group: widget.group,
              onUpdate: () {
                setState(() {
                  _syncMembersAndChat();
                });
              },
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.green[100],
        centerTitle: false,
        titleSpacing: 12,
        toolbarHeight: 72,
        title: _buildAppBarTitle(),
        actions: [
          if (widget.isLeader)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.people_alt,
                  size: 30,
                  color: Colors.black87,
                ),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          GroupHeader(
            headerImage: _headerImage,
            isLeader: widget.isLeader,
            onPickImage: _pickHeaderImage,
          ),
          if (notices.isNotEmpty)
            GroupNoticeBanner(
              post: notices.first,
              onTap: () => _navigateToDetail(notices.first),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final post = normalPosts[index];
              return GroupPostCard(
                post: post,
                userName: widget.userName,
                isLeader: widget.isLeader,
                onTap: () => _navigateToDetail(post),
                onEdit: () => _editPost(post),
                onDelete: () => _deletePost(post),
              );
            }, childCount: normalPosts.length),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }
}
