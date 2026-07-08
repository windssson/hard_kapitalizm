import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';

class ChatService {
  static final _db = Supabase.instance.client;
  static const _table = 'chat_messages';
  static const _pageSize = 50;

  /// İlk yükleme: en yeni [_pageSize] mesajı getirir
  static Future<List<ChatMessage>> fetchLatest() async {
    final rows = await _db
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(_pageSize);
    return (rows as List).map((r) => ChatMessage.fromJson(r)).toList().reversed.toList();
  }

  /// Sayfalama: [before] tarihinden önceki [_pageSize] mesajı getirir
  static Future<List<ChatMessage>> fetchBefore(DateTime before) async {
    final rows = await _db
        .from(_table)
        .select()
        .lt('created_at', before.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(_pageSize);
    return (rows as List).map((r) => ChatMessage.fromJson(r)).toList().reversed.toList();
  }

  /// Mesaj gönder — player bilgileri server'dan alınır, client'tan gönderilmez
  static Future<void> sendMessage({
    required String playerId,
    required String playerName,
    required String avatarId,
    required int playerLevel,
    required String content,
  }) async {
    await _db.from(_table).insert({
      'player_id': playerId,
      'player_name': playerName,
      'avatar_id': avatarId,
      'player_level': playerLevel,
      'content': content.trim(),
    });
  }

  /// Yeni mesajlar için Realtime stream
  static RealtimeChannel subscribeToNewMessages({
    required void Function(ChatMessage msg) onInsert,
  }) {
    return _db
        .channel('global_chat')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _table,
          callback: (payload) {
            final msg = ChatMessage.fromJson(payload.newRecord);
            onInsert(msg);
          },
        )
        .subscribe();
  }
}
