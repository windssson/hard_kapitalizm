import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/data/production_entry_service.dart';
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
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

final fieldListProvider =
    FutureProvider<List<FieldListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  await processProductionEntry(
    supabase: supabase,
    ownerKind: 'field',
  );

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
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.fieldTypes;
});

final fieldConstructionProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
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

  await processProductionEntry(
    supabase: supabase,
    ownerKind: 'field',
    ownerId: fieldId,
  );

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
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  FieldActionNotifier(this._ref);

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
      _ref.invalidate(fieldConstructionProvider);
      _ref.invalidate(playerProvider);
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(
    String constructionId, {
    bool syncProviders = true,
  }
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
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        _ref.invalidate(fieldConstructionProvider);
      }
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishConstructionWithGold(
    String constructionId,
    {
    bool syncProviders = true,
  }
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
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        _ref.invalidate(fieldConstructionProvider);
        _ref.invalidate(playerProvider);
      }
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFieldUpgrade(
    String fieldId, {
    bool syncProviders = true,
  }) async {
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
      if (syncProviders) {
        _ref.invalidate(activeFieldUpgradeProvider(fieldId));
        _ref.invalidate(fieldDetailProvider(fieldId));
        _ref.invalidate(playerProvider);
      }
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
      await tryCompleteDueBuildingUpgrades(_supabase);
      _ref.invalidate(fieldListProvider);
      _ref.invalidate(fieldDetailProvider);
      _ref.invalidate(playerProvider);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message, 'code': e.code};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishFieldUpgradeWithGold(
    String upgradeId,
    {
    bool syncProviders = true,
  }
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
      final responseMap = Map<String, dynamic>.from(response as Map);
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        final entityId = responseMap['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(fieldDetailProvider(entityId));
        }
        _ref.invalidate(playerProvider);
      }
      return responseMap;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFieldBoost({
    required String fieldId,
    required int durationHours,
    required int starCost,
    bool syncProviders = true,
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
      if (syncProviders) {
        _ref.invalidate(activeFieldBoostProvider(fieldId));
        _ref.invalidate(fieldDetailProvider(fieldId));
        _ref.invalidate(playerProvider);
      }
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addProductionSlot(
    String fieldId, {
    bool syncProviders = true,
  }) async {
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
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        _ref.invalidate(fieldDetailProvider(fieldId));
        _ref.invalidate(playerProvider);
      }
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignProductionSlotProduct({
    required String slotId,
    required String productId,
    required int qualityLevel,
    bool syncProviders = true,
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
      final responseMap = Map<String, dynamic>.from(response as Map);
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        final ownerId = responseMap['owner_id']?.toString();
        if (ownerId != null && ownerId.isNotEmpty) {
          _ref.invalidate(fieldDetailProvider(ownerId));
        }
      }
      return responseMap;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changeProductionSlotProduct({
    required String slotId,
    required String productId,
    required int qualityLevel,
    bool syncProviders = true,
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
      final responseMap = Map<String, dynamic>.from(response as Map);
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        final ownerId = responseMap['owner_id']?.toString();
        if (ownerId != null && ownerId.isNotEmpty) {
          _ref.invalidate(fieldDetailProvider(ownerId));
        }
      }
      return responseMap;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setProductionSlotActive({
    required String slotId,
    required bool isActive,
    bool syncProviders = true,
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
      final responseMap = Map<String, dynamic>.from(response as Map);
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        final ownerId = responseMap['owner_id']?.toString();
        if (ownerId != null && ownerId.isNotEmpty) {
          _ref.invalidate(fieldDetailProvider(ownerId));
        }
      }
      return responseMap;
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
    bool syncProviders = true,
  }) async {
    try {
      final result = await _productionLogisticsService
          .startWarehouseToProductionTransfer(
            warehouseSlotId: warehouseSlotId,
            productionInventoryId: productionInventoryId,
            quantity: quantity,
            vehicleId: null,
          );
      if (syncProviders) {
        _ref.invalidate(fieldDetailProvider);
      }
      return {
        'success': result.success,
        'message': result.message,
        'transfer_id': result.transferId,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> transferProductionInventoryToWarehouse({
    required String productionInventoryId,
    required String warehouseId,
    required int quantity,
    bool syncProviders = true,
  }) async {
    try {
      final result = await _productionLogisticsService
          .startProductionToWarehouseTransfer(
            productionInventoryId: productionInventoryId,
            buyerWarehouseId: warehouseId,
            quantity: quantity,
            vehicleId: null,
          );
      if (syncProviders) {
        _ref.invalidate(fieldDetailProvider);
      }
      return {
        'success': result.success,
        'message': result.message,
        'transfer_id': result.transferId,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<ProductionLogisticsWarehouseOption>>
  getWarehousesForProductionLogistics({
    required String productionCityId,
    required String productId,
  }) async {
    return _productionLogisticsService.getWarehouseOptions(
      productionCityId: productionCityId,
      productId: productId,
    );
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

  Future<TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>>
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

  Future<TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>>
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
    bool syncProviders = true,
  }) async {
    final result = await _productionLogisticsService.startWarehouseToProductionTransfer(
      warehouseSlotId: warehouseSlotId,
      productionInventoryId: productionInventoryId,
      quantity: quantity,
      vehicleId: vehicleId,
    );
    if (syncProviders) {
      _ref.invalidate(fieldDetailProvider);
      _ref.invalidate(playerProvider);
    }
    return result;
  }

  Future<ProductionLogisticsStartResult> startProductionToWarehouseTransfer({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
    String? vehicleId,
    bool syncProviders = true,
  }) async {
    final result = await _productionLogisticsService.startProductionToWarehouseTransfer(
      productionInventoryId: productionInventoryId,
      buyerWarehouseId: buyerWarehouseId,
      quantity: quantity,
      vehicleId: vehicleId,
    );
    if (syncProviders) {
      _ref.invalidate(fieldDetailProvider);
      _ref.invalidate(playerProvider);
    }
    return result;
  }
}

final fieldActionProvider = Provider((ref) => FieldActionNotifier(ref));
