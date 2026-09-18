import 'package:flutter/material.dart';
import 'Group_Model.dart';
import 'Personal_Chat_Screen.dart';
import 'api_service.dart';

class LeaderManageDrawer extends StatefulWidget {
  final Group group;
  final VoidCallback onUpdate; // 처리 완료 후 메인 화면도 같이 새로고침하기 위한 콜백

  const LeaderManageDrawer({
    super.key,
    required this.group,
    required this.onUpdate,
  });

  @override
  State<LeaderManageDrawer> createState() => _LeaderManageDrawerState();
}

class _LeaderManageDrawerState extends State<LeaderManageDrawer> {
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    final groupId = int.parse(widget.group.id);
    final requests = await ApiService.getJoinRequests(groupId);
    if (mounted) {
      setState(() {
        if (requests != null) {
          _pendingRequests = List<Map<String, dynamic>>.from(requests);
        }
        _isLoadingRequests = false;
      });
    }
  }

  // 가입 대기자와 1:1 쪽지 화면 열기
  Future<void> _openPendingUserChat(String userName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalChatScreen(
          groupId: int.parse(widget.group.id),
          userName: userName,
        ),
      ),
    );
  }

  // 가입 승인 확인 팝업
  Future<void> _showApproveDialog(Map<String, dynamic> request) async {
    final userName = request['nickname'] ?? '알 수 없음';
    final requestId = request['id'] as int;
    
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('가입 승인'),
        content: const Text('정말 승인하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '승인',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _approveRequest(requestId, userName, request['user_id'] as int);
    }
  }

  // 가입 거절 확인 팝업
  Future<void> _showRejectDialog(Map<String, dynamic> request) async {
    final userName = request['nickname'] ?? '알 수 없음';
    final requestId = request['id'] as int;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('가입 거절'),
        content: const Text('정말 거절하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '거절',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _rejectRequest(requestId, userName);
    }
  }

  // 가입 승인 로직 (API 연동)
  Future<void> _approveRequest(int requestId, String userName, int userId) async {
    final groupId = int.parse(widget.group.id);
    final success = await ApiService.approveJoinRequest(groupId, requestId);
    
    if (!mounted) return;

    if (success) {
      setState(() {
        _pendingRequests.removeWhere((req) => req['id'] == requestId);
        widget.group.members.add(GroupMember(userId: userId, name: userName, isLeader: false));
      });

      widget.onUpdate();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$userName 님의 가입을 승인했습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가입 승인에 실패했습니다.')));
    }
  }

  // 가입 거절 로직 (API 연동)
  Future<void> _rejectRequest(int requestId, String userName) async {
    final groupId = int.parse(widget.group.id);
    final success = await ApiService.rejectJoinRequest(groupId, requestId);
    
    if (!mounted) return;

    if (success) {
      setState(() {
        _pendingRequests.removeWhere((req) => req['id'] == requestId);
      });

      widget.onUpdate();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$userName 님의 가입을 거절했습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가입 거절에 실패했습니다.')));
    }
  }

  // 멤버 강퇴 로직 (API 연동)
  Future<void> _kickMember(GroupMember member) async {
    final groupId = int.parse(widget.group.id);
    final success = await ApiService.kickMember(groupId, member.userId);
    
    if (!mounted) return;

    if (success) {
      setState(() {
        // 1. 모임 명단에서 해당 유저 강퇴
        widget.group.members.removeWhere((m) => m.userId == member.userId);

        // 2. 이 사람이 쓴 모든 게시글의 작성자를 '(알 수 없음)'으로 변경
        for (var post in widget.group.posts) {
          if (post.author == member.name) {
            post.author = '(알 수 없음)';
          }
        }

        // 3. 댓글 작성자도 '(알 수 없음)'으로 변경
        for (var post in widget.group.posts) {
          for (var comment in post.comments) {
            if (comment.author == member.name) {
              comment.author = '(알 수 없음)';
            }
          }
        }
      });

      widget.onUpdate();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${member.name} 님을 강퇴했습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('멤버 강퇴에 실패했습니다.')));
    }
  }

  // 방장 위임 로직 (API 연동)
  void _transferLeader(GroupMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방장 위임'),
        content: Text(
          '${member.name} 님에게 방장 권한을 넘기시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final groupId = int.parse(widget.group.id);
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              final success = await ApiService.transferGroupLeader(groupId, member.userId);
              
              if (!mounted) return;

              if (success) {
                setState(() {
                  // 현재 방장 권한 해제
                  for (var m in widget.group.members) {
                    if (m.isLeader) m.isLeader = false;
                  }
                  // 새 방장 권한 부여
                  member.isLeader = true;
                });

                navigator.pop(); // 팝업 닫기
                navigator.pop(); // 서랍 닫기
                widget.onUpdate();

                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('${member.name} 님이 새로운 방장이 되었습니다.')),
                );
              } else {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('권한 위임에 실패했습니다.')),
                );
              }
            },
            child: const Text(
              '위임하기',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // 모임 해산 로직 (API 연동)
  void _deleteGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모임 해산', style: TextStyle(color: Colors.red)),
        content: const Text('정말 모임을 해산하시겠습니까?\n모든 게시글과 데이터가 영구 삭제되며 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final groupId = int.parse(widget.group.id);
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final success = await ApiService.deleteGroup(groupId);
              
              if (!mounted) return;

              if (success) {
                // 루트 화면(Group_Main_Screen)으로 복귀
                navigator.popUntil((route) => route.isFirst);
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('모임이 해산되었습니다.')),
                );
              } else {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('모임 해산에 실패했습니다.')),
                );
              }
            },
            child: const Text(
              '해산하기',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestTile(Map<String, dynamic> request) {
    final userName = request['nickname'] ?? '알 수 없음';
    return ListTile(
      onTap: () => _openPendingUserChat(userName),
      leading: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openPendingUserChat(userName),
        child: CircleAvatar(
          backgroundColor: Colors.blue[50],
          child: const Icon(Icons.mail_outline, color: Colors.blue),
        ),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontSize: 18),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: request['message'] != null && request['message'].toString().isNotEmpty
          ? Text(request['message'], maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
            onPressed: () => _showApproveDialog(request),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
            onPressed: () => _showRejectDialog(request),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 서랍 머리글
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.green[800],
              child: const Text(
                '모임 관리 (방장 전용)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 1. 가입 대기자 섹션
            if (_isLoadingRequests)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_pendingRequests.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '가입 대기자',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              ..._pendingRequests.map(
                (req) => _buildPendingRequestTile(req),
              ),
              const Divider(thickness: 2),
            ],

            // 2. 현재 멤버 섹션
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '현재 멤버',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView(
                children: widget.group.members.map((member) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      member.name,
                      style: const TextStyle(fontSize: 18),
                    ),
                    trailing: member.isLeader
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.workspace_premium,
                                  color: Colors.amber,
                                ),
                                tooltip: '방장 위임',
                                onPressed: () => _transferLeader(member),
                              ),
                              TextButton(
                                onPressed: () => _kickMember(member),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('강퇴'),
                              ),
                            ],
                          ),
                  );
                }).toList(),
              ),
            ),
            const Divider(thickness: 2),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                '모임 해산',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: _deleteGroup,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
