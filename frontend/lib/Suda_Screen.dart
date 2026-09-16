import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

// ------------------------------------------------------------------
// 1. 데이터 모델 (백엔드 응답 형식에 맞게 수정)
// ------------------------------------------------------------------
class Comment {
  int id;
  String author;
  String content;
  List<Comment> replies;
  int likesCount;
  bool isLiked;

  Comment({
    this.id = 0,
    required this.author,
    required this.content,
    List<Comment>? replies,
    this.likesCount = 0,
    this.isLiked = false,
  }) : replies = replies ?? [];

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      author: json['author'] ?? '',
      content: json['content'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      replies:
          (json['replies'] as List<dynamic>?)
              ?.map((r) => Comment.fromJson(r))
              .toList() ??
          [],
    );
  }
}

class Post {
  int id;
  String title;
  String content;
  String author;
  int likesCount;
  bool isLiked;
  List<Comment> comments;
  String timeAgo;
  String? imageUrl;

  Post({
    this.id = 0,
    required this.title,
    this.content = '',
    required this.author,
    required this.likesCount,
    this.isLiked = false,
    List<Comment>? comments,
    required this.timeAgo,
    this.imageUrl,
  }) : comments = comments ?? [];

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      author: json['author'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((c) => Comment.fromJson(c))
              .toList() ??
          [],
      timeAgo: _formatTimeAgo(json['created_at']),
      imageUrl: json['attachment_url'],
    );
  }

  static String _formatTimeAgo(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      if (diff.inDays < 30) return '${diff.inDays}일 전';
      return '${dateTime.year}.${dateTime.month}.${dateTime.day}';
    } catch (_) {
      return '';
    }
  }
}

// ------------------------------------------------------------------
// 2. 수다방 메인 화면
// ------------------------------------------------------------------
class SudaScreen extends StatefulWidget {
  final String userName;

  const SudaScreen({super.key, required this.userName});

  @override
  State<SudaScreen> createState() => _SudaScreenState();
}

class _SudaScreenState extends State<SudaScreen> {
  List<Post> _allPosts = [];
  List<Post> _displayedPosts = [];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getPosts();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (data != null) {
        _allPosts = data.map((p) => Post.fromJson(p)).toList();
        _filterPosts(_searchController.text);
      }
    });
  }

  void _filterPosts(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _displayedPosts = _allPosts.reversed.toList().cast<Post>();
      } else {
        _displayedPosts = _allPosts
            .where((post) {
              return post.title.contains(query) || post.content.contains(query);
            })
            .toList()
            .reversed
            .toList()
            .cast<Post>();
      }
    });
  }

  void _showWriteDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController contentController = TextEditingController();
    bool isAnonymousPost = true;
    File? selectedImage;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('새 게시글 쓰기'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: isAnonymousPost,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              isAnonymousPost = value ?? true;
                            });
                          },
                        ),
                        const Text(
                          '익명',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(hintText: '제목을 입력하세요'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: const InputDecoration(hintText: '내용을 입력하세요'),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.image, color: Colors.blue),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (pickedFile != null) {
                            setDialogState(() {
                              selectedImage = File(pickedFile.path);
                            });
                          }
                        },
                      ),
                    ),
                    if (selectedImage != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              selectedImage!,
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedImage = null;
                                });
                              },
                              child: Container(
                                color: Colors.black54,
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (titleController.text.trim().isNotEmpty &&
                              contentController.text.trim().isNotEmpty) {
                            setDialogState(() {
                              isUploading = true;
                            });

                            String? uploadedUrl;
                            if (selectedImage != null) {
                              uploadedUrl = await ApiService.uploadPostImage(
                                selectedImage!,
                              );
                            }

                            final postId = await ApiService.createPost(
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                              isAnonymous: isAnonymousPost,
                              attachmentUrl: uploadedUrl,
                            );

                            setDialogState(() {
                              isUploading = false;
                            });

                            if (!context.mounted) return;
                            Navigator.pop(context);

                            if (postId != null) {
                              await _loadPosts();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('게시글 작성에 실패했습니다.'),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                  ),
                  child: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('등록', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard(Post post) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: post.id,
              userName: widget.userName,
              onUpdate: _loadPosts,
              onDelete: _loadPosts,
            ),
          ),
        );
        _loadPosts();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              post.content,
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  ApiService.getImageUrl(post.imageUrl) ?? post.imageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.author,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  post.isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                  color: Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likesCount}',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: Colors.blue,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.comments.length}',
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Text(
                  post.timeAgo,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            '자유 수다 + 정보 팁',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue[100],
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: _filterPosts,
                decoration: InputDecoration(
                  hintText: '게시글 검색',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(0),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      thickness: 15.0,
                      interactive: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _displayedPosts.length,
                        itemBuilder: (context, index) {
                          return _buildPostCard(_displayedPosts[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'suda_fab',
          onPressed: _showWriteDialog,
          backgroundColor: Colors.blue[600],
          icon: const Icon(Icons.edit, color: Colors.white),
          label: const Text(
            '글쓰기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// 3. 게시글 상세 화면
// ------------------------------------------------------------------
class PostDetailScreen extends StatefulWidget {
  final int postId;
  final String userName;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.userName,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _isLoading = true;
  bool _isAnonymous = true;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getPostDetail(widget.postId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (data != null) _post = Post.fromJson(data);
    });
  }

  bool _isMine(String author) {
    return author == ApiService.currentUserId;
  }

  // ---------------- 게시글 수정/삭제 ----------------
  void _showEditPostDialog() {
    if (_post == null) return;
    final titleController = TextEditingController(text: _post!.title);
    final contentController = TextEditingController(text: _post!.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '게시글 수정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '제목을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 6,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]),
            onPressed: () async {
              if (titleController.text.trim().isNotEmpty &&
                  contentController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                final ok = await ApiService.updatePost(
                  widget.postId,
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                );
                if (ok) {
                  await _loadDetail();
                  widget.onUpdate();
                }
              }
            },
            child: const Text(
              '저장',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeletePostDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '게시글 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '정말 이 게시글을 삭제하시겠습니까?\n삭제된 글은 복구할 수 없습니다.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ApiService.deletePost(widget.postId);
              if (ok && context.mounted) {
                widget.onDelete();
                Navigator.pop(context);
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 댓글 수정/삭제 ----------------
  void _showEditCommentDialog(Comment comment) {
    final editController = TextEditingController(text: comment.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '댓글 수정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: editController,
          maxLines: 4,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: '댓글 내용을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]),
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                final ok = await ApiService.updateComment(
                  widget.postId,
                  comment.id,
                  editController.text.trim(),
                );
                if (ok) await _loadDetail();
              }
            },
            child: const Text(
              '저장',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteCommentDialog(Comment comment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '댓글 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '정말 이 댓글을 삭제하시겠습니까?',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '취소',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ApiService.deleteComment(
                widget.postId,
                comment.id,
              );
              if (ok) await _loadDetail();
            },
            child: const Text(
              '삭제',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog({required bool isPost, required int targetId}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final reasons = ['스팸 및 홍보', '욕설 및 비하', '음란물 및 부적절한 콘텐츠', '도배', '기타'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '신고 사유 선택',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...reasons.map(
                (reason) => ListTile(
                  title: Text(reason),
                  onTap: () async {
                    Navigator.pop(context);
                    final errorMsg = isPost
                        ? await ApiService.reportPost(targetId, reason)
                        : await ApiService.reportComment(
                            widget.postId,
                            targetId,
                            reason,
                          );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMsg ?? '신고가 접수되었습니다.')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- 대댓글 작성/삭제 ----------------
  void _showReplyDialog(Comment parentComment) {
    final replyController = TextEditingController();
    bool isAnonymousReply = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('답글 작성'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: isAnonymousReply,
                        onChanged: (bool? value) {
                          setDialogState(() {
                            isAnonymousReply = value ?? true;
                          });
                        },
                      ),
                      const Text(
                        '익명',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: replyController,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: '답글을 입력하세요'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (replyController.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    final ok = await ApiService.createReply(
                      widget.postId,
                      parentComment.id,
                      replyController.text.trim(),
                      isAnonymous: isAnonymousReply,
                    );
                    if (ok) await _loadDetail();
                  }
                },
                child: const Text('등록'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteReplyDialog(Comment parentComment, Comment reply) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('답글 삭제'),
        content: const Text('정말 이 답글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final ok = await ApiService.deleteReply(
                widget.postId,
                parentComment.id,
                reply.id,
              );
              if (ok) await _loadDetail();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildReply(Comment parentComment, Comment reply) {
    final mine = _isMine(reply.author);
    return Padding(
      padding: const EdgeInsets.only(
        left: 52.0,
        right: 12.0,
        top: 6.0,
        bottom: 6.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Text(
              'ㄴ ',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reply.author,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: mine ? Colors.blue : Colors.black87,
                        ),
                      ),
                    ),
                    if (mine) ...[
                      _buildActionIcon(
                        icon: Icons.delete_outline,
                        onTap: () =>
                            _showDeleteReplyDialog(parentComment, reply),
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                    ],
                    _buildActionIcon(
                      icon: Icons.report_problem_outlined,
                      onTap: () =>
                          _showReportDialog(isPost: false, targetId: reply.id),
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.content,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    if (reply.isLiked) {
                      final newCount = await ApiService.unlikeComment(
                        widget.postId,
                        reply.id,
                      );
                      if (newCount != null && mounted) {
                        setState(() {
                          reply.isLiked = false;
                          reply.likesCount = newCount;
                        });
                      }
                    } else {
                      final newCount = await ApiService.likeComment(
                        widget.postId,
                        reply.id,
                      );
                      if (newCount != null && mounted) {
                        setState(() {
                          reply.isLiked = true;
                          reply.likesCount = newCount;
                        });
                      }
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reply.isLiked
                            ? Icons.thumb_up
                            : Icons.thumb_up_alt_outlined,
                        size: 15,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${reply.likesCount}',
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(Comment comment) {
    final mine = _isMine(comment.author);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(
              Icons.person,
              color: mine ? Colors.blue : Colors.grey,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    comment.author,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: mine ? Colors.blue : Colors.black87,
                    ),
                  ),
                ),
                if (mine) ...[
                  _buildActionIcon(
                    icon: Icons.edit_outlined,
                    onTap: () => _showEditCommentDialog(comment),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  _buildActionIcon(
                    icon: Icons.delete_outline,
                    onTap: () => _showDeleteCommentDialog(comment),
                    color: Colors.red,
                  ),
                  const SizedBox(width: 4),
                ],
                _buildActionIcon(
                  icon: Icons.report_problem_outlined,
                  onTap: () =>
                      _showReportDialog(isPost: false, targetId: comment.id),
                  color: Colors.orange,
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 18, color: Colors.black),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        if (comment.isLiked) {
                          final newCount = await ApiService.unlikeComment(
                            widget.postId,
                            comment.id,
                          );
                          if (newCount != null && mounted) {
                            setState(() {
                              comment.isLiked = false;
                              comment.likesCount = newCount;
                            });
                          }
                        } else {
                          final newCount = await ApiService.likeComment(
                            widget.postId,
                            comment.id,
                          );
                          if (newCount != null && mounted) {
                            setState(() {
                              comment.isLiked = true;
                              comment.likesCount = newCount;
                            });
                          }
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            comment.isLiked
                                ? Icons.thumb_up
                                : Icons.thumb_up_alt_outlined,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.likesCount}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => _showReplyDialog(comment),
                      child: const Text(
                        '답글',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...comment.replies.map((reply) => _buildReply(comment, reply)),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildPostSection() {
    final post = _post!;
    final mine = _isMine(post.author);
    return Container(
      padding: const EdgeInsets.all(20.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '작성자: ${post.author}  |  ${post.timeAgo}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (mine) ...[
                TextButton.icon(
                  onPressed: _showEditPostDialog,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('수정'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                TextButton.icon(
                  onPressed: _showDeletePostDialog,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('삭제'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
              TextButton.icon(
                onPressed: () =>
                    _showReportDialog(isPost: true, targetId: post.id),
                icon: const Icon(Icons.report_problem_outlined, size: 18),
                label: const Text('신고'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ],
          ),
          const Divider(height: 30, thickness: 1),
          Text(post.content, style: const TextStyle(fontSize: 18, height: 1.5)),
          const SizedBox(height: 16),

          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ApiService.getImageUrl(post.imageUrl) ?? post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: OutlinedButton.icon(
              onPressed: () async {
                if (post.isLiked) {
                  final newCount = await ApiService.unlikePost(post.id);
                  if (newCount != null && mounted) {
                    setState(() {
                      post.isLiked = false;
                      post.likesCount = newCount;
                    });
                    widget.onUpdate();
                  }
                } else {
                  final newCount = await ApiService.likePost(post.id);
                  if (newCount != null && mounted) {
                    setState(() {
                      post.isLiked = true;
                      post.likesCount = newCount;
                    });
                    widget.onUpdate();
                  }
                }
              },
              icon: Icon(
                post.isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                color: Colors.red,
              ),
              label: Text(
                '공감 ${post.likesCount}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('게시글 상세'),
          backgroundColor: Colors.blue[100],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _isAnonymous,
                      onChanged: (bool? value) {
                        setState(() => _isAnonymous = value ?? true);
                      },
                    ),
                    const Text(
                      '익명',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: '댓글을 남겨보세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue, size: 28),
                  onPressed: () async {
                    final text = _commentController.text.trim();
                    if (text.isNotEmpty) {
                      _commentController.clear();
                      FocusScope.of(context).unfocus();
                      final ok = await ApiService.createComment(
                        widget.postId,
                        text,
                        isAnonymous: _isAnonymous,
                      );
                      if (ok) await _loadDetail();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _post == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('게시글을 불러오지 못했습니다.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadDetail,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            : CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _buildPostSection()),
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        '댓글 ${_post!.comments.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final comment = _post!.comments[index];
                      return Container(
                        color: Colors.white,
                        child: _buildComment(comment),
                      );
                    }, childCount: _post!.comments.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }
}
