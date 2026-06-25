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
  final int peerId;          // 대화 상대의 internal_id
  final int senderId;        // 메시지 보낸 사람의 internal_id
  final String content;
  final DateTime sentAt;     // UTC 기준
  final String status;
  final bool isMine;

  StoredMessage({
    this.rowId,
    required this.clientMsgId,
    required this.peerId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    required this.status,
    required this.isMine,
  });

  Map<String, Object?> toMap() => {
        'client_msg_id': clientMsgId,
        'peer_id': peerId,
        'sender_id': senderId,
        'content': content,
        'sent_at': sentAt.toUtc().toIso8601String(),
        'status': status,
        'is_mine': isMine ? 1 : 0,
      };

  static StoredMessage fromMap(Map<String, Object?> m) => StoredMessage(
        rowId: m['id'] as int?,
        clientMsgId: m['client_msg_id'] as String,
        peerId: m['peer_id'] as int,
        senderId: m['sender_id'] as int,
        content: m['content'] as String,
        sentAt: DateTime.parse(m['sent_at'] as String).toUtc(),
        status: m['status'] as String,
        isMine: (m['is_mine'] as int) == 1,
      );
}

class Conversation {
  final int peerId;
  final String peerNickname;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  Conversation({
    required this.peerId,
    required this.peerNickname,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });
}

class LocalChatDb {
  LocalChatDb._();
  static final LocalChatDb instance = LocalChatDb._();

  Database? _db;
  final _messageStreamController =
      StreamController<StoredMessage>.broadcast();

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
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE conversations (
            peer_id          INTEGER PRIMARY KEY,
            peer_nickname    TEXT NOT NULL,
            last_message     TEXT,
            last_message_at  TEXT,
            unread_count     INTEGER NOT NULL DEFAULT 0
          );
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            client_msg_id  TEXT NOT NULL UNIQUE,
            peer_id        INTEGER NOT NULL,
            sender_id      INTEGER NOT NULL,
            content        TEXT NOT NULL,
            sent_at        TEXT NOT NULL,
            status         TEXT NOT NULL,
            is_mine        INTEGER NOT NULL
          );
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_peer_time ON messages(peer_id, sent_at);',
        );
      },
    );
    return _db!;
  }

  // ───────────── conversations ─────────────

  Future<void> upsertConversation({
    required int peerId,
    required String peerNickname,
  }) async {
    try {
      final db = await _open();

      // 기존 대화방이 있으면 닉네임만 갱신, 없으면 새로 생성
      final existing = await db.query(
        'conversations',
        where: 'peer_id = ?',
        whereArgs: [peerId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await db.insert('conversations', {
          'peer_id': peerId,
          'peer_nickname': peerNickname,
          'unread_count': 0,
        });
      } else if (peerNickname.isNotEmpty) {
        await db.update(
          'conversations',
          {'peer_nickname': peerNickname},
          where: 'peer_id = ?',
          whereArgs: [peerId],
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
      orderBy: 'last_message_at DESC',
    );
    return rows.map((m) => Conversation(
          peerId: m['peer_id'] as int,
          peerNickname: m['peer_nickname'] as String,
          lastMessage: m['last_message'] as String?,
          lastMessageAt: (m['last_message_at'] as String?) == null
              ? null
              : DateTime.parse(m['last_message_at'] as String).toUtc(),
          unreadCount: (m['unread_count'] as int?) ?? 0,
        )).toList();
  }

  Future<void> markRead(int peerId) async {
    final db = await _open();
    await db.update(
      'conversations',
      {'unread_count': 0},
      where: 'peer_id = ?',
      whereArgs: [peerId],
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
  Future<StoredMessage> saveMessage(StoredMessage msg) async {
    try {
      final db = await _open();

      // 0) 이미 같은 client_msg_id 가 저장돼 있는지 확인
      final existingMsg = await db.query(
        'messages',
        columns: ['id'],
        where: 'client_msg_id = ?',
        whereArgs: [msg.clientMsgId],
        limit: 1,
      );
      final isFreshInsert = existingMsg.isEmpty;

      // 1) 메시지 저장 (있으면 교체 — status 갱신 가능)
      await db.insert(
        'messages',
        msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2) 대화방 메타는 "신규 메시지" 일 때만 갱신
      if (isFreshInsert) {
        final isUnreadIncrement = !msg.isMine && msg.status != 'read';
        final existing = await db.query(
          'conversations',
          where: 'peer_id = ?',
          whereArgs: [msg.peerId],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('conversations', {
            'peer_id': msg.peerId,
            'peer_nickname': '',
            'last_message': msg.content,
            'last_message_at': msg.sentAt.toUtc().toIso8601String(),
            'unread_count': isUnreadIncrement ? 1 : 0,
          });
        } else {
          final currentUnread = (existing.first['unread_count'] as int?) ?? 0;
          await db.update(
            'conversations',
            {
              'last_message': msg.content,
              'last_message_at': msg.sentAt.toUtc().toIso8601String(),
              'unread_count':
                  isUnreadIncrement ? currentUnread + 1 : currentUnread,
            },
            where: 'peer_id = ?',
            whereArgs: [msg.peerId],
          );
        }
      }
    } catch (e, st) {
      debugPrint('LocalChatDb saveMessage error: $e\n$st');
    }

    // 항상 스트림에 흘려보냄 — UI 가 status 변경(예: pending→delivered)도 받아 재렌더링.
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

  Future<List<StoredMessage>> loadMessages(int peerId, {int limit = 200}) async {
    try {
      final db = await _open();
      final rows = await db.query(
        'messages',
        where: 'peer_id = ?',
        whereArgs: [peerId],
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

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
