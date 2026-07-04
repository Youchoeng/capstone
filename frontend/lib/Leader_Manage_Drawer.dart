import 'package:flutter/material.dart';
import 'Group_Model.dart';
import 'Personal_Chat_Screen.dart';

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
  Future<void> _showApproveDialog(String userName) async {
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
      _approveRequest(userName);
    }
  }

  // 가입 거절 확인 팝업
  Future<void> _showRejectDialog(String userName) async {
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
      _rejectRequest(userName);
    }
  }

  // 가입 승인 로직
  void _approveRequest(String userName) {
    setState(() {
      widget.group.joinRequests.remove(userName);
      widget.group.members.add(GroupMember(name: userName, isLeader: false));
    });

    widget.onUpdate();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$userName 님의 가입을 승인했습니다.')));
  }

  // 가입 거절 로직
  void _rejectRequest(String userName) {
    setState(() {
      widget.group.joinRequests.remove(userName);
    });

    widget.onUpdate();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$userName 님의 가입을 거절했습니다.')));
  }

  // 멤버 강퇴 로직
  void _kickMember(String userName) {
    setState(() {
      // 1. 모임 명단에서 해당 유저 강퇴
      widget.group.members.removeWhere((member) => member.name == userName);

      // 2. 이 사람이 쓴 모든 게시글의 작성자를 '(알 수 없음)'으로 변경
      for (var post in widget.group.posts) {
        if (post.author == userName) {
          post.author = '(알 수 없음)';
        }
      }

      // 3. 댓글 작성자도 '(알 수 없음)'으로 변경
      for (var post in widget.group.posts) {
        for (var comment in post.comments) {
          if (comment.author == userName) {
            comment.author = '(알 수 없음)';
          }
        }
      }
    });

    widget.onUpdate();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$userName 님을 강퇴했습니다.')));
  }

  // 방장 위임 로직
  void _transferLeader(String newLeaderName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방장 위임'),
        content: Text(
          '$newLeaderName 님에게 방장 권한을 넘기시겠습니까?\n위임 후 승혁 님은 일반 멤버가 됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // 현재 방장 권한 해제
                for (var member in widget.group.members) {
                  if (member.name == '연승혁') {
                    member.isLeader = false;
                  }
                }

                // 새 방장 권한 부여
                for (var member in widget.group.members) {
                  if (member.name == newLeaderName) {
                    member.isLeader = true;
                  }
                }
              });

              Navigator.pop(context); // 팝업 닫기
              Navigator.pop(context); // 서랍 닫기
              widget.onUpdate();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$newLeaderName 님이 새로운 방장이 되었습니다.')),
              );
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

  Widget _buildPendingRequestTile(String userName) {
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
            onPressed: () => _showApproveDialog(userName),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
            onPressed: () => _showRejectDialog(userName),
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
            if (widget.group.joinRequests.isNotEmpty) ...[
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
              ...widget.group.joinRequests.map(
                (userName) => _buildPendingRequestTile(userName),
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
                                onPressed: () => _transferLeader(member.name),
                              ),
                              TextButton(
                                onPressed: () => _kickMember(member.name),
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
          ],
        ),
      ),
    );
  }
}
