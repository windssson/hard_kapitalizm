import 'package:flutter/foundation.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final _db = Supabase.instance.client;
  static const _table = 'chat_messages';
  static const _pageSize = 50;

  static Future<List<ChatMessage>> fetchLatest({
    String channel = 'global',
    int? cityId,
  }) async {
    var query = _db.from(_table).select().eq('channel', channel);
    if (channel == 'city' && cityId != null) {
      query = query.eq('city_id', cityId);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(_pageSize);

    return (rows as List)
        .map((r) => ChatMessage.fromJson(r))
        .toList()
        .reversed
        .toList();
  }

  static Future<List<ChatMessage>> fetchBefore(
    DateTime before, {
    String channel = 'global',
    int? cityId,
  }) async {
    var query = _db
        .from(_table)
        .select()
        .eq('channel', channel)
        .lt('created_at', before.toUtc().toIso8601String());

    if (channel == 'city' && cityId != null) {
      query = query.eq('city_id', cityId);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(_pageSize);

    return (rows as List)
        .map((r) => ChatMessage.fromJson(r))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> sendMessage({
    required String content,
    String channel = 'global',
    MarketListingModel? linkedListing,
    String? replyToMessageId,
  }) async {
    final params = {
      'p_content': content.trim(),
      'p_channel': channel,
      'p_linked_listing_slot_id': linkedListing?.slotId.isNotEmpty == true
          ? linkedListing!.slotId
          : null,
      'p_linked_product_id': linkedListing?.productId.isNotEmpty == true
          ? linkedListing!.productId
          : null,
      'p_linked_product_name': linkedListing?.productName,
      'p_linked_product_icon': linkedListing?.productIcon,
      'p_linked_product_quality_level': linkedListing?.qualityLevel,
      'p_linked_product_quantity': linkedListing?.quantity,
      'p_linked_product_price': linkedListing?.price,
      'p_reply_to_message_id': replyToMessageId,
    };

    debugPrint(
      '[CHAT][SEND] channel=$channel content="${content.trim()}" '
      'slot=${params['p_linked_listing_slot_id']} '
      'replyTo=$replyToMessageId',
    );

    try {
      final res = await _db.rpc('send_chat_message', params: params);
      if (res is Map && res['success'] == false) {
        throw Exception(res['message'] ?? 'Mesaj gönderilemedi.');
      }
      debugPrint('[CHAT][SEND] rpc send_chat_message success');
    } catch (e, st) {
      debugPrint('[CHAT][SEND][ERROR] type=${e.runtimeType} error=$e');
      debugPrint('[CHAT][SEND][STACK] $st');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> reportMessage({
    required String messageId,
    required String reason,
    String details = '',
  }) async {
    final response = await _db.rpc(
      'report_chat_message',
      params: {
        'p_message_id': messageId,
        'p_reason': reason,
        'p_details': details.trim(),
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  static Future<Map<String, dynamic>> sendDirectMessage({
    required String receiverId,
    required String content,
  }) async {
    final response = await _db.rpc(
      'send_direct_message',
      params: {
        'p_receiver_id': receiverId,
        'p_content': content.trim(),
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  static RealtimeChannel subscribeToNewMessages({
    required void Function(ChatMessage msg) onInsert,
  }) {
    return _db
        .channel('chat_messages_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _table,
          callback: (payload) {
            try {
              if (payload.newRecord.isNotEmpty) {
                final msg = ChatMessage.fromJson(payload.newRecord);
                onInsert(msg);
              }
            } catch (_) {}
          },
        )
        .subscribe();
  }
}
