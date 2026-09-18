// 모임 내부 화면에서 글 직접 들어가기(수다 탭 댓글 기능, 좋아요 기능 등 차용)
import 'package:flutter/material.dart';
import 'Group_Model.dart';
import 'api_service.dart';

class GroupPostDetailScreen extends StatefulWidget {
  final GroupPost post;
  final String userName;
  final VoidCallback onUpdate;

  // 방장 권한이 있다면 남의 댓글도 삭제할 수 있게 처리하기 위한 변수 (선택적 사용)
  final bool isLeader;

  const GroupPostDetailScreen({
    super.key,
    required this.post,
    required this.userName,
    required this.onUpdate,
    this.isLeader = false,
  });

  @override
  State<GroupPostDetailScreen> createState() => _GroupPostDetailScreenState();
}

class _GroupPostDetailScreenState extends State<GroupPostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // 🌟 상태 관리: 현재 답글을 달고 있는 부모 댓글
  GroupComment? _replyTarget;

  // 🌟 상태 관리: 현재 수정 중인 댓글 또는 답글 객체
  dynamic _editTarget;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // @태그 파란색 강조 함수
  Widget _buildPostText(String content) {
    List<TextSpan> spans = [];
    content.split(' ').forEach((word) {
      if (word.startsWith('@')) {
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$word ',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              height: 1.5,
            ),
          ),
        );
      }
    });
    return RichText(text: TextSpan(children: spans));
  }

  // ------------------------------------------------------------------
  // 🌟 댓글/답글 삭제 확인 팝업
  // ------------------------------------------------------------------
  void _confirmDelete(VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 🌟 메뉴 버튼 (수정/삭제)
  // ------------------------------------------------------------------
  Widget _buildMoreMenu(dynamic item, VoidCallback onDelete) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
      onSelected: (value) {
        if (value == 'edit') {
          setState(() {
            _editTarget = item;
            _replyTarget = null;
            _commentController.text = item.content;
            _focusNode.requestFocus(); // 키보드 올리기
          });
        } else if (value == 'delete') {
          _confirmDelete(onDelete);
        } else if (value == 'report') {
          _showReportDialog(isPost: item is GroupPost, targetId: item.id);
        }
      },
      itemBuilder: (context) => [
        if (item.author == widget.userName)
          const PopupMenuItem(value: 'edit', child: Text('수정')),
        if (item.author == widget.userName)
          const PopupMenuItem(
            value: 'delete',
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        const PopupMenuItem(
          value: 'report',
          child: Text('신고하기', style: TextStyle(color: Colors.orange)),
        ),
      ],
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
                            widget.post.id,
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

  // ------------------------------------------------------------------
  // 🌟 단일 대댓글(답글) UI
  // ------------------------------------------------------------------
  Widget _buildReply(GroupComment parentComment, GroupReply reply) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 40.0,
        top: 8.0,
        bottom: 8.0,
        right: 16.0,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      color: Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      reply.author,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: reply.author == widget.userName
                            ? Colors.green
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      reply.timeAgo,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                _buildMoreMenu(reply, () {
                  setState(() {
                    parentComment.replies.remove(reply);
                  });
                  widget.onUpdate();
                }),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Text(reply.content, style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 🌟 단일 댓글 (부모) UI
  // ------------------------------------------------------------------
  Widget _buildComment(GroupComment comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: comment.author == widget.userName
                            ? Colors.green
                            : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment.author,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: comment.author == widget.userName
                              ? Colors.green
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment.timeAgo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  _buildMoreMenu(comment, () {
                    setState(() {
                      widget.post.comments.remove(comment);
                    });
                    widget.onUpdate();
                  }),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 28.0),
                child: Text(
                  comment.content,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),

              // 🌟 답글 달기 버튼
              Padding(
                padding: const EdgeInsets.only(left: 28.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _replyTarget = comment;
                      _editTarget = null;
                      _commentController.clear();
                      _focusNode.requestFocus(); // 키보드 띄우기
                    });
                  },
                  child: const Text(
                    '답글 달기',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 🌟 이 댓글에 달린 대댓글 리스트 렌더링
        if (comment.replies.isNotEmpty)
          ...comment.replies.map((reply) => _buildReply(comment, reply)),

        const Divider(),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 🌟 전송 버튼 로직 (작성/수정/답글 분기 처리)
  // ------------------------------------------------------------------
  void _handleSubmit() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (_editTarget != null) {
        // 1. 기존 글 수정 모드
        _editTarget.content = text;
        _editTarget = null;
      } else if (_replyTarget != null) {
        // 2. 대댓글 작성 모드
        _replyTarget!.replies.add(
          GroupReply(author: widget.userName, content: text),
        );
        _replyTarget = null;
      } else {
        // 3. 일반 새 댓글 작성 모드
        widget.post.comments.add(
          GroupComment(author: widget.userName, content: text),
        );
      }

      _commentController.clear();
      FocusScope.of(context).unfocus();
    });
    widget.onUpdate(); // 메인 화면(이전 화면)에도 갱신
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('게시글 보기'),
          backgroundColor: Colors.green[100],
          elevation: 0,
        ),

        // 🌟 하단 입력창 (수정/답글 상태에 따라 상단에 배너가 뜸)
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 답글이나 수정 모드일 때 안내 배너
                if (_replyTarget != null || _editTarget != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _editTarget != null
                              ? '댓글 수정 중...'
                              : '${_replyTarget!.author} 님에게 답글 작성 중',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _replyTarget = null;
                              _editTarget = null;
                              _commentController.clear();
                              FocusScope.of(context).unfocus();
                            });
                          },
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 실제 입력 필드
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: _replyTarget != null
                              ? '답글을 남겨보세요'
                              : '댓글을 남겨보세요',
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
                      icon: const Icon(
                        Icons.send,
                        color: Colors.green,
                        size: 28,
                      ),
                      onPressed: _handleSubmit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 🌟 게시글 본문 및 댓글 리스트
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 게시글 본문 영역
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post.author,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.post.timeAgo,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.post.title.isNotEmpty) ...[
                      Text(
                        widget.post.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 내용 & 태그
                    _buildPostText(widget.post.content),
                    const SizedBox(height: 20),

                    // 사진 원본 크기로 보여주기
                    if (widget.post.imageUrl != null &&
                        widget.post.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          ApiService.getImageUrl(widget.post.imageUrl) ??
                              widget.post.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),

                    const SizedBox(height: 20),
                    // 좋아요 버튼
                    OutlinedButton.icon(
                      onPressed: () async {
                        final previousLike = widget.post.isLiked;
                        setState(() {
                          widget.post.isLiked = !widget.post.isLiked;
                          widget.post.isLiked
                              ? widget.post.likeCount++
                              : widget.post.likeCount--;
                        });

                        final newCount = !previousLike
                            ? await ApiService.likePost(widget.post.id)
                            : await ApiService.unlikePost(widget.post.id);

                        if (newCount == null) {
                          if (context.mounted) {
                            setState(() {
                              widget.post.isLiked = previousLike;
                              widget.post.isLiked
                                  ? widget.post.likeCount++
                                  : widget.post.likeCount--;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('요청 실패')),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            setState(() => widget.post.likeCount = newCount);
                          }
                        }
                        widget.onUpdate();
                      },
                      icon: Icon(
                        widget.post.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
                      ),
                      label: Text(
                        '공감 ${widget.post.likeCount}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 8, color: Colors.grey[200]), // 구분선
              // 2. 댓글 헤더
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '댓글 ${widget.post.comments.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 3. 댓글 목록
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: widget.post.comments.length,
                itemBuilder: (context, index) {
                  return _buildComment(widget.post.comments[index]);
                },
              ),
              const SizedBox(height: 40), // 하단 여백
            ],
          ),
        ),
      ),
    );
  }
}
