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

      final response = await supabase
          .from('logistics_transfers')
          .select(
            'id, quantity, status, is_rental, total_price, rental_cost, started_at, finish_at, completed_at, '
            'product:products(id, urun_adi, urun_iconu), '
            'seller_warehouse:warehouses!seller_warehouse_id(id, name, city:cities(id, name)), '
            'seller_store:stores!seller_store_id(id, name, city:cities(id, name)), '
            'buyer_warehouse:warehouses!buyer_warehouse_id(id, name, city:cities(id, name)), '
            'buyer_store:stores!buyer_store_id(id, name, city:cities(id, name))',
          )
          .eq('buyer_player_id', user.id)
          .neq('status', 'in_transit')
          .order('completed_at', ascending: false)
          .limit(50);

      return (response as List<dynamic>)
          .map(
            (json) => TransferHistoryItemModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    });
