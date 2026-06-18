import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_history_item_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';

bool _looksLikeNestedTransferMapRow(Map<String, dynamic> json) {
  return json['product'] is Map ||
      json['seller_warehouse'] is Map ||
      json['buyer_warehouse'] is Map ||
      json['seller_store'] is Map ||
      json['buyer_store'] is Map ||
      json['seller_production_inventory'] is Map ||
      json['buyer_production_inventory'] is Map;
}

final buyerTransferMapProvider =
    FutureProvider.autoDispose<List<TransferMapItemModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      try {
        final response = await supabase.rpc('get_buyer_transfer_map_items');

        return (response as List<dynamic>)
            .map(
              (json) {
                final map = Map<String, dynamic>.from(json as Map);
                if (_looksLikeNestedTransferMapRow(map)) {
                  return TransferMapItemModel.fromJson(map);
                }
                return TransferMapItemModel.fromFlatJson(map);
              },
            )
            .toList();
      } on PostgrestException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('get_buyer_transfer_map_items') ||
            message.contains('does not exist') ||
            message.contains('not found')) {
          return const [];
        }
        rethrow;
      }
    });

final buyerTransferHistoryProvider =
    FutureProvider.autoDispose<List<TransferHistoryItemModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      try {
        final response = await supabase.rpc('get_buyer_transfer_history_items');

        return (response as List<dynamic>)
            .map(
              (json) => TransferHistoryItemModel.fromJson(
                Map<String, dynamic>.from(json as Map),
              ),
            )
            .toList();
      } on PostgrestException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('get_buyer_transfer_history_items') ||
            message.contains('does not exist') ||
            message.contains('not found')) {
          return const [];
        }
        rethrow;
      }
    });
