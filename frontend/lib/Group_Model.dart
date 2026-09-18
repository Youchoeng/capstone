// group_models.dart

// 1. 부모 댓글 (GroupComment)
// ------------------------------------------------------------------
class GroupComment {
  int id;
  String author;
  String content;
  int likeCount;     // 승혁님 기존 기능 유지!
  bool isLiked;      // 승혁님 기존 기능 유지!
  bool isMine;       // 승혁님 기존 기능 유지!
  String timeAgo;    // 작성 시간 추가

  // 자식 답글 주머니 (GroupReply 전용 리스트로 변경)
  List<GroupReply> replies;

  GroupComment({
    this.id = 0,
    required this.author,
    required this.content,
    this.likeCount = 0,
    this.isLiked = false,
    this.isMine = false,
    this.timeAgo = '방금 전',
    List<GroupReply>? replies,
  }) : replies = replies ?? [];

  factory GroupComment.fromJson(Map<String, dynamic> json) {
    return GroupComment(
      id: json['id'] ?? 0,
      author: json['author'] ?? '',
      content: json['content'] ?? '',
      likeCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      timeAgo: json['created_at'] != null ? _timeAgo(json['created_at']) : '방금 전',
      replies: (json['replies'] as List<dynamic>?)
              ?.map((e) => GroupReply.fromJson(e))
              .toList() ??
          [],
    );
  }

  static String _timeAgo(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final difference = DateTime.now().difference(dateTime);
      if (difference.inDays > 0) return '${difference.inDays}일 전';
      if (difference.inHours > 0) return '${difference.inHours}시간 전';
      if (difference.inMinutes > 0) return '${difference.inMinutes}분 전';
      return '방금 전';
    } catch (e) {
      return dateTimeStr;
    }
  }
}
// 2. 자식 대댓글 (GroupReply) - 새로 추가
// ------------------------------------------------------------------
class GroupReply {
  int id;
  String author;
  String content;
  int likeCount;     // 답글에도 좋아요 가능!
  bool isLiked;
  bool isMine;
  String timeAgo;

  GroupReply({
    this.id = 0,
    required this.author,
    required this.content,
    this.likeCount = 0,
    this.isLiked = false,
    this.isMine = false,
    this.timeAgo = '방금 전',
  });

  factory GroupReply.fromJson(Map<String, dynamic> json) {
    return GroupReply(
      id: json['id'] ?? 0,
      author: json['author'] ?? '',
      content: json['content'] ?? '',
      likeCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      timeAgo: json['created_at'] != null ? GroupComment._timeAgo(json['created_at']) : '방금 전',
    );
  }
}

class GroupPost {
  int id;
  String title;
  String author;
  String content; // 수정 가능하도록 final 제거
  final String timeAgo;
  final bool isNotice;
  final bool isPrivate;
  String? imageUrl; // 수정 가능하도록 final 제거
  final String? videoUrl;
  String? attachmentUrl;
  int likeCount;
  bool isLiked;
  List<GroupComment> comments;

  GroupPost({
    this.id = 0,
    this.title = '',
    required this.author,
    required this.content,
    required this.timeAgo,
    this.isNotice = false,
    this.isPrivate = false,
    this.imageUrl,
    this.videoUrl,
    this.attachmentUrl,
    this.likeCount = 0,
    this.isLiked = false,
    this.comments = const [],
  });

  factory GroupPost.fromJson(Map<String, dynamic> json) {
    return GroupPost(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      author: json['author'] ?? '',
      likeCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      attachmentUrl: json['attachment_url'],
      imageUrl: json['attachment_url'], // 만약 이미지가 있다면 이미지 URL로도 사용
      timeAgo: json['created_at'] != null ? _timeAgo(json['created_at']) : '방금 전',
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => GroupComment.fromJson(e))
              .toList() ??
          [],
      isNotice: json['is_notice'] ?? false,
      isPrivate: false,
      videoUrl: null,
    );
  }

  static String _timeAgo(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      final difference = DateTime.now().difference(dateTime);
      if (difference.inDays > 0) return '${difference.inDays}일 전';
      if (difference.inHours > 0) return '${difference.inHours}시간 전';
      if (difference.inMinutes > 0) return '${difference.inMinutes}분 전';
      return '방금 전';
    } catch (e) {
      return dateTimeStr;
    }
  }
}

class GroupMember {
  final int userId;
  final String name;
  final String? profileImageUrl;
  bool isLeader;

  GroupMember({
    this.userId = 0,
    required this.name,
    this.profileImageUrl,
    this.isLeader = false,
  });
}

class Group {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int memberCount;

  // 🌟 여기서부터가 메인 화면이 애타게 찾고 있는 4가지 변수입니다!
  final bool isMember;
  final List<GroupMember> members;
  final List<GroupPost> posts;
  List<String> joinRequests;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.memberCount,
    this.isMember = true,
    required this.members,
    this.posts = const [],
    this.joinRequests = const [],
  });

  // 방장 확인용 헬퍼 함수
  bool checkIsLeader(String currentUserName) {
    return members.any((member) => member.name == currentUserName && member.isLeader);
  }
  // 💡 서버에서 온 데이터를 플러터 Object로 변환해주는 함수
  factory Group.fromJson(Map<String, dynamic> json) {
    List<GroupMember> parsedMembers = [];
    if (json['members'] != null) {
      parsedMembers = (json['members'] as List).map((m) => GroupMember(
        userId: m['user_id'] ?? 0,
        name: m['nickname'] ?? '알 수 없음',
        isLeader: m['is_leader'] == true,
      )).toList();
    } else {
      parsedMembers = [
        GroupMember(
          userId: 0,
          name: json['is_leader'] == true ? '연승혁' : '일반회원', // 방장 여부 매칭
          isLeader: json['is_leader'] ?? false,
        )
      ];
    }

    return Group(
      // 서버에서 id를 숫자로 주므로 .toString()으로 안전하게 문자열 변환
      id: json['id']?.toString() ?? '', 
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? 'https://via.placeholder.com/300',
      memberCount: json['member_count'] ?? 1,
      
      // 아래 데이터들은 서버 응답에 없을 때를 대비해 기본값(초기값) 채우기
      isMember: json['is_member'] ?? true,
      posts: const [],
      joinRequests: const [],
      
      members: parsedMembers,
    );
  }
}

// 알림(Notification) 전역 모델 및 리스트 (Group_Model.dart 맨 아래 추가)
// ------------------------------------------------------------------
class NotificationItem {
  final String title;
  final String content;
  final String timeAgo;
  bool isRead;

  NotificationItem({
    required this.title,
    required this.content,
    required this.timeAgo,
    this.isRead = false,
  });
}

// 앱 어디서든 접근 가능한 '전역 알림 리스트'
List<NotificationItem> globalNotifications = [];