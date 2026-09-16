import 'dart:io';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../Group_Model.dart'; // 모델 경로 확인
import 'common_widget.dart';

class GroupPostCard extends StatelessWidget {
  final GroupPost post;
  final String userName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  final bool isLeader;

  const GroupPostCard({
    super.key,
    required this.post,
    required this.userName,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,

    this.isLeader = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isMyPost = (post.author == userName); // 내가 쓴 글인가?
    bool canDelete = isMyPost || isLeader;     // 삭제 권한: 내 글이거나 OR 방장이거나!
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 헤더 (프로필, 이름, 시간, 더보기 메뉴)
              Row(
                children: [
                  buildProfileAvatar(name:post.author),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.author, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(post.timeAgo, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (post.isPrivate) const Icon(Icons.lock, size: 18, color: Colors.grey),

                  // 🌟 수정/삭제 메뉴 (권한에 따라 다르게 표시!)
                  if (canDelete) // '내 글'이거나 '방장'이면 일단 점 3개 메뉴를 띄웁니다.
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      // <PopupMenuEntry<String>> 을 명시해줘야 if문을 리스트 안에 쓸 수 있습니다.
                      itemBuilder: (context) => <PopupMenuEntry<String>>[

                        // 1. 수정 버튼: 진짜 '내 글'일 때만 메뉴에 쏙 들어감!
                        if (isMyPost)
                          const PopupMenuItem(value: 'edit', child: Text('수정')),

                        // 2. 삭제 버튼: 위에서 canDelete를 통과했으니 무조건 띄워줌!
                        const PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (post.title.isNotEmpty) ...[
                Text(post.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],

              // 2. 본문 텍스트
              _buildPostText(post.content),
              const SizedBox(height: 12),

              // 3. 이미지 (있을 경우)
              if (post.imageUrl != null) _buildPostImage(post.imageUrl!),

              // 4. 하단 아이콘 (좋아요, 댓글)
              Row(
                children: [
                  Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.red, size: 20),
                  const SizedBox(width: 4),
                  Text('${post.likeCount}', style: const TextStyle(color: Colors.red, fontSize: 16)),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  Text('${post.comments.length}', style: const TextStyle(color: Colors.green, fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 내부 보조 위젯들 (함께 이동)


  // 2. 게시글 텍스트 (태그 처리)
  Widget _buildPostText(String content) {
    final List<TextSpan> spans = [];
    for (final word in content.split(' ')) {
      final isTag = word.startsWith('@');
      spans.add(TextSpan(
        text: '$word ',
        style: TextStyle(
          color: isTag ? Colors.blue : Colors.black,
          fontWeight: isTag ? FontWeight.bold : FontWeight.normal,
          fontSize: 18,
          height: 1.4,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  // 3. 게시글 이미지 (파일/네트워크 구분)
  Widget _buildPostImage(String path) {
    // 상대 경로인 경우 절대 URL로 변환 시도
    final resolvedUrl = ApiService.getImageUrl(path);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: resolvedUrl != null
          ? Image.network(
              resolvedUrl,
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 150,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image),
              ),
            )
          : Image.file(
              File(path),
              width: double.infinity,
              height: 150,
              fit: BoxFit.cover,
      ),
    );
  }
} // 클래스 끝
