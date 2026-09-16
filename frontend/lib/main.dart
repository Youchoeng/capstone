import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'Home_Screen.dart';
import 'Suda_Screen.dart';
import 'Login_Screen.dart';
import 'Health_Screen.dart';
import 'Group_Main_Screen.dart';
import 'AI_Screen.dart';
import 'Home_Settings_Screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'Personal_Chat_Screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 웹 플랫폼일 때 SQLite → IndexedDB 기반 팩토리로 교체
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // .env 파일이 없어도 앱이 죽지 않게 방어
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('🚨 [경고] .env 파일이 없습니다! .env.sample 파일을 복사해서 .env를 만들어주세요!');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final data = initialMessage.data;
        if (data.containsKey('group_id') && data.containsKey('sender_id')) {
          final groupId = int.tryParse(data['group_id'].toString()) ?? 0;
          final peerId = int.tryParse(data['sender_id'].toString()) ?? 0;
          final userName = data['sender_nickname'] ?? '상대방';

          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => PersonalChatScreen(
                groupId: groupId,
                peerId: peerId,
                userName: userName,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 폰트 크기 설정을 실시간으로 반영
    return ValueListenableBuilder<double>(
      valueListenable: globalFontScale,
      builder: (context, scale, child) {
        return MaterialApp(
          title: '시니어 건강 모임 앱',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
          locale: const Locale('ko', 'KR'),
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: Colors.blue[600],
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.blue[100],
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
              titleTextStyle: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 앱 전체 텍스트 배율을 설정에서 변경한 값으로 적용
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
          navigatorKey: navigatorKey,
          home: const LoginScreen(),
        );
      },
    );
  }
}

// ------------------------------------------------------------------
// 2. 메인 네비게이션 화면 (하단 탭바 관리)
// ------------------------------------------------------------------
class MainNavigationScreen extends StatefulWidget {
  final String userName;
  const MainNavigationScreen({super.key, required this.userName});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(userName: widget.userName),
      const HealthScreen(),
      SudaScreen(userName: widget.userName),
      const GroupMainScreen(),
      const AIScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.blue[100],
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.black54,
        selectedFontSize: 16,
        unselectedFontSize: 16,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '건강'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '수다'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '모임'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }
}
