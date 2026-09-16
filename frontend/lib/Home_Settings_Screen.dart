import 'package:flutter/material.dart';
import 'Setting_Verify_Current_Password_Screen.dart';
import 'Setting_Change_Nickname_Screen.dart';
import 'Setting_Change_Password_Screen.dart';
import 'Login_Screen.dart';
import 'services/chat_runtime.dart';
import 'api_service.dart';

// 🌟 1. 앱 전체 폰트 크기를 들고 있는 '방송국' (전역 변수)
final ValueNotifier<double> globalFontScale = ValueNotifier<double>(1.0);

class HomeSettingsScreen extends StatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  State<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends State<HomeSettingsScreen> {
  bool _isNotificationOn = true;

  void _goToNicknameChange() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VerifyCurrentPasswordScreen(
          title: '현재 비밀번호 확인',
          nextScreen: ChangeNicknameScreen(),
        ),
      ),
    );
  }

  void _goToPasswordChange() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VerifyCurrentPasswordScreen(
          title: '현재 비밀번호 확인',
          nextScreen: ChangePasswordScreen(),
        ),
      ),
    );
  }

  String _fontSizeLabel() {
    // 이제 로컬 변수 대신 전역 변수의 값을 읽어옵니다.
    final scale = globalFontScale.value;
    if (scale <= 0.9) return '작게';
    if (scale <= 1.1) return '보통';
    if (scale <= 1.3) return '크게';
    return '아주 크게';
  }

  // ❌ 수동으로 폰트를 키우던 _scaled 함수는 완벽히 삭제했습니다! (MediaQuery가 다 알아서 해줍니다)

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 30, color: Colors.blue[700]),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildNotificationTile() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        secondary: Icon(
          Icons.notifications_none,
          size: 30,
          color: Colors.blue[700],
        ),
        title: const Text(
          '알림 설정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _isNotificationOn ? '알림이 켜져 있습니다.' : '알림이 꺼져 있습니다.',
          style: const TextStyle(fontSize: 14),
        ),
        value: _isNotificationOn,
        onChanged: (value) {
          setState(() {
            _isNotificationOn = value;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? '알림이 켜졌습니다.' : '알림이 꺼졌습니다.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        },
        activeThumbColor: Colors.green,
      ),
    );
  }

  Widget _buildFontSizeTile() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, size: 30, color: Colors.blue[700]),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '폰트 크기 조절',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Text(
                '현재 설정: ${_fontSizeLabel()}',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '가',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Expanded(
                  child: Slider(
                    value: globalFontScale.value, // 🌟 전역 변수 값 사용
                    min: 0.8,
                    max: 1.4,
                    divisions: 3,
                    label: _fontSizeLabel(),
                    onChanged: (value) {
                      setState(() {
                        // 🌟 전역 변수 값을 업데이트하면, main.dart가 이 신호를 듣고 앱 전체를 다시 그립니다!
                        globalFontScale.value = value;
                      });
                    },
                  ),
                ),
                Text(
                  '가',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 46),
              child: Text(
                '미리보기: 글자가 이렇게 보입니다.',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue[100],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNotificationTile(),
          _buildFontSizeTile(),
          _buildMenuTile(
            icon: Icons.person_outline,
            title: '닉네임 변경',
            subtitle: '현재 비밀번호 확인 후 변경',
            onTap: _goToNicknameChange,
          ),
          _buildMenuTile(
            icon: Icons.lock_outline,
            title: '비밀번호 변경',
            subtitle: '현재 비밀번호 확인 후 변경',
            onTap: _goToPasswordChange,
          ),

          // 로그아웃 메뉴
          Card(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            color: Colors.red[50],
            child: ListTile(
              leading: Icon(
                Icons.exit_to_app,
                size: 30,
                color: Colors.red[700],
              ),
              title: const Text(
                '로그아웃',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text('채팅 세션을 종료하고 로그인 화면으로 이동합니다.'),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () async {
                // 1. 전역 채팅 싱글톤의 모든 소켓 커넥션 및 런타임 메모리 즉시 파괴
                await ChatRuntime.instance.stop();

                // 2. ApiService에 등록된 로컬 SharedPreferences 저장소 비우기
                await ApiService.logout();

                if (!context.mounted) return;

                // 3. 로그인 화면으로 안전하게 튕겨내기
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false, // 기존 내비게이션 스택 전부 제거
                );
              },
            ),
          ),

          // 회원 탈퇴 메뉴
          Card(
            margin: const EdgeInsets.only(bottom: 24),
            color: Colors.red[100],
            child: ListTile(
              leading: Icon(
                Icons.delete_forever,
                size: 30,
                color: Colors.red[900],
              ),
              title: Text(
                '회원 탈퇴',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900],
                ),
              ),
              subtitle: const Text('모든 데이터가 영구적으로 삭제됩니다.'),
              trailing: Icon(Icons.chevron_right, color: Colors.red[900]),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      '정말 탈퇴하시겠습니까?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      '탈퇴 시 작성한 게시글, 쪽지 내역 및 건강 기록이 영구적으로 삭제되며 복구할 수 없습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final error = await ApiService.deleteAccount();
                          if (error == null) {
                            await ChatRuntime.instance.stop();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(error)));
                          }
                        },
                        child: const Text(
                          '탈퇴하기',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
