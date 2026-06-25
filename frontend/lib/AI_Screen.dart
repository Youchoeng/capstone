import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart'; // 제미나이 AI 패키지 추가!
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 1. 대화 메시지 데이터 모델
class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

// 2. AI 화면 UI 및 로직
class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _wordsSpoken = "";

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "안녕하세요! 무엇이든 물어보세요. 마이크 버튼을 누르고 말씀하셔도 됩니다! 😊",
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _wordsSpoken = result.recognizedWords;
          _messageController.text = _wordsSpoken;
        });
      },
      localeId: 'ko_KR',
    );
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  // 스크롤 맨 아래로 내리는 함수
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 🌟 [핵심] 진짜 AI에게 질문을 보내고 답변을 받아오는 함수!
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 1. 내가 보낸 메시지 화면에 추가 & '생성 중' 표시
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _wordsSpoken = "";
      _messages.add(ChatMessage(text: "AI가 열심히 생각하는 중입니다...", isUser: false));
    });
    _scrollToBottom();

    try {
      // 2. 발급받은 API 키 입력 (🚨 깃허브 같은 곳에 올릴 땐 조심하세요!)
      final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception("API 키를 찾을 수 없습니다. .env 파일을 확인해주세요!");
      }

      // (실제로는 Provider나 DB에서 사용자가 가입한 모임 정보를 끌어옵니다.)
      String appData = """
      [현재 사용자 정보]
      - 이름: 연승혁
      - 가입된 모임: '주말 등산 동호회', '시니어 스마트폰 교실'
      - 가장 빠른 일정: 5월 10일 오전 9시 (주말 등산 동호회 - 도봉산 입구 집합)
      - 건강 상태: 고혈압 있음 (나트륨 주의)
      """;

      // 제미나이에게 부여할 '페르소나'와 '비밀 데이터'를 세팅합니다.
      final systemPrompt = Content.system("""
      당신은 이 시니어 건강 모임 앱의 아주 친절하고 똑똑한 AI 비서입니다.
      사용자가 앱 내의 일정이나 모임, 건강에 대해 물어보면 
      반드시 아래 [현재 사용자 정보]를 바탕으로 대답해 주세요.
      정보에 없는 내용은 부드럽게 모른다고 대답하세요.
      
      $appData
      """);

      //  3. 모델을 선언할 때 systemInstruction 이라는 옵션으로 몰래 주입합니다!
      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        systemInstruction: systemPrompt, //  귓속말 데이터 쏙 넣기!
      );

      // 4. 그리고 사용자의 질문 전송!
      final response = await model.generateContent([Content.text(text)]);

      // 5. 답변이 오면 '생성 중' 메시지를 지우고 진짜 답변 띄우기
      setState(() {
        _messages.removeLast(); // 마지막 메시지("생성 중...") 삭제
        _messages.add(ChatMessage(
            text: response.text ?? "답변을 생성하지 못했습니다.",
            isUser: false
        ));
      });
    } catch (e) {
      // 인터넷이 안 되거나 에러가 났을 때
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(text: "앗, AI 서버와 연결에 실패했어요. 다시 시도해주세요!\n에러: $e", isUser: false));
      });
    }

    _scrollToBottom();
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.smart_toy, color: Colors.blue[800]),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue[600] : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  color: message.isUser ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('AI 비서'),
          backgroundColor: Colors.blue[100],
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), offset: const Offset(0, -2), blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTapDown: (details) => _startListening(),
                    onTapUp: (details) => _stopListening(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.red : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.white : Colors.black87,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _isListening ? '듣고 있습니다...' : '무엇이든 물어보세요...',
                        hintStyle: TextStyle(color: _isListening ? Colors.red : Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: Colors.blue[600], shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}