
// 데이터
final Map<String, Map<String, dynamic>> initialChatData = {
  '모임장': {
    'lastMessage': '이번 주는 시청역 근처 카페입니다.',
    'lastTime': '오후 1:13',
    'unreadCount': 0,
    'messages': [
      {'text': '안녕하세요. 문의 있으시면 말씀해주세요!', 'isMe': false, 'time': '오후 1:10', 'isRead': true},
      {'text': '네! 이번 모임 장소가 어디인가요?', 'isMe': true, 'time': '오후 1:12', 'isRead': true},
      {'text': '이번 주는 시청역 근처 카페입니다.', 'isMe': false, 'time': '오후 1:13', 'isRead': true},
    ],
  },
  '김철수': {
    'lastMessage': '오늘 모임 오시나요?',
    'lastTime': '오후 2:12',
    'unreadCount': 1,
    'messages': [
      {'text': '안녕하세요!', 'isMe': false, 'time': '오후 2:10', 'isRead': true},
      {'text': '네 안녕하세요 :)', 'isMe': true, 'time': '오후 2:11', 'isRead': true},
      {'text': '오늘 모임 오시나요?', 'isMe': false, 'time': '오후 2:12', 'isRead': false},
    ],
  },
  '이영희': {
    'lastMessage': '사진 잘 봤어요 :)',
    'lastTime': '오후 3:08',
    'unreadCount': 1,
    'messages': [
      {'text': '안녕하세요~ 반가워요!', 'isMe': false, 'time': '오후 3:00', 'isRead': true},
      {'text': '사진 잘 봤어요 :)', 'isMe': false, 'time': '오후 3:08', 'isRead': false},
    ],
  },
  '박민수': {
    'lastMessage': '다음 일정 언제예요?',
    'lastTime': '오후 1:30',
    'unreadCount': 3,
    'messages': [
      {'text': '안녕하세요', 'isMe': false, 'time': '오후 1:20', 'isRead': false},
      {'text': '자료 공유 감사해요.', 'isMe': false, 'time': '오후 1:25', 'isRead': false},
      {'text': '다음 일정 언제예요?', 'isMe': false, 'time': '오후 1:30', 'isRead': false},
    ],
  },
  '연승혁': {
    'lastMessage': '넵 괜찮아요 조심해서 오세요',
    'lastTime': '오후 5:03',
    'unreadCount': 0,
    'messages': [
      {'text': '오늘 조금 늦을 것 같아요.', 'isMe': false, 'time': '오후 5:01', 'isRead': true},
      {'text': '넵 괜찮아요 조심해서 오세요', 'isMe': true, 'time': '오후 5:03', 'isRead': true},
    ],
  },
  '최수민': {
    'lastMessage': '아직이요! 정해지면 알려드릴게요',
    'lastTime': '오후 6:23',
    'unreadCount': 0,
    'messages': [
      {'text': '다음 모임 일정 정해졌나요?', 'isMe': false, 'time': '오후 6:20', 'isRead': true},
      {'text': '아직이요! 정해지면 알려드릴게요', 'isMe': true, 'time': '오후 6:23', 'isRead': true},
    ],
  },
};