import 'package:flutter/foundation.dart';
import 'package:hard_kapitalizm/features/chat/models/chat_message.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final _db = Supabase.instance.client;
  static const _table = 'chat_messages';
  static const _pageSize = 50;

  static Future<List<ChatMessage>> fetchLatest() async {
    final rows = await _db
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(_pageSize);

    return (rows as List)
        .map((r) => ChatMessage.fromJson(r))
        .toList()
        .reversed
        .toList();
  }

  static Future<List<ChatMessage>> fetchBefore(DateTime before) async {
    final rows = await _db
        .from(_table)
        .select()
        .lt('created_at', before.toUtc().toIso8601String())
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
    MarketListingModel? linkedListing,
  }) async {
    final params = {
      'p_content': content.trim(),
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
    };

    debugPrint(
      '[CHAT][SEND] content="${content.trim()}" '
      'slot=${params['p_linked_listing_slot_id']} '
      'product=${params['p_linked_product_id']} '
      'qty=${params['p_linked_product_quantity']} '
      'price=${params['p_linked_product_price']}',
    );

    try {
      await _db.rpc('send_chat_message', params: params);
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
