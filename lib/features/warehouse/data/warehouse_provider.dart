import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';

final warehouseListProvider = FutureProvider<List<WarehouseModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return [];

  try {
    final response = await supabase.rpc('get_warehouse_list_page_data');
    final data = response['warehouses'] as List<dynamic>? ?? const [];
    return data
        .map((json) => WarehouseModel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  } catch (e) {
    throw Exception('Depo listesi alinamadi: $e');
  }
});

final warehouseDetailProvider =
    FutureProvider.family<WarehouseModel, String>((ref, warehouseId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) throw Exception('Oturum acilmamis.');

      final response = await supabase.rpc(
        'get_player_warehouse_detail',
        params: {'p_warehouse_id': warehouseId},
      );

      if (response == null) {
        throw Exception('Depo bulunamadi.');
      }

      return WarehouseModel.fromJson(response as Map<String, dynamic>);
    });

final warehouseTypeDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, typeId) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'get_warehouse_type_detail',
        params: {'p_type_id': typeId},
      );
      return Map<String, dynamic>.from(response as Map);
    });

final allProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_all_products_catalog');
  return (response as List).map((json) => ProductModel.fromJson(json)).toList();
});

final warehouseTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase.rpc('get_warehouse_types_catalog');
});

class WarehouseActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TransferVehicleOptionsService _vehicleOptionsService =
      TransferVehicleOptionsService();

  Future<Map<String, dynamic>> addProductToWarehouse({
    required String warehouseId,
    required String productId,
    required int quantity,
    required int qualityLevel,
    required double cost,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'add_product_to_warehouse',
        params: {
          'p_player_id': user.id,
          'p_warehouse_id': warehouseId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
          'p_quantity': quantity,
          'p_cost': cost,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createWarehouse({
    required String cityId,
    required String typeId,
    required String name,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'start_building_construction',
        params: {
          'p_player_id': user.id,
          'p_city_id': cityId,
          'p_building_kind': 'warehouse',
          'p_type_id': typeId,
          'p_name': name,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishConstructionWithGold(
    String constructionId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'finish_construction_with_gold',
        params: {
          'p_player_id': user.id,
          'p_construction_id': constructionId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(String constructionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'complete_building_construction',
        params: {
          'p_player_id': user.id,
          'p_construction_id': constructionId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateWarehouseSlotPrice({
    required String warehouseSlotId,
    required double price,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    if (price <= 0) {
      return {'success': false, 'message': 'Satis fiyati 0 buyuk olmali.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_warehouse_slot_price',
        params: {
          'p_player_id': user.id,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_price': price,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setWarehouseSlotSaleStatus({
    required String warehouseSlotId,
    required bool isAvailableForSale,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'set_warehouse_slot_sale_status',
        params: {
          'p_player_id': user.id,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_is_available_for_sale': isAvailableForSale,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getPlayerActiveWarehousesBasic() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await _supabase.rpc('get_player_active_warehouses_basic');
    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>>
      getWarehouseToWarehouseVehicleOptions({
    required String warehouseSlotId,
    required String buyerWarehouseId,
    required int quantity,
  }) async {
    final response = await _vehicleOptionsService.getOptions(
      TransferVehicleOptionsRequest(
        sourceKind: 'warehouse_slot',
        sourceId: warehouseSlotId,
        targetKind: 'warehouse',
        targetId: buyerWarehouseId,
        quantity: quantity,
      ),
    );

    return mapTransferVehicleOptions(
      rows: response,
      mapper: MarketTransferVehicleOptionModel.fromJson,
    );
  }

  Future<Map<String, dynamic>> startWarehouseToWarehouseTransfer({
    required String warehouseSlotId,
    required String buyerWarehouseId,
    required int quantity,
    String? vehicleId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_warehouse_to_warehouse_transfer',
        params: {
          'p_warehouse_slot_id': warehouseSlotId,
          'p_buyer_warehouse_id': buyerWarehouseId,
          'p_quantity': quantity,
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteWarehouseSlot({
    required String warehouseSlotId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'delete_warehouse_slot',
        params: {
          'p_player_id': user.id,
          'p_warehouse_slot_id': warehouseSlotId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final warehouseActionProvider = Provider((ref) => WarehouseActionNotifier());
