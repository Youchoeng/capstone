import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final RegExp _passwordAllowedRegExp =
      RegExp(r'[A-Za-z0-9!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]');

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasSpecialChar =
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]').hasMatch(password);
    final isEnglishNumberAndSpecialOnly =
        RegExp(r'^[A-Za-z0-9!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]+$')
            .hasMatch(password);
    return hasMinLength && hasSpecialChar && isEnglishNumberAndSpecialOnly;
  }

  Future<void> _savePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    if (!_isValidPassword(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '비밀번호는 8자 이상, 특수문자 1개 이상 포함, 영어·숫자·특수문자만 사용할 수 있습니다.',
          ),
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await ApiService.updateMe(password: newPassword);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPasswordMatched =
        _confirmPasswordController.text.isEmpty ||
        _newPasswordController.text == _confirmPasswordController.text;

    final bool isPasswordValid =
        _newPasswordController.text.isEmpty ||
        _isValidPassword(_newPasswordController.text);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '비밀번호 변경',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.blue[100],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_passwordAllowedRegExp),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '새 비밀번호',
                border: const OutlineInputBorder(),
                helperText: _newPasswordController.text.isEmpty
                    ? '8자 이상, 특수문자 1개 이상, 영어·숫자·특수문자만 가능'
                    : isPasswordValid
                    ? '사용 가능한 비밀번호입니다.'
                    : '8자 이상, 특수문자 1개 이상, 영어·숫자·특수문자만 입력해주세요.',
                helperStyle: TextStyle(
                  color: _newPasswordController.text.isEmpty
                      ? Colors.grey
                      : isPasswordValid
                      ? Colors.green[800]
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_passwordAllowedRegExp),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '새 비밀번호 확인',
                border: const OutlineInputBorder(),
                helperText: _confirmPasswordController.text.isEmpty
                    ? '새 비밀번호를 한 번 더 입력해주세요.'
                    : isPasswordMatched
                    ? '비밀번호가 일치합니다.'
                    : '비밀번호가 일치하지 않습니다.',
                helperStyle: TextStyle(
                  color: _confirmPasswordController.text.isEmpty
                      ? Colors.grey
                      : isPasswordMatched
                      ? Colors.green[800]
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(
                      () =>
                          _obscureConfirmPassword = !_obscureConfirmPassword,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 18,
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
