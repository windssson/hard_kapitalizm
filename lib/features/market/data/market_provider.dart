import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
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
      final response = await supabase.rpc(
        'get_market_product_detail',
        params: {'p_product_id': productId},
      );

      if (response == null) return null;
      return ProductModel.fromJson(response as Map<String, dynamic>);
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

final marketCityProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, cityId) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'get_city_map_detail',
        params: {'p_city_id': cityId},
      );

      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    });

final marketBuyerWarehouseProvider =
    FutureProvider.family<MarketBuyerWarehouseModel?, String>((
      ref,
      warehouseId,
    ) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'get_market_buyer_warehouse_detail',
        params: {'p_warehouse_id': warehouseId},
      );

      if (response == null) return null;
      return MarketBuyerWarehouseModel.fromJson(response as Map<String, dynamic>);
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
      final response = await supabase.rpc(
        'get_market_buyer_store_slot_detail',
        params: {'p_store_slot_id': storeSlotId},
      );

      if (response == null) return null;
      return MarketBuyerStoreSlotModel.fromJson(response as Map<String, dynamic>);
    });

final buyerActiveMarketTransfersProvider =
    FutureProvider.autoDispose<List<MarketTransferModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return const [];

      final response = await supabase.rpc('get_buyer_active_market_transfers');

      return (response as List<dynamic>)
          .map(
            (json) => MarketTransferModel.fromJson(
              json as Map<String, dynamic>,
            ),
          )
          .toList();
    });

final marketTransferVehicleOptionsProvider = FutureProvider.family<
  TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>,
  MarketVehicleOptionsParams
>((ref, params) async {
  final service = TransferVehicleOptionsService();
  final response = await service.getOptions(
    TransferVehicleOptionsRequest(
      sourceKind: 'market_slot',
      sourceId: params.sellerSlotId,
      targetKind: params.isStoreTarget ? 'store_slot' : 'warehouse',
      targetId: params.isStoreTarget
          ? params.buyerStoreSlotId!
          : params.buyerWarehouseId!,
      quantity: params.quantity,
    ),
  );

  return mapTransferVehicleOptions(
    rows: response,
    mapper: MarketTransferVehicleOptionModel.fromJson,
  );
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
