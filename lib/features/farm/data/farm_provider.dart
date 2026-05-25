import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_list_item_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';

final farmListProvider =
    FutureProvider.autoDispose<List<FarmListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  final response = await supabase.rpc('get_farm_list_items');
  final rows = response as List<dynamic>;

  return rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    return FarmListItemModel(
      farm: FarmModel.fromJson(
        Map<String, dynamic>.from(map['farm'] as Map),
      ),
      cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
      farmTypeName: (map['farm_type_name'] ?? 'Bilinmeyen Tarla').toString(),
      farmTypeIcon: (map['farm_type_icon'] ?? 'farm.webp').toString(),
      outputStockQuantity:
          (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
      slots: (map['slots'] as List<dynamic>? ?? const [])
          .map(
            (slot) => FarmSlotPreviewModel.fromJson(
              Map<String, dynamic>.from(slot as Map),
            ),
          )
          .toList(),
    );
  }).toList();
});

final farmTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase.rpc('get_farm_types_catalog');
});

final farmConstructionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      final response = await supabase.rpc(
        'get_player_building_constructions',
        params: {
          'p_building_kind': 'farm',
          'p_status': 'in_progress',
        },
      );

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;
      return rows.first as Map<String, dynamic>;
    });

final farmDetailProvider = FutureProvider.family<FarmDetailModel, String>((
  ref,
  farmId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  final response = await supabase.rpc(
    'get_farm_detail',
    params: {
      'p_player_id': user.id,
      'p_farm_id': farmId,
    },
  );

  final responseMap = Map<String, dynamic>.from(response as Map);
  if (responseMap['success'] != true) {
    throw Exception(
      responseMap['message'] ?? 'Tarla detaylari alinirken hata olustu.',
    );
  }

  final farmPayload = Map<String, dynamic>.from(
    responseMap['farm'] as Map,
  );
  final farm = FarmModel.fromJson(
    Map<String, dynamic>.from(farmPayload['farm'] as Map),
  );
  final farmType = FarmTypeDetailModel.fromJson(
    Map<String, dynamic>.from(farmPayload['farm_type'] as Map),
  );
  final slotRows = (farmPayload['slots'] as List<dynamic>? ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final inventoryRows =
      (farmPayload['inventories'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  return FarmDetailModel(
    farm: farm,
    farmType: farmType,
    cityName: (farmPayload['city_name'] ?? 'Bilinmeyen Sehir').toString(),
    slots: slotRows.map(FarmProductionSlotModel.fromJson).toList(),
    inventories: inventoryRows
        .map(FarmProductionInventoryModel.fromJson)
        .toList(),
  );
});

class FarmActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  Future<Map<String, dynamic>> createFarm({
    required String cityId,
    required String typeId,
    required String name,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_building_construction',
        params: {
          'p_player_id': user.id,
          'p_city_id': cityId,
          'p_building_kind': 'farm',
          'p_type_id': typeId,
          'p_name': name,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(
    String constructionId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

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

  Future<Map<String, dynamic>> finishConstructionWithGold(
    String constructionId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

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

  Future<Map<String, dynamic>> addProductionSlot(String farmId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'add_production_slot',
        params: {
          'p_player_id': user.id,
          'p_owner_kind': 'farm',
          'p_owner_id': farmId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignProductionSlotProduct({
    required String slotId,
    required String productId,
    required int qualityLevel,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'assign_production_slot_product',
        params: {
          'p_player_id': user.id,
          'p_production_slot_id': slotId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changeProductionSlotProduct({
    required String slotId,
    required String productId,
    required int qualityLevel,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'change_production_slot_product',
        params: {
          'p_player_id': user.id,
          'p_production_slot_id': slotId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setProductionSlotActive({
    required String slotId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_production_slot_active',
        params: {
          'p_player_id': user.id,
          'p_production_slot_id': slotId,
          'p_is_active': isActive,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<SelectableProductionProductModel>> getSelectableProducts({
    required String ownerKind,
    required String typeId,
  }) {
    return fetchSelectableProductionProducts(
      supabase: _supabase,
      ownerKind: ownerKind,
      typeId: typeId,
    );
  }

  Future<List<Map<String, dynamic>>> getEligibleWarehouseSlotsForInventory({
    required FarmProductionInventoryModel inventory,
    required String cityId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum acilmamis.');

    final response = await _supabase.rpc(
      'get_player_active_warehouses_with_slots',
      params: {'p_city_id': cityId},
    );

    final eligible = <Map<String, dynamic>>[];

    for (final warehouse in response as List<dynamic>) {
      final warehouseMap = Map<String, dynamic>.from(warehouse as Map);
      final slots = ((warehouseMap['warehouse_slots'] as List<dynamic>?) ?? const [])
          .where((slot) {
            final map = Map<String, dynamic>.from(slot as Map);
            return map['product_id'] == inventory.productId &&
                (map['quality_level'] as num?)?.toInt() == inventory.qualityLevel &&
                ((map['quantity'] as num?)?.toInt() ?? 0) > 0;
          })
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();

      if (slots.isNotEmpty) {
        eligible.add({
          ...warehouseMap,
          'warehouse_slots': slots,
        });
      }
    }

    return eligible;
  }

  Future<List<Map<String, dynamic>>> getEligibleWarehouseSlotsForInventoryAllCities({
    required FarmProductionInventoryModel inventory,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum acilmamis.');

    final response = await _supabase.rpc(
      'get_player_active_warehouses_with_slots',
    );

    final eligible = <Map<String, dynamic>>[];

    for (final warehouse in response as List<dynamic>) {
      final warehouseMap = Map<String, dynamic>.from(warehouse as Map);
      final slots = ((warehouseMap['warehouse_slots'] as List<dynamic>?) ??
              const [])
          .where((slot) {
            final map = Map<String, dynamic>.from(slot as Map);
            return map['product_id'] == inventory.productId &&
                (map['quality_level'] as num?)?.toInt() ==
                    inventory.qualityLevel &&
                ((map['quantity'] as num?)?.toInt() ?? 0) > 0;
          })
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();

      if (slots.isNotEmpty) {
        eligible.add({
          ...warehouseMap,
          'warehouse_slots': slots,
        });
      }
    }

    return eligible;
  }

  Future<List<Map<String, dynamic>>> getPlayerWarehousesByCity(
    String cityId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum acilmamis.');

    final response = await _supabase.rpc(
      'get_player_active_warehouses_basic',
    );

    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((warehouse) => warehouse['city_id']?.toString() == cityId)
        .toList();
  }

  Future<Map<String, dynamic>> transferWarehouseToProductionInventory({
    required String warehouseSlotId,
    required String productionInventoryId,
    required int quantity,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'transfer_warehouse_slot_to_production_inventory',
        params: {
          'p_player_id': user.id,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_production_inventory_id': productionInventoryId,
          'p_quantity': quantity,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> transferProductionInventoryToWarehouse({
    required String productionInventoryId,
    required String warehouseId,
    required int quantity,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'transfer_production_inventory_to_warehouse',
        params: {
          'p_player_id': user.id,
          'p_production_inventory_id': productionInventoryId,
          'p_warehouse_id': warehouseId,
          'p_quantity': quantity,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<ProductionLogisticsWarehouseOption>>
  getWarehousesForProductionLogistics({
    required String productionCityId,
  }) {
    return _productionLogisticsService.getWarehouseOptions(
      productionCityId: productionCityId,
    );
  }

  Future<List<ProductionLogisticsVehicleOption>>
  getProductionInputTransferVehicleOptions({
    required String warehouseSlotId,
    required String productionInventoryId,
    required int quantity,
  }) {
    return _productionLogisticsService.getProductionInputTransferVehicleOptions(
      warehouseSlotId: warehouseSlotId,
      productionInventoryId: productionInventoryId,
      quantity: quantity,
    );
  }

  Future<List<ProductionLogisticsVehicleOption>>
  getProductionOutputTransferVehicleOptions({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
  }) {
    return _productionLogisticsService
        .getProductionOutputTransferVehicleOptions(
          productionInventoryId: productionInventoryId,
          buyerWarehouseId: buyerWarehouseId,
          quantity: quantity,
        );
  }

  Future<ProductionLogisticsStartResult> startWarehouseToProductionTransfer({
    required String warehouseSlotId,
    required String productionInventoryId,
    required int quantity,
    String? vehicleId,
  }) {
    return _productionLogisticsService.startWarehouseToProductionTransfer(
      warehouseSlotId: warehouseSlotId,
      productionInventoryId: productionInventoryId,
      quantity: quantity,
      vehicleId: vehicleId,
    );
  }

  Future<ProductionLogisticsStartResult> startProductionToWarehouseTransfer({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
    String? vehicleId,
  }) {
    return _productionLogisticsService.startProductionToWarehouseTransfer(
      productionInventoryId: productionInventoryId,
      buyerWarehouseId: buyerWarehouseId,
      quantity: quantity,
      vehicleId: vehicleId,
    );
  }
}

final farmActionProvider = Provider((ref) => FarmActionNotifier());
