import 'package:flutter/material.dart';
import 'api_service.dart';

class VerifyCurrentPasswordScreen extends StatefulWidget {
  final String title;
  final Widget nextScreen;

  const VerifyCurrentPasswordScreen({
    super.key,
    required this.title,
    required this.nextScreen,
  });

  @override
  State<VerifyCurrentPasswordScreen> createState() =>
      _VerifyCurrentPasswordScreenState();
}

class _VerifyCurrentPasswordScreenState
    extends State<VerifyCurrentPasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    final currentPassword = _currentPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 비밀번호를 입력해주세요.')),
      );
      return;
    }

    final userId = ApiService.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보를 찾을 수 없습니다. 다시 로그인해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 현재 비밀번호 확인: 로그인 API 재호출
    final error = await ApiService.login(userId, currentPassword);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 비밀번호가 일치하지 않습니다.')),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.blue[100],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              '변경을 위해 현재 비밀번호를 입력해주세요.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrentPassword,
              decoration: InputDecoration(
                labelText: '현재 비밀번호',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrentPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
              ),
              onSubmitted: (_) => _verifyPassword(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
