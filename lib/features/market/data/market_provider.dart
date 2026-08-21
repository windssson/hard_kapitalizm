import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/market/models/product_price_history_model.dart';
import 'package:hard_kapitalizm/features/market/models/seller_market_sale_model.dart';

final marketProductProvider =
    FutureProvider.family<ProductModel?, String>((ref, productId) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'get_market_product_detail',
        params: {'p_product_id': productId},
      );

      if (response == null) return null;
      return ProductModel.fromJson(Map<String, dynamic>.from(response as Map));
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
                MarketListingModel.fromJson(Map<String, dynamic>.from(json as Map)),
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
                MarketListingModel.fromJson(Map<String, dynamic>.from(json as Map)),
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
      return MarketBuyerWarehouseModel.fromJson(Map<String, dynamic>.from(response as Map));
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
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final TransferVehicleOptionsService _vehicleOptionsService =
      TransferVehicleOptionsService();

  MarketActionNotifier(this._ref);

  Map<String, dynamic> _sync(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

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

      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(warehouseDetailProvider(buyerWarehouseId));
      return _sync(response);
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

final marketActionProvider = Provider((ref) => MarketActionNotifier(ref));

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
    FutureProvider.family<ProductPriceHistoryModel?, String>((
      ref,
      productId,
    ) async {
      final supabase = Supabase.instance.client;

      Map<String, dynamic>? normalize(dynamic response) {
        if (response == null) return null;
        if (response is Map<String, dynamic>) return response;
        if (response is Map) return Map<String, dynamic>.from(response);
        if (response is List && response.isNotEmpty) {
          final first = response.first;
          if (first is Map<String, dynamic>) return first;
          if (first is Map) return Map<String, dynamic>.from(first);
        }
        return null;
      }

      Future<Map<String, dynamic>?> fetchRpc() async {
        final response = await supabase
            .rpc(
              'get_product_price_history',
              params: {'p_product_id': productId},
            )
            .timeout(const Duration(seconds: 8));
        return normalize(response);
      }

      Future<Map<String, dynamic>?> fetchProductsFallback() async {
        final response = await supabase
            .from('products')
            .select(
              'id, updated_at, price_day_0, price_day_1, price_day_2, price_day_3, price_day_4, price_day_5, price_day_6',
            )
            .eq('id', productId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (response == null) return null;

        return {
          'product_id': response['id'],
          'updated_at': response['updated_at'],
          'price_day_0': response['price_day_0'],
          'price_day_1': response['price_day_1'],
          'price_day_2': response['price_day_2'],
          'price_day_3': response['price_day_3'],
          'price_day_4': response['price_day_4'],
          'price_day_5': response['price_day_5'],
          'price_day_6': response['price_day_6'],
        };
      }

      try {
        final rpcData = await fetchRpc();
        if (rpcData != null) {
          return ProductPriceHistoryModel.fromJson(rpcData);
        }
      } on TimeoutException {
        // Fall back to direct table query when the RPC stalls.
      } catch (_) {
        // Continue to fallback query below.
      }

      try {
        final fallbackData = await fetchProductsFallback();
        if (fallbackData != null) {
          return ProductPriceHistoryModel.fromJson(fallbackData);
        }
      } on TimeoutException {
        return null;
      } catch (_) {
        return null;
      }

      return null;
    });

final sellerMarketSalesHistoryProvider =
    FutureProvider.autoDispose<SellerMarketSalesHistoryResponse>((ref) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'get_seller_market_sales_history',
        params: {'p_limit': 50},
      );

      if (response == null) {
        return const SellerMarketSalesHistoryResponse(
          success: true,
          totalSalesCount: 0,
          totalSoldQuantity: 0,
          totalRevenue: 0.0,
          sales: [],
        );
      }

      return SellerMarketSalesHistoryResponse.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

