import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; //토큰 추가 코드

class ApiService {
  // 웹(Chrome): localhost:8000
  // Android 에뮬레이터: 10.0.2.2:8000
  // 실기기 또는 iOS 시뮬레이터: 실제 서버 IP로 변경 필요
  static const String baseUrl = 'http://10.0.2.2:8080';
  static String? token;
  static String? currentUserId;
  static Future<void> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('access_token');
    currentUserId = prefs.getString('current_user_id');
  } // 토큰 추가 코드

  static Future<Map<String, String>> getHeaders() async {
    await loadSavedAuth(); // 토큰 꺼내오기 추가 코드
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── 로그인 ──────────────────────────────────────────────────────
  // 성공 시 null 반환, 실패 시 에러 메시지 반환
  static Future<String?> login(String userId, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'username=${Uri.encodeComponent(userId)}&password=${Uri.encodeComponent(password)}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['access_token'];

        // 1️⃣ 우선 토큰을 로컬에 저장 (이게 있어야 getMe()의 getHeaders()가 작동합니다)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token ?? '');

        // 🌟 2️⃣ [핵심 추가] 방금 찾으신 getMe() 함수를 호출하여 진짜 내 정보를 가져옵니다!
        final meData = await getMe();

        if (meData != null) {
          print("👤 [로그] getMe() 호출 성공! 회원 정보: $meData");

          // 백엔드 DB의 고유 고유번호(보통 'id')를 추출합니다.
          final backendId = meData['id'] ?? meData['internal_id'];

          if (backendId != null) {
            currentUserId = backendId.toString(); // ⭕ 숫자 고유번호(예: "6")가 정상 저장됨!
            print(
              "🎯 [성공] currentUserId가 숫자형 ID인 '$currentUserId'로 매pping 되었습니다.",
            );
          } else {
            print("⚠️ [경고] getMe() 응답에 'id' 키가 없습니다. 전체 데이터를 확인하세요.");
            currentUserId = userId; // 대체재로 기존 문자열 아이디 유지
          }
        } else {
          print("❌ [에러] 로그인 후 getMe()로 유저 정보를 가져오는데 실패했습니다.");
          currentUserId = userId;
        }

        // 3️⃣ 최종 매핑된 진짜 ID를 SharedPreferences에 저장
        await prefs.setString('current_user_id', currentUserId ?? '');

        return null;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['detail'] ?? '로그인 실패';
    } catch (e) {
      return '서버 연결 실패: $e';
    }
  }

  // ── 내 정보 조회 ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 회원가입 ─────────────────────────────────────────────────────
  static Future<String?> register({
    required String userId,
    required String password,
    required String nickname,
    required int age,
    String? gender,
    int healthCondition = 0,
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'password': password,
        'nickname': nickname,
        'age': age,
        'health_condition': healthCondition,
      };
      if (gender != null) body['gender'] = gender;

      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['detail'] ?? '회원가입 실패';
    } catch (e) {
      return '서버 연결 실패: $e';
    }
  }

  // ── 내 정보 수정 ─────────────────────────────────────────────────
  static Future<String?> updateMe({
    String? nickname,
    String? password,
    int? age,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nickname != null) body['nickname'] = nickname;
      if (password != null) body['password'] = password;
      if (age != null) body['age'] = age;

      final response = await http.patch(
        Uri.parse('$baseUrl/users/me'),
        headers: await getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['detail'] ?? '수정 실패';
    } catch (e) {
      return '서버 연결 실패: $e';
    }
  }

  // ── 게시글 목록 ──────────────────────────────────────────────────
  static Future<List<dynamic>?> getPosts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/posts/'));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 게시글 상세 ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getPostDetail(int postId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/posts/$postId'));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 게시글 작성 ──────────────────────────────────────────────────
  static Future<int?> createPost({
    required String title,
    required String content,
    bool isAnonymous = false,
    String? attachmentUrl,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'content': content,
        'is_anonymous': isAnonymous,
      };
      if (attachmentUrl != null) body['attachment_url'] = attachmentUrl;

      final response = await http.post(
        Uri.parse('$baseUrl/posts/'),
        headers: await getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['post_id'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 게시글 수정 ──────────────────────────────────────────────────
  static Future<bool> updatePost(
    int postId, {
    String? title,
    String? content,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (content != null) body['content'] = content;

      final response = await http.patch(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await getHeaders(),
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 게시글 삭제 ──────────────────────────────────────────────────
  static Future<bool> deletePost(int postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 게시글 좋아요 ────────────────────────────────────────────────
  static Future<int?> likePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['likes_count'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 게시글 좋아요 취소 ───────────────────────────────────────────
  static Future<int?> unlikePost(int postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['likes_count'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 댓글 작성 ────────────────────────────────────────────────────
  static Future<bool> createComment(
    int postId,
    String content, {
    bool isAnonymous = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: await getHeaders(),
        body: jsonEncode({'content': content, 'is_anonymous': isAnonymous}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // ── 댓글 수정 ────────────────────────────────────────────────────
  static Future<bool> updateComment(
    int postId,
    int commentId,
    String content,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
        headers: await getHeaders(),
        body: jsonEncode({'content': content}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 댓글 삭제 ────────────────────────────────────────────────────
  static Future<bool> deleteComment(int postId, int commentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 대댓글 작성 ──────────────────────────────────────────────────
  static Future<bool> createReply(
    int postId,
    int commentId,
    String content, {
    bool isAnonymous = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/replies'),
        headers: await getHeaders(),
        body: jsonEncode({'content': content, 'is_anonymous': isAnonymous}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // ── 대댓글 삭제 ──────────────────────────────────────────────────
  static Future<bool> deleteReply(
    int postId,
    int commentId,
    int replyId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '$baseUrl/posts/$postId/comments/$commentId/replies/$replyId',
        ),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 댓글/대댓글 좋아요 ───────────────────────────────────────────
  static Future<int?> likeComment(int postId, int commentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/like'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['likes_count'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 댓글/대댓글 좋아요 취소 ─────────────────────────────────────
  static Future<int?> unlikeComment(int postId, int commentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId/comments/$commentId/like'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['likes_count'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // 모임(Group) API
  // ══════════════════════════════════════════════════════════════

  // ── 전체 모임 목록 (검색 포함) ────────────────────────────────
  static Future<List<dynamic>?> getGroups({String query = ''}) async {
    try {
      final uri = query.trim().isEmpty
          ? Uri.parse('$baseUrl/groups/')
          : Uri.parse('$baseUrl/groups/?q=${Uri.encodeComponent(query)}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 내 모임 목록 ─────────────────────────────────────────────
  static Future<List<dynamic>?> getMyGroups() async {
    try {
      final headers = await getHeaders();
      print('1️⃣ [요청 헤더]: $headers'); // 토큰이 제대로 담겨서 가는지 확인

      final response = await http.get(
        Uri.parse('$baseUrl/groups/my'),
        headers: headers,
      );

      print('2️⃣ [응답 상태코드]: ${response.statusCode}'); // 200인지, 401인지 확인
      print(
        '3️⃣ [응답 데이터]: ${utf8.decode(response.bodyBytes)}',
      ); // 서버가 진짜로 뭘 주는지 확인

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      print('❌ [요청 에러]: $e');
      return null;
    }
  }
  /* static Future<List<dynamic>?> getMyGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/my'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }*/

  // ── 모임 상세 정보 ───────────────────────────────────────────
  static Future<Map<String, dynamic>?> getGroupDetail(int groupId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/groups/$groupId'));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 모임 생성 ────────────────────────────────────────────────
  static Future<int?> createGroup({
    required String name,
    required String description,
    String imageUrl = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/'),
        headers: await getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'image_url': imageUrl,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['group_id'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 가입 요청 ────────────────────────────────────────────────
  static Future<bool> requestJoinGroup(
    int groupId, {
    String message = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join'),
        headers: await getHeaders(),
        body: jsonEncode({'message': message}),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // ── 가입 요청 목록 (리더 전용) ───────────────────────────────
  static Future<List<dynamic>?> getJoinRequests(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/join-requests'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 가입 승인 ────────────────────────────────────────────────
  static Future<bool> approveJoinRequest(int groupId, int requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join-requests/$requestId/approve'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 가입 거절 ────────────────────────────────────────────────
  static Future<bool> rejectJoinRequest(int groupId, int requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join-requests/$requestId/reject'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 모임 탈퇴 ────────────────────────────────────────────────
  static Future<bool> leaveGroup(int groupId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/leave'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 모임 삭제 ────────────────────────────────────────────────
  static Future<bool> deleteGroup(int groupId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 멤버 강퇴 ────────────────────────────────────────────────
  static Future<bool> kickMember(int groupId, int targetUserId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/groups/$groupId/members/$targetUserId'),
        headers: await getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── 모임 게시글 목록 ─────────────────────────────────────────
  static Future<List<dynamic>?> getGroupPosts(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/posts'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 모임 게시글 작성 ─────────────────────────────────────────
  static Future<int?> createGroupPost(
    int groupId, {
    required String title,
    required String content,
    bool isAnonymous = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/posts'),
        headers: await getHeaders(),
        body: jsonEncode({
          'title': title,
          'content': content,
          'is_anonymous': isAnonymous,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body)['post_id'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── 채팅 쪽지 수신함 (폴링용) ─────────────────────────────────
  /// user_id 에게 온 메시지를 발신자별로 그룹화한 목록을 반환.
  /// 각 항목: { peer_id, peer_nickname, unread_count, last_message, last_message_at }
  static Future<List<Map<String, dynamic>>> getChatInbox(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/inbox/$userId'),
        headers: await getHeaders(),
      );
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getChatHistory(int userId, int peerId) async {
    try {
      // 이미 정의되어 있는 getHeaders()를 사용해 Authorization Bearer 토큰을 자동으로 주입합니다.
      final headers = await getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/chat/history/$userId/$peerId'),
        headers: headers, // ⭕ 공통 토큰 헤더 적용
      );

      if (response.statusCode == 200) {
        // 한글 깨짐 방지를 위해 인코딩 처리 후 JSON 파싱
        return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      } else {
        print("getChatHistory 서버 에러 코드: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("getChatHistory 네트워크 에러 발생: $e");
      return [];
    }
  }
}
