import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_history_item_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';

final buyerTransferMapProvider =
    FutureProvider.autoDispose<List<TransferMapItemModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      final response = await supabase.rpc('get_buyer_transfer_map_items');

      return (response as List<dynamic>)
          .map(
            (json) => TransferMapItemModel.fromFlatJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    });

final buyerTransferHistoryProvider =
    FutureProvider.autoDispose<List<TransferHistoryItemModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      final response = await supabase.rpc('get_buyer_transfer_history_items');

      return (response as List<dynamic>)
          .map(
            (json) => TransferHistoryItemModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    });
