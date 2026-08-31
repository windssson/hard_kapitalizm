import 'package:flutter/foundation.dart';
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

class BuyerTransferMapNotifier
    extends AsyncNotifier<List<TransferMapItemModel>> {
  @override
  Future<List<TransferMapItemModel>> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await supabase
          .rpc('get_buyer_transfer_map_items')
          .timeout(const Duration(seconds: 15));

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
      debugPrint('[TransferMap] PostgrestException: ${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('[TransferMap] Unexpected error: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void patchRemoveTransfer(String transferId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.where((item) => item.id != transferId).toList(),
    );
  }
}

final buyerTransferMapProvider =
    AsyncNotifierProvider<BuyerTransferMapNotifier, List<TransferMapItemModel>>(
  BuyerTransferMapNotifier.new,
);

class BuyerTransferHistoryNotifier
    extends AsyncNotifier<List<TransferHistoryItemModel>> {
  @override
  Future<List<TransferHistoryItemModel>> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await supabase
          .rpc('get_buyer_transfer_history_items')
          .timeout(const Duration(seconds: 15));

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
      debugPrint('[TransferHistory] PostgrestException: ${e.message}');
      rethrow;
    } catch (e, st) {
      debugPrint('[TransferHistory] Unexpected error: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final buyerTransferHistoryProvider = AsyncNotifierProvider<
    BuyerTransferHistoryNotifier, List<TransferHistoryItemModel>>(
  BuyerTransferHistoryNotifier.new,
);

final transferItemsProvider =
    FutureProvider.family.autoDispose<List<TransferItemDetail>, String>((
      ref,
      transferId,
    ) async {
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase.rpc(
          'get_logistics_transfer_items',
          params: {'p_transfer_id': transferId},
        ).timeout(const Duration(seconds: 10));

        final list = response as List<dynamic>;
        return list
            .map(
              (item) => TransferItemDetail.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      } catch (e, stack) {
        debugPrint('Error in transferItemsProvider for $transferId: $e\n$stack');
        rethrow;
      }
    });
