import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Group_Model.dart';

//글쓰기 팝업창 코드
class GroupDialogs {
  // --- 1. 게시글 수정 다이얼로그 ---
  static void showEditPostDialog({
    required BuildContext context,
    required GroupPost post,
    required VoidCallback onUpdated,
  }) {
    final controller = TextEditingController(text: post.content);
    File? tempImage =
        post.imageUrl != null && !post.imageUrl!.startsWith('http')
        ? File(post.imageUrl!)
        : null;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit',
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildFullScreenLayout(
              context: context,
              title: '게시글 수정',
              contentController: controller,
              selectedImage: tempImage,
              // 수정할 때는 공지사항 체크박스 굳이 안 띄워도 되니 기본값 처리
              isLeader: false,
              isNotice: post.isNotice,
              onNoticeChanged: (val) {},
              onImagePicked: (file) => setDialogState(() => tempImage = file),
              onImageRemoved: () => setDialogState(() {
                tempImage = null;
                post.imageUrl = null;
              }),
              onSubmitted: () {
                post.content = controller.text;
                if (tempImage != null) post.imageUrl = tempImage!.path;
                onUpdated();
                Navigator.pop(context);
              },
              submitLabel: '수정 완료',
            );
          },
        );
      },
    );
  }

  // --- 2. 새 글 쓰기 다이얼로그 ---
  static void showWritePostDialog({
    required BuildContext context,
    required String userName,
    required bool isLeader, // 🌟 [추가] 상세 화면에서 방장 완장을 받아옵니다!
    required Function(GroupPost newPost) onSubmitted,
  }) {
    final TextEditingController contentController = TextEditingController();
    File? selectedImage;
    bool isNotice = false; // 🌟 [추가] 공지사항 체크 여부 (기본은 false)

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Write',
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _buildFullScreenLayout(
              context: context,
              title: '새 글 쓰기',
              contentController: contentController,
              selectedImage: selectedImage,
              isLeader: isLeader, // 🌟 [추가] 레이아웃으로 완장 전달
              isNotice: isNotice, // 🌟 [추가] 현재 체크 상태 전달
              onNoticeChanged: (value) => setDialogState(
                () => isNotice = value ?? false,
              ), // 🌟 [추가] 체크박스 누르면 상태 업데이트!
              onImagePicked: (file) =>
                  setDialogState(() => selectedImage = file),
              onImageRemoved: () => setDialogState(() => selectedImage = null),
              onSubmitted: () {
                if (contentController.text.trim().isNotEmpty ||
                    selectedImage != null) {
                  onSubmitted(
                    GroupPost(
                      author: userName,
                      content: contentController.text.trim(),
                      timeAgo: '방금 전',
                      isPrivate: true,
                      imageUrl: selectedImage?.path,
                      isNotice: isNotice, // 🌟 [추가] 새 글 만들 때 공지사항 여부 쾅 찍어주기!
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              submitLabel: '등록',
            );
          },
        );
      },
    );
  }

  // --- 3. 공통 레이아웃 헬퍼 ---
  static Widget _buildFullScreenLayout({
    required BuildContext context,
    required String title,
    required TextEditingController contentController,
    required File? selectedImage,
    required bool isLeader, // 🌟 [추가] 방장인지?
    required bool isNotice, // 🌟 [추가] 공지 체크됐는지?
    required Function(bool?) onNoticeChanged, // 🌟 [추가] 체크박스 동작 함수
    required Function(File) onImagePicked,
    required VoidCallback onImageRemoved,
    required VoidCallback onSubmitted,
    required String submitLabel,
  }) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: contentController,
                        maxLines: null,
                        minLines: 15,
                        decoration: const InputDecoration(
                          hintText: '내용을 입력하세요...',
                          border: InputBorder.none,
                        ),
                      ),
                      if (selectedImage != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                selectedImage,
                                width: double.infinity,
                                fit: BoxFit.fitWidth,
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: InkWell(
                                onTap: onImageRemoved,
                                child: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.green,
                        size: 30,
                      ),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final pickedFile = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (pickedFile != null) {
                          onImagePicked(File(pickedFile.path));
                        }
                      },
                    ),

                    // 🌟 [추가] 방장일 때만 카메라 버튼 옆에 체크박스 등장!
                    if (isLeader)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: isNotice,
                            onChanged: onNoticeChanged,
                            activeColor: Colors.green[800],
                          ),
                          const Text(
                            '공지로 등록',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                    const Spacer(),
                    ElevatedButton(
                      onPressed: onSubmitted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        submitLabel,
                        style: const TextStyle(color: Colors.white),
                      ),
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
}
