import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_buyer_warehouse_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_listing_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';

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
