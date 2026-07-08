import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/market/models/product_price_history_model.dart';

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

final marketCityListingsProvider =
    FutureProvider.family<List<MarketListingModel>, String>((ref, cityId) async {
      final supabase = Supabase.instance.client;

      final response = await supabase.rpc(
        'get_market_listings_for_city',
        params: {'p_city_id': cityId},
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
class MarketActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TransferVehicleOptionsService _vehicleOptionsService =
      TransferVehicleOptionsService();

  Future<Map<String, dynamic>> startMultiMarketTransfer({
    required String buyerWarehouseId,
    required String sourceCityId,
    required List<Map<String, dynamic>> items,
    String? vehicleId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_multi_market_transfer',
        params: {
          'p_buyer_warehouse_id': buyerWarehouseId,
          'p_source_city_id': sourceCityId,
          'p_items': items,
          'p_vehicle_id': vehicleId,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>>
  getIntercityVehicleOptions({
    required String sourceCityId,
    required String targetCityId,
    required double totalVolume,
  }) async {
    final response = await _vehicleOptionsService.getRouteOptions(
      RouteTransferVehicleOptionsRequest(
        sourceCityId: sourceCityId,
        targetCityId: targetCityId,
        totalVolume: totalVolume,
      ),
    );

    return mapTransferVehicleOptions(
      rows: response,
      mapper: MarketTransferVehicleOptionModel.fromJson,
    );
  }
}

final marketActionProvider = Provider((ref) => MarketActionNotifier());

final playerMarketListingsProvider =
    FutureProvider.family<List<MarketListingModel>, String>((
      ref,
      playerId,
    ) async {
      final supabase = Supabase.instance.client;

      final response = await supabase.rpc(
        'get_market_listings_for_player',
        params: {'p_player_id': playerId},
      );

      return (response as List<dynamic>)
          .map(
            (json) =>
                MarketListingModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    });

final productPriceHistoryProvider =
    FutureProvider.family<ProductPriceHistoryModel?, String>((ref, productId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('product_price_history')
      .select()
      .eq('product_id', productId)
      .maybeSingle();

  if (response == null) return null;
  return ProductPriceHistoryModel.fromJson(response);
});
