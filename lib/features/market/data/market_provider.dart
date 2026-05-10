import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_store_slot_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';

class MarketVehicleOptionsParams {
  final String? buyerWarehouseId;
  final String? buyerStoreSlotId;
  final String sellerSlotId;
  final int quantity;

  const MarketVehicleOptionsParams({
    this.buyerWarehouseId,
    this.buyerStoreSlotId,
    required this.sellerSlotId,
    required this.quantity,
  });

  bool get isStoreTarget => buyerStoreSlotId != null && buyerStoreSlotId!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is MarketVehicleOptionsParams &&
        other.buyerWarehouseId == buyerWarehouseId &&
        other.buyerStoreSlotId == buyerStoreSlotId &&
        other.sellerSlotId == sellerSlotId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(
        buyerWarehouseId,
        buyerStoreSlotId,
        sellerSlotId,
        quantity,
      );
}

final marketProductProvider =
    FutureProvider.family<ProductModel?, String>((ref, productId) async {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle();

      if (response == null) return null;
      return ProductModel.fromJson(response);
    });

final marketListingsProvider =
    FutureProvider.family<List<MarketListingModel>, String>((
      ref,
      productId,
    ) async {
      final supabase = Supabase.instance.client;

      final response = await supabase.rpc(
        'get_market_listings_for_product',
        params: {'p_product_id': productId},
      );

      return (response as List<dynamic>)
          .map(
            (json) =>
                MarketListingModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    });

final marketBuyerWarehouseProvider =
    FutureProvider.family<MarketBuyerWarehouseModel?, String>((
      ref,
      warehouseId,
    ) async {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('warehouses')
          .select(
            'id, name, city_id, is_active, city:cities(name, map_position_x, map_position_y), '
            'warehouse_type:warehouse_types(icon)',
          )
          .eq('id', warehouseId)
          .maybeSingle();

      if (response == null) return null;
      return MarketBuyerWarehouseModel.fromJson(response);
    });

final warehouseCapacityStatusProvider =
    FutureProvider.family<WarehouseCapacityStatusModel?, String>((
      ref,
      warehouseId,
    ) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'get_warehouse_capacity_status',
        params: {'p_warehouse_id': warehouseId},
      );

      if (response == null) return null;
      if (response is List && response.isEmpty) return null;

      final json = response is List ? response.first : response;
      return WarehouseCapacityStatusModel.fromJson(
        json as Map<String, dynamic>,
      );
    });

final marketBuyerStoreSlotProvider =
    FutureProvider.family<MarketBuyerStoreSlotModel?, String>((
      ref,
      storeSlotId,
    ) async {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('store_slots')
          .select(
            'id, store_id, product_id, quality_level, quantity, pending_quantity, capacity, '
            'store:stores(id, name, city_id, is_active, city:cities(id, name, map_position_x, map_position_y))',
          )
          .eq('id', storeSlotId)
          .maybeSingle();

      if (response == null) return null;
      return MarketBuyerStoreSlotModel.fromJson(response);
    });

final buyerActiveMarketTransfersProvider =
    FutureProvider.autoDispose<List<MarketTransferModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      final response = await supabase
          .from('logistics_transfers')
          .select(
            'id, product_id, quantity, status, started_at, finish_at, is_rental, total_price, rental_cost',
          )
          .eq('buyer_player_id', user.id)
          .eq('status', 'in_transit')
          .order('finish_at', ascending: true);

      return (response as List<dynamic>)
          .map(
            (json) => MarketTransferModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    });

final marketTransferVehicleOptionsProvider = FutureProvider.family<
  List<MarketTransferVehicleOptionModel>,
  MarketVehicleOptionsParams
>((ref, params) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc(
    params.isStoreTarget
        ? 'get_market_transfer_vehicle_options_for_store'
        : 'get_market_transfer_vehicle_options',
    params: params.isStoreTarget
        ? {
            'p_store_slot_id': params.buyerStoreSlotId,
            'p_seller_slot_id': params.sellerSlotId,
            'p_quantity': params.quantity,
          }
        : {
            'p_buyer_warehouse_id': params.buyerWarehouseId,
            'p_seller_slot_id': params.sellerSlotId,
            'p_quantity': params.quantity,
          },
  );

  return (response as List<dynamic>)
      .map(
        (json) => MarketTransferVehicleOptionModel.fromJson(
          json as Map<String, dynamic>,
        ),
      )
      .toList();
});

class MarketActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> startMarketTransfer({
    String? buyerWarehouseId,
    String? buyerStoreSlotId,
    required String sellerSlotId,
    required int quantity,
    String? vehicleId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        (buyerStoreSlotId != null && buyerStoreSlotId.isNotEmpty)
            ? 'start_market_to_store_transfer'
            : 'start_market_transfer',
        params: (buyerStoreSlotId != null && buyerStoreSlotId.isNotEmpty)
            ? {
                'p_store_slot_id': buyerStoreSlotId,
                'p_seller_slot_id': sellerSlotId,
                'p_quantity': quantity,
                'p_vehicle_id': vehicleId,
              }
            : {
                'p_buyer_warehouse_id': buyerWarehouseId,
                'p_seller_slot_id': sellerSlotId,
                'p_quantity': quantity,
                'p_vehicle_id': vehicleId,
              },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeMarketTransfer(
    String transferId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'complete_market_transfer',
        params: {'p_transfer_id': transferId},
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeDueMarketTransfers({
    String? buyerPlayerId,
    int limit = 100,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'complete_due_market_transfers',
        params: {
          'p_buyer_player_id': buyerPlayerId ?? user.id,
          'p_limit': limit,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final marketActionProvider = Provider((ref) => MarketActionNotifier());
