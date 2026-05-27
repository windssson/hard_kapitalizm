import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_list_item_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';

final fieldListProvider =
    FutureProvider.autoDispose<List<FieldListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  final response = await supabase.rpc('get_field_list_items');
  final rows = response as List<dynamic>;

  return rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    return FieldListItemModel(
      field: FieldModel.fromJson(
        Map<String, dynamic>.from(map['field'] as Map),
      ),
      cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
      fieldTypeName:
          (map['field_type_name'] ?? 'Bilinmeyen Ciftlik').toString(),
      fieldTypeIcon: (map['field_type_icon'] ?? 'field.webp').toString(),
      outputStockQuantity:
          (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
      slots: (map['slots'] as List<dynamic>? ?? const [])
          .map(
            (slot) => FieldSlotPreviewModel.fromJson(
              Map<String, dynamic>.from(slot as Map),
            ),
          )
          .toList(),
    );
  }).toList();
});

final fieldTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase.rpc('get_field_types_catalog');
});

final fieldConstructionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      final response = await supabase.rpc(
        'get_player_building_constructions',
        params: {
          'p_building_kind': 'field',
          'p_status': 'in_progress',
        },
      );

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;
      return rows.first as Map<String, dynamic>;
    });

final fieldDetailProvider = FutureProvider.family<FieldDetailModel, String>((
  ref,
  fieldId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  final response = await supabase.rpc(
    'get_field_detail_data',
    params: {'p_field_id': fieldId},
  );

  final map = Map<String, dynamic>.from(response as Map);
  return FieldDetailModel(
    field: FieldModel.fromJson(
      Map<String, dynamic>.from(map['field'] as Map),
    ),
    fieldType: FieldTypeDetailModel.fromJson(
      Map<String, dynamic>.from(map['field_type'] as Map),
    ),
    cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
    slots: (map['slots'] as List<dynamic>? ?? const [])
        .map(
          (slot) => ProductionSlotModel.fromJson(
            Map<String, dynamic>.from(slot as Map),
          ),
        )
        .toList(),
    inventories: (map['inventories'] as List<dynamic>? ?? const [])
        .map(
          (inv) => ProductionInventoryModel.fromJson(
            Map<String, dynamic>.from(inv as Map),
          ),
        )
        .toList(),
  );
});

final activeFieldUpgradeProvider =
    FutureProvider.family<BuildingUpgradeModel?, String>((ref, fieldId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_upgrade',
        params: {
          'p_building_kind': 'field',
          'p_entity_id': fieldId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingUpgradeModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

final activeFieldBoostProvider =
    FutureProvider.family<BuildingBoostModel?, String>((ref, fieldId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_boost',
        params: {
          'p_building_kind': 'field',
          'p_entity_id': fieldId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingBoostModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

class FieldActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  Future<Map<String, dynamic>> createField({
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
          'p_building_kind': 'field',
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

  Future<Map<String, dynamic>> startFieldUpgrade(String fieldId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_building_upgrade',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'field',
          'p_entity_id': fieldId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeDueBuildingUpgrades() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'complete_due_building_upgrades',
        params: {
          'p_limit': 100,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishFieldUpgradeWithGold(
    String upgradeId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'finish_building_upgrade_with_gold',
        params: {
          'p_player_id': user.id,
          'p_upgrade_id': upgradeId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFieldBoost({
    required String fieldId,
    required int durationHours,
    required int starCost,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_building_boost',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'field',
          'p_entity_id': fieldId,
          'p_duration_hours': durationHours,
          'p_star_cost': starCost,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeDueBuildingBoosts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'complete_due_building_boosts',
        params: {
          'p_limit': 100,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addProductionSlot(String fieldId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'add_production_slot',
        params: {
          'p_player_id': user.id,
          'p_owner_kind': 'field',
          'p_owner_id': fieldId,
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
    required ProductionInventoryModel inventory,
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

  Future<List<Map<String, dynamic>>> getEligibleWarehouseSlotsForInventoryAllCities({
    required ProductionInventoryModel inventory,
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
    required String productId,
  }) async {
    final warehouses = await _productionLogisticsService.getPlayerWarehouses();
    final typesResponse = await _supabase.rpc('get_warehouse_types_catalog');
    final typeRows = (typesResponse as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final eligibleWarehouses = warehouses.where((warehouse) {
      final typeId = (warehouse['warehouse_type_id'] ?? '').toString();
      if (typeId.isEmpty) return false;

      final typeRow = typeRows.cast<Map<String, dynamic>?>().firstWhere(
        (row) => row?['id']?.toString() == typeId,
        orElse: () => null,
      );
      if (typeRow == null) return false;

      final acceptedIds = _parseAcceptedProductIds(
        typeRow['accepted_product_ids'],
      );
      return acceptedIds.contains(productId.toUpperCase());
    }).toList();

    return eligibleWarehouses
        .map(
          (row) => ProductionLogisticsWarehouseOption.fromJson(
            row,
            productionCityId: productionCityId,
          ),
        )
        .toList();
  }

  List<String> _parseAcceptedProductIds(dynamic rawValue) {
    if (rawValue == null) return const [];

    final cleaned = rawValue
        .toString()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('"', '')
        .replaceAll("'", '');

    return cleaned
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
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

final fieldActionProvider = Provider((ref) => FieldActionNotifier());
