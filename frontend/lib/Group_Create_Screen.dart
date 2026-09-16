import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class GroupCreateScreen extends StatefulWidget {
  final String currentUser; // 모임을 만드는 사람 (자동으로 리더가 됨)

  const GroupCreateScreen({super.key, required this.currentUser});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _isSubmitting = false;

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    final groupDescription = _descriptionController.text.trim();

    if (groupName.isEmpty || groupDescription.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모임 이름과 소개글을 모두 입력해주세요!')));
      return;
    }

    if (groupName.length > 20) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모임 이름은 20자 이내로 입력해주세요!')));
      return;
    }

    if (groupDescription.length > 40) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모임 소개글은 40자 이내로 입력해주세요!')));
      return;
    }

    setState(() => _isSubmitting = true);

    // 백엔드 API로 모임 생성
    final groupId = await ApiService.createGroup(
      name: groupName,
      description: groupDescription,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (groupId != null) {
      Navigator.pop(context, {
        'id': groupId,
        'name': groupName,
        'description': groupDescription,
        'leader': widget.currentUser,
        'memberCount': 1,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 생성에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '새 모임 만들기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '어떤 모임을 만들어볼까요?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 1. 모임 이름 입력창
            const Text(
              '모임 이름 (20자 이내)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 20,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: '예) 주말 등산 동호회',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_nameController.text.length}/20',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 모임 소개글 입력창
            const Text(
              '모임 소개글 (40자 이내)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 40,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: '모임의 목적, 활동 내용, 환영하는 멤버 등\n자세한 소개를 적어주세요.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_descriptionController.text.length}/40',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 40),

            // 3. 만들기 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        '모임 만들기',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
