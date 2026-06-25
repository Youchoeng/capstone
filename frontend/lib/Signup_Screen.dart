import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  String _selectedGender = '선택안함';
  DateTime? _selectedDate;
  bool _isLoading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 아이디: 영어 + 숫자만 허용
  final RegExp _idAllowedRegExp = RegExp(r'[A-Za-z0-9]');

  // 비밀번호: 영어 + 숫자 + 특수문자 허용
  final RegExp _passwordAllowedRegExp = RegExp(
    r'[A-Za-z0-9!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]',
  );

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    _confirmPwController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  bool _isValidId(String id) {
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(id);
  }

  bool _isValidPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasSpecialChar = RegExp(
      r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]',
    ).hasMatch(password);
    final isEnglishNumberAndSpecialOnly = RegExp(
      r'^[A-Za-z0-9!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]+$',
    ).hasMatch(password);
    return hasMinLength && hasSpecialChar && isEnglishNumberAndSpecialOnly;
  }

  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  // 성별 문자열 → 백엔드 GenderType 매핑
  String? _mapGender(String gender) {
    if (gender == '남성') return 'male';
    if (gender == '여성') return 'female';
    return null; // '선택안함'
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1960, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.green[800]!),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitSignUp() async {
    final id = _idController.text.trim();
    final pw = _pwController.text;
    final confirmPw = _confirmPwController.text;
    final nickname = _nicknameController.text.trim();

    if (id.isEmpty || pw.isEmpty || confirmPw.isEmpty || nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')));
      return;
    }

    if (!_isValidId(id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아이디는 영어와 숫자만 사용할 수 있습니다.')));
      return;
    }

    if (!_isValidPassword(pw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호는 8자 이상, 특수문자 1개 이상 포함, 영어·숫자·특수문자만 사용할 수 있습니다.'),
        ),
      );
      return;
    }

    if (pw != confirmPw) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')));
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('생년월일을 선택해주세요.')));
      return;
    }

    final age = _calculateAge(_selectedDate!);
    if (age < 0 || age > 150) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 생년월일을 선택해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    final error = await ApiService.register(
      userId: id,
      password: pw,
      nickname: nickname,
      age: age,
      gender: _mapGender(_selectedGender),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIdValid =
        _idController.text.isEmpty || _isValidId(_idController.text.trim());

    final bool isPasswordMatched =
        _confirmPwController.text.isEmpty ||
        _pwController.text == _confirmPwController.text;

    final bool isPasswordValid =
        _pwController.text.isEmpty || _isValidPassword(_pwController.text);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '환영합니다!\n기본 정보를 입력해주세요.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // 1. 아이디
            TextField(
              controller: _idController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_idAllowedRegExp),
              ],
              decoration: InputDecoration(
                labelText: '아이디',
                border: const OutlineInputBorder(),
                helperText: _idController.text.isEmpty
                    ? '영어와 숫자만 입력 가능합니다.'
                    : isIdValid
                    ? '사용 가능한 형식입니다.'
                    : '아이디는 영어와 숫자만 사용할 수 있습니다.',
                helperStyle: TextStyle(
                  color: _idController.text.isEmpty
                      ? Colors.grey
                      : isIdValid
                      ? Colors.green[800]
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 2. 비밀번호
            TextField(
              controller: _pwController,
              obscureText: _obscurePassword,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_passwordAllowedRegExp),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '비밀번호',
                border: const OutlineInputBorder(),
                helperText: _pwController.text.isEmpty
                    ? '8자 이상, 특수문자 1개 이상, 영어·숫자·특수문자만 가능'
                    : isPasswordValid
                    ? '사용 가능한 비밀번호입니다.'
                    : '8자 이상, 특수문자 1개 이상, 영어·숫자·특수문자만 입력해주세요.',
                helperStyle: TextStyle(
                  color: _pwController.text.isEmpty
                      ? Colors.grey
                      : isPasswordValid
                      ? Colors.green[800]
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. 비밀번호 확인
            TextField(
              controller: _confirmPwController,
              obscureText: _obscureConfirmPassword,
              inputFormatters: [
                FilteringTextInputFormatter.allow(_passwordAllowedRegExp),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                border: const OutlineInputBorder(),
                helperText: _confirmPwController.text.isEmpty
                    ? '비밀번호를 한 번 더 입력해주세요.'
                    : isPasswordMatched
                    ? '비밀번호가 일치합니다.'
                    : '비밀번호가 일치하지 않습니다.',
                helperStyle: TextStyle(
                  color: _confirmPwController.text.isEmpty
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
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. 닉네임
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 5. 성별 선택
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: '성별',
                border: OutlineInputBorder(),
              ),
              items: ['선택안함', '남성', '여성'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedGender = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 6. 생년월일 (나이 계산에 사용)
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '생년월일 *',
                  border: const OutlineInputBorder(),
                  helperText: _selectedDate == null ? '생년월일을 선택해주세요.' : null,
                  helperStyle: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null
                          ? '날짜를 선택해주세요'
                          : '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일'
                                '  (만 ${_calculateAge(_selectedDate!)}세)',
                      style: TextStyle(
                        color: _selectedDate == null
                            ? Colors.grey[600]
                            : Colors.black,
                      ),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 가입 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _submitSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      '가입하기',
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
