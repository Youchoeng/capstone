// ─────────────────────────────────────────────────────────────
// 로컬 SQLite 기반 채팅 저장소 (단일 진실의 원천)
// ─────────────────────────────────────────────────────────────
//
// 서버에는 메시지를 저장하지 않으므로, 본 클라이언트가
// 모든 메시지의 영구 저장을 책임진다.
//
// 테이블 구성
//  · conversations : 1:1 대화방 (peer_id 기준 1개씩)
//  · messages      : 실제 메시지 한 줄 한 줄
//
// 상태(status) 값
//  · pending   : 송신 대기 (오프라인이거나 ack 미수신)
//  · sent      : 서버 수락 — 즉시 상대 전달은 안 됐음 (FCM 으로 위임)
//  · delivered : 상대 클라이언트가 WS 로 즉시 수신함
//  · received  : 내가 수신한 메시지
//  · read      : 상대가 읽었다는 신호를 받은 경우 (확장용)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class StoredMessage {
  final int? rowId;
  final String clientMsgId;
  final int groupId;
  final int peerId; // 대화 상대의 internal_id
  final int senderId; // 메시지 보낸 사람의 internal_id
  final String content;
  final DateTime sentAt; // UTC 기준
  final String status;
  final bool isMine;
  final String messageType;
  final String? mediaUrl;
  final bool isDeleted;

  StoredMessage({
    this.rowId,
    required this.clientMsgId,
    required this.groupId,
    required this.peerId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    required this.status,
    required this.isMine,
    this.messageType = 'text',
    this.mediaUrl,
    this.isDeleted = false,
  });

  Map<String, Object?> toMap() => {
    'client_msg_id': clientMsgId,
    'group_id': groupId,
    'peer_id': peerId,
    'sender_id': senderId,
    'content': content,
    'sent_at': sentAt.toUtc().toIso8601String(),
    'status': status,
    'is_mine': isMine ? 1 : 0,
    'message_type': messageType,
    'media_url': mediaUrl,
    'is_deleted': isDeleted ? 1 : 0,
  };

  static StoredMessage fromMap(Map<String, Object?> m) => StoredMessage(
    rowId: m['id'] as int?,
    clientMsgId: m['client_msg_id'] as String,
    groupId: m['group_id'] as int,
    peerId: m['peer_id'] as int,
    senderId: m['sender_id'] as int,
    content: m['content'] as String,
    sentAt: DateTime.parse(m['sent_at'] as String).toUtc(),
    status: m['status'] as String,
    isMine: (m['is_mine'] as int) == 1,
    messageType: (m['message_type'] as String?) ?? 'text',
    mediaUrl: m['media_url'] as String?,
    isDeleted: ((m['is_deleted'] as int?) ?? 0) == 1,
  );
}

class Conversation {
  final int groupId;
  final int peerId;
  final String peerNickname;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isExited;

  Conversation({
    required this.groupId,
    required this.peerId,
    required this.peerNickname,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.isExited = false,
  });
}

class LocalChatDb {
  LocalChatDb._();
  static final LocalChatDb instance = LocalChatDb._();

  Database? _db;
  final _messageStreamController = StreamController<StoredMessage>.broadcast();

  /// 새 메시지가 저장될 때마다 흘러나오는 스트림 (UI 가 구독해서 즉시 갱신)
  Stream<StoredMessage> get messageStream => _messageStreamController.stream;

  Future<Database> _open() async {
    if (_db != null) return _db!;

    // 웹: path_provider 불가 → 단순 이름만 지정 (IndexedDB에 저장됨)
    // 모바일: 기존 방식 유지
    final String path;
    if (kIsWeb) {
      path = 'chat.db';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = p.join(dir.path, 'chat.db');
    }

    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE conversations (
            group_id         INTEGER NOT NULL,
            peer_id          INTEGER NOT NULL,
            peer_nickname    TEXT NOT NULL,
            last_message     TEXT,
            last_message_at  TEXT,
            unread_count     INTEGER NOT NULL DEFAULT 0,
            is_exited        INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (group_id, peer_id)
          );
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            client_msg_id  TEXT NOT NULL UNIQUE,
            group_id       INTEGER NOT NULL,
            peer_id        INTEGER NOT NULL,
            sender_id      INTEGER NOT NULL,
            content        TEXT NOT NULL,
            sent_at        TEXT NOT NULL,
            status         TEXT NOT NULL,
            is_mine        INTEGER NOT NULL,
            message_type   TEXT NOT NULL DEFAULT 'text',
            media_url      TEXT,
            is_deleted     INTEGER NOT NULL DEFAULT 0
          );
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_group_peer_time ON messages(group_id, peer_id, sent_at);',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN message_type TEXT NOT NULL DEFAULT \'text\';',
          );
          await db.execute('ALTER TABLE messages ADD COLUMN media_url TEXT;');
          await db.execute(
            'ALTER TABLE messages ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE conversations ADD COLUMN is_exited INTEGER NOT NULL DEFAULT 0;',
          );
        }
        if (oldVersion < 4) {
          await db.execute('DROP TABLE IF EXISTS conversations;');
          await db.execute('''
            CREATE TABLE conversations (
              group_id         INTEGER NOT NULL,
              peer_id          INTEGER NOT NULL,
              peer_nickname    TEXT NOT NULL,
              last_message     TEXT,
              last_message_at  TEXT,
              unread_count     INTEGER NOT NULL DEFAULT 0,
              is_exited        INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (group_id, peer_id)
            );
          ''');
          await db.execute(
            'ALTER TABLE messages ADD COLUMN group_id INTEGER NOT NULL DEFAULT 0;',
          );
          await db.execute('DROP INDEX IF EXISTS idx_messages_peer_time;');
          await db.execute(
            'CREATE INDEX idx_messages_group_peer_time ON messages(group_id, peer_id, sent_at);',
          );
        }
      },
    );
    return _db!;
  }

  // ───────────── conversations ─────────────

  Future<void> upsertConversation({
    required int groupId,
    required int peerId,
    required String peerNickname,
    int isExited = 0,
  }) async {
    try {
      final db = await _open();

      // 기존 대화방이 있으면 닉네임만 갱신, 없으면 새로 생성
      final existing = await db.query(
        'conversations',
        where: 'group_id = ? AND peer_id = ?',
        whereArgs: [groupId, peerId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('conversations', {
          'group_id': groupId,
          'peer_id': peerId,
          'peer_nickname': peerNickname,
          'unread_count': 0,
          'is_exited': isExited,
        });
      } else {
        // 기존 방이 이미 존재할 때
        final Map<String, dynamic> updateData = {'is_exited': isExited};

        // 만약 닉네임이 비어있지 않다면 닉네임 변경사항도 같이 업데이트 맵에 추가합니다.
        if (peerNickname.isNotEmpty) {
          updateData['peer_nickname'] = peerNickname;
        }
        await db.update(
          'conversations',
          updateData,
          where: 'group_id = ? AND peer_id = ?',
          whereArgs: [groupId, peerId],
        );
      }
    } catch (e, st) {
      debugPrint('LocalChatDb upsertConversation error: $e\n$st');
    }
  }

  Future<List<Conversation>> listConversations() async {
    final db = await _open();
    final rows = await db.query(
      'conversations',
      where: 'is_exited = 0',
      orderBy: 'last_message_at DESC',
    );
    return rows
        .map(
          (m) => Conversation(
            groupId: m['group_id'] as int,
            peerId: m['peer_id'] as int,
            peerNickname: m['peer_nickname'] as String,
            lastMessage: m['last_message'] as String?,
            lastMessageAt: (m['last_message_at'] as String?) == null
                ? null
                : DateTime.parse(m['last_message_at'] as String).toUtc(),
            unreadCount: (m['unread_count'] as int?) ?? 0,
            isExited: ((m['is_exited'] as int?) ?? 0) == 1,
          ),
        )
        .toList();
  }

  Future<void> syncConversationsBatch(
    List<Map<String, dynamic>> conversations,
  ) async {
    if (conversations.isEmpty) return;
    try {
      final db = await _open();

      await db.transaction((txn) async {
        for (final conv in conversations) {
          await txn.insert('conversations', {
            'group_id': conv['group_id'],
            'peer_id': conv['peer_id'],
            'peer_nickname': conv['peer_nickname'] ?? '',
            'last_message': conv['last_message'],
            'last_message_at': conv['last_message_at'],
            'unread_count': conv['unread_count'] ?? 0,
            'is_exited': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
    } catch (e, st) {
      debugPrint('LocalChatDb syncConversationsBatch error: $e\n$st');
    }
  }

  Future<void> markRead(int groupId, int peerId) async {
    final db = await _open();
    await db.update(
      'conversations',
      {'unread_count': 0},
      where: 'group_id = ? AND peer_id = ?',
      whereArgs: [groupId, peerId],
    );
  }

  // ───────────── messages ─────────────

  /// 메시지 저장 (멱등).
  ///
  /// 같은 client_msg_id 가 WS 와 FCM 양쪽으로 두 번 들어와도:
  /// - 메시지 row 는 한 번만 들어가고 (이미 있으면 덮어쓰기)
  /// - 대화방 unread_count 는 "신규 수신" 일 때만 1 증가
  /// - last_message / last_message_at 도 신규일 때만 갱신
  ///
  /// 즉 두 번째 호출은 사실상 status 갱신용으로만 동작.
  Future<void> saveMessagesBatch(List<StoredMessage> messages) async {
    if (messages.isEmpty) return;
    try {
      final db = await _open();

      // 🛠️ 트랜잭션 블록 내에서 DML을 수행하여 디스크 동기화(fsync) 횟수를 1회로 최적화합니다.
      await db.transaction((txn) async {
        for (final msg in messages) {
          // 0) 이미 저장된 client_msg_id 검사
          final existingMsg = await txn.query(
            'messages',
            columns: ['id'],
            where: 'client_msg_id = ?',
            whereArgs: [msg.clientMsgId],
            limit: 1,
          );
          final isFreshInsert = existingMsg.isEmpty;

          // 1) 메시지 인서트 (트랜잭션용 txn 객체 사용 필수!)
          await txn.insert(
            'messages',
            msg.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // 2) 대화방 메타 갱신
          if (isFreshInsert) {
            final isUnreadIncrement = !msg.isMine && msg.status != 'read';

            final existing = await txn.query(
              'conversations',
              where: 'group_id = ? AND peer_id = ?',
              whereArgs: [msg.groupId, msg.peerId],
              limit: 1,
            );

            if (existing.isEmpty) {
              await txn.insert('conversations', {
                'group_id': msg.groupId,
                'peer_id': msg.peerId,
                'peer_nickname': '',
                'last_message': msg.content,
                'last_message_at': msg.sentAt.toUtc().toIso8601String(),
                'unread_count': isUnreadIncrement ? 1 : 0,
                'is_exited': 0,
              });
            } else {
              final currentUnread =
                  (existing.first['unread_count'] as int?) ?? 0;
              await txn.update(
                'conversations',
                {
                  'last_message': msg.content,
                  'last_message_at': msg.sentAt.toUtc().toIso8601String(),
                  'unread_count': isUnreadIncrement
                      ? currentUnread + 1
                      : currentUnread,
                  'is_exited': 0,
                },
                where: 'group_id = ? AND peer_id = ?',
                whereArgs: [msg.groupId, msg.peerId],
              );
            }
          }
        }
      });

      // 3) 트랜잭션이 완벽히 끝나 락이 풀린 직후에 스트림에 방출하여 UI를 리렌더링시킵니다.
      for (final msg in messages) {
        _messageStreamController.add(msg);
      }
    } catch (e, st) {
      debugPrint('LocalChatDb saveMessagesBatch error: $e\n$st');
    }
  }

  /// 1개 메시지 단독 저장용 (기존 코드 안전성 보강)
  Future<StoredMessage> saveMessage(StoredMessage msg) async {
    try {
      final db = await _open();
      final existingMsg = await db.query(
        'messages',
        columns: ['id'],
        where: 'client_msg_id = ?',
        whereArgs: [msg.clientMsgId],
        limit: 1,
      );
      final isFreshInsert = existingMsg.isEmpty;

      await db.insert(
        'messages',
        msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (isFreshInsert) {
        final isUnreadIncrement = !msg.isMine && msg.status != 'read';
        final existing = await db.query(
          'conversations',
          where: 'group_id = ? AND peer_id = ?',
          whereArgs: [msg.groupId, msg.peerId],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('conversations', {
            'group_id': msg.groupId,
            'peer_id': msg.peerId,
            'peer_nickname': '',
            'last_message': msg.content,
            'last_message_at': msg.sentAt.toUtc().toIso8601String(),
            'unread_count': isUnreadIncrement ? 1 : 0,
            'is_exited': 0,
          });
        } else {
          final currentUnread = (existing.first['unread_count'] as int?) ?? 0;
          await db.update(
            'conversations',
            {
              'last_message': msg.content,
              'last_message_at': msg.sentAt.toUtc().toIso8601String(),
              'unread_count': isUnreadIncrement
                  ? currentUnread + 1
                  : currentUnread,
              'is_exited': 0,
            },
            where: 'group_id = ? AND peer_id = ?',
            whereArgs: [msg.groupId, msg.peerId],
          );
        }
      }
    } catch (e, st) {
      debugPrint('LocalChatDb saveMessage error: $e\n$st');
    }

    _messageStreamController.add(msg);
    return msg;
  }

  Future<void> updateStatus(String clientMsgId, String status) async {
    try {
      final db = await _open();
      await db.update(
        'messages',
        {'status': status},
        where: 'client_msg_id = ?',
        whereArgs: [clientMsgId],
      );

      // 변경된 메시지를 다시 읽어서 스트림에 알림 → UI 가 상태 라벨을 즉시 갱신
      final rows = await db.query(
        'messages',
        where: 'client_msg_id = ?',
        whereArgs: [clientMsgId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        _messageStreamController.add(StoredMessage.fromMap(rows.first));
      }
    } catch (e, st) {
      debugPrint('LocalChatDb updateStatus error: $e\n$st');
    }
  }

  Future<void> updateMessageStatus(String clientMsgId, String status) async {
    return updateStatus(clientMsgId, status);
  }

  Future<void> markMyMessagesAsRead(int groupId, int peerId) async {
    try {
      final db = await _open();

      // 내가 보낸 메시지 중 해당 방의 메시지를 읽음 처리
      await db.update(
        'messages',
        {'status': 'read'},
        where: 'group_id = ? AND peer_id = ? AND is_mine = 1 AND status != ?',
        whereArgs: [groupId, peerId, 'read'],
      );

      // 스트림으로 방출하여 UI가 새로고침 되도록 유도
      final rows = await db.query(
        'messages',
        where: 'group_id = ? AND peer_id = ? AND is_mine = 1 AND status = ?',
        whereArgs: [groupId, peerId, 'read'],
      );

      for (final row in rows) {
        _messageStreamController.add(StoredMessage.fromMap(row));
      }
    } catch (e, st) {
      debugPrint('LocalChatDb markMyMessagesAsRead error: $e\n$st');
    }
  }

  Future<List<StoredMessage>> loadMessages(
    int groupId,
    int peerId, {
    int limit = 200,
  }) async {
    try {
      final db = await _open();
      final rows = await db.query(
        'messages',
        where: 'group_id = ? AND peer_id = ?',
        whereArgs: [groupId, peerId],
        orderBy: 'sent_at ASC',
        limit: limit,
      );
      return rows.map(StoredMessage.fromMap).toList();
    } catch (e, st) {
      debugPrint('LocalChatDb loadMessages error: $e\n$st');
      return [];
    }
  }

  /// 아직 서버에 전달 못한(=pending) 내 메시지들 (재전송용)
  Future<List<StoredMessage>> loadPendingOutbox() async {
    try {
      final db = await _open();
      final rows = await db.query(
        'messages',
        where: 'is_mine = 1 AND status = ?',
        whereArgs: ['pending'],
        orderBy: 'sent_at ASC',
      );
      return rows.map(StoredMessage.fromMap).toList();
    } catch (e, st) {
      debugPrint('LocalChatDb loadPendingOutbox error: $e\n$st');
      return [];
    }
  }

  Future<void> deleteMessage(String clientMsgId) async {
    try {
      final db = await _open();
      await db.delete(
        'messages',
        where: 'client_msg_id = ?',
        whereArgs: [clientMsgId],
      );
    } catch (e, st) {
      debugPrint('LocalChatDb deleteMessage error: $e\n$st');
    }
  }

  Future<void> markMessageAsDeleted(String clientMsgId) async {
    try {
      final db = await _open();

      final targetRows = await db.query(
        'messages',
        where: 'client_msg_id = ?',
        whereArgs: [clientMsgId],
        limit: 1,
      );
      if (targetRows.isEmpty) return;
      final targetMsg = StoredMessage.fromMap(targetRows.first);

      await db.update(
        'messages',
        {'is_deleted': 1},
        where: 'client_msg_id = ?',
        whereArgs: [clientMsgId],
      );

      final latestMsgRows = await db.query(
        'messages',
        where: 'group_id = ? AND peer_id = ?',
        orderBy: 'sent_at DESC',
        limit: 1,
      );

      if (latestMsgRows.isNotEmpty &&
          latestMsgRows.first['client_msg_id'] == clientMsgId) {
        await db.update(
          'conversations',
          {'last_message': '삭제된 메시지입니다.'},
          where: 'group_id = ? AND peer_id = ?',
          whereArgs: [targetMsg.groupId, targetMsg.peerId],
        );
      }

      final updatedRows = await db.query(
        'messages',
        where: 'client_msg_id = ?',
        whereArgs: [clientMsgId],
        limit: 1,
      );
      if (updatedRows.isNotEmpty) {
        _messageStreamController.add(StoredMessage.fromMap(updatedRows.first));
      }
    } catch (e, st) {
      debugPrint('LocalChatDb markMessageAsDeleted error: $e\n$st');
    }
  }

  Future<void> exitConversation(int groupId, int peerId) async {
    try {
      final db = await _open();
      await db.update(
        'conversations',
        {
          'is_exited': 1, // 나감 처리
          'unread_count': 0, // 안읽은 메시지수 초기화
        },
        where: 'group_id = ? AND peer_id = ?',
        whereArgs: [groupId, peerId],
      );
    } catch (e, st) {
      debugPrint('LocalChatDb exitConversation error: $e\n$st');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
