import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/data/production_entry_service.dart';
import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

// Fabrika Listesi Provider
final factoryListProvider =
    FutureProvider<List<FactoryListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  await processProductionEntry(
    supabase: supabase,
    ownerKind: 'factory',
  );

  final response = await supabase.rpc('get_factory_list_items');
  final rows = response as List<dynamic>;

  return rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    return FactoryListItemModel(
      factory: FactoryModel.fromJson(
        Map<String, dynamic>.from(map['factory'] as Map),
      ),
      cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
      factoryTypeName:
          (map['factory_type_name'] ?? 'Bilinmeyen Fabrika').toString(),
      factoryTypeIcon: (map['factory_type_icon'] ?? 'factory.webp').toString(),
      inputStockQuantity: (map['input_stock_quantity'] as num?)?.toInt() ?? 0,
      outputStockQuantity:
          (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
      selectedProduct: map['selected_product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['selected_product'] as Map),
            ),
    );
  }).toList();
});

// Fabrika Tipleri Provider
final factoryTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase.rpc('get_factory_types_catalog');
});

final factoryConstructionProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final response = await supabase.rpc(
    'get_player_building_constructions',
    params: {
      'p_building_kind': 'factory',
      'p_status': 'in_progress',
    },
  );

  final rows = response as List<dynamic>;
  if (rows.isEmpty) return null;
  return rows.first as Map<String, dynamic>;
});

final factoryDetailProvider = FutureProvider.family<FactoryDetailModel, String>((
  ref,
  factoryId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  await processProductionEntry(
    supabase: supabase,
    ownerKind: 'factory',
    ownerId: factoryId,
  );

  final response = await supabase.rpc(
    'get_factory_detail_data',
    params: {'p_factory_id': factoryId},
  );

  final map = Map<String, dynamic>.from(response as Map);
  return FactoryDetailModel(
    factory: FactoryModel.fromJson(
      Map<String, dynamic>.from(map['factory'] as Map),
    ),
    factoryType: FactoryTypeDetailModel.fromJson(
      Map<String, dynamic>.from(map['factory_type'] as Map),
    ),
    cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
    product: map['product'] == null
        ? null
        : ProductModel.fromJson(
            Map<String, dynamic>.from(map['product'] as Map),
          ),
    inventories: (map['inventories'] as List<dynamic>? ?? const [])
        .map(
          (row) => FactoryProductionInventoryModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(),
  );
});

final activeFactoryUpgradeProvider =
    FutureProvider.family<BuildingUpgradeModel?, String>((ref, factoryId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_upgrade',
        params: {
          'p_building_kind': 'factory',
          'p_entity_id': factoryId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingUpgradeModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

final activeFactoryBoostProvider =
    FutureProvider.family<BuildingBoostModel?, String>((ref, factoryId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_boost',
        params: {
          'p_building_kind': 'factory',
          'p_entity_id': factoryId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingBoostModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

// Fabrika Aksiyonları
class FactoryActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  FactoryActionNotifier(this._ref);

  Future<Map<String, dynamic>> createFactory({
    required String cityId,
    required String typeId,
    required String name,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

    try {
      final response = await _supabase.rpc(
        'start_building_construction',
        params: {
          'p_player_id': user.id,
          'p_city_id': cityId,
          'p_building_kind': 'factory',
          'p_type_id': typeId,
          'p_name': name,
        },
      );
      _ref.invalidate(factoryConstructionProvider);
      _ref.invalidate(playerProvider);
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
      _ref.invalidate(factoryListProvider);
      _ref.invalidate(factoryConstructionProvider);
      _ref.invalidate(playerProvider);
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
      _ref.invalidate(factoryListProvider);
      _ref.invalidate(factoryConstructionProvider);
      _ref.invalidate(playerProvider);
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFactoryUpgrade(String factoryId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_building_upgrade',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'factory',
          'p_entity_id': factoryId,
        },
      );
      _ref.invalidate(activeFactoryUpgradeProvider(factoryId));
      _ref.invalidate(factoryDetailProvider(factoryId));
      _ref.invalidate(playerProvider);
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
      _ref.invalidate(factoryListProvider);
      _ref.invalidate(factoryDetailProvider);
      _ref.invalidate(playerProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishFactoryUpgradeWithGold(
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
      _ref.invalidate(factoryListProvider);
      _ref.invalidate(factoryDetailProvider);
      _ref.invalidate(playerProvider);
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFactoryBoost({
    required String factoryId,
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
          'p_building_kind': 'factory',
          'p_entity_id': factoryId,
          'p_duration_hours': durationHours,
          'p_star_cost': starCost,
        },
      );
      _ref.invalidate(activeFactoryBoostProvider(factoryId));
      _ref.invalidate(factoryDetailProvider(factoryId));
      _ref.invalidate(playerProvider);
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
      _ref.invalidate(factoryListProvider);
      _ref.invalidate(factoryDetailProvider);
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setFactoryProduct({
    required String factoryId,
    required String productId,
    required int qualityLevel,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_factory_product',
        params: {
          'p_player_id': user.id,
          'p_factory_id': factoryId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
        },
      );
      _ref.invalidate(factoryListProvider);
      _ref.invalidate(factoryDetailProvider(factoryId));
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setFactoryActive({
    required String factoryId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_factory_active',
        params: {
          'p_factory_id': factoryId,
          'p_is_active': isActive,
        },
      );
      _ref.invalidate(factoryListProvider);
      _ref.invalidate(factoryDetailProvider(factoryId));
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<SelectableProductionProductModel>> getSelectableProducts({
    required String typeId,
  }) {
    return fetchSelectableProductionProducts(
      supabase: _supabase,
      ownerKind: 'factory',
      typeId: typeId,
    );
  }

  Future<List<Map<String, dynamic>>> getEligibleWarehouseSlotsForInventory({
    required FactoryProductionInventoryModel inventory,
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
    required FactoryProductionInventoryModel inventory,
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
      // Invalidate factory details to show new inventory quantities
      _ref.invalidate(factoryDetailProvider);
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
      // Invalidate factory details to show updated inventory quantities
      _ref.invalidate(factoryDetailProvider);
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
  }) async {
    final result = await _productionLogisticsService.startWarehouseToProductionTransfer(
      warehouseSlotId: warehouseSlotId,
      productionInventoryId: productionInventoryId,
      quantity: quantity,
      vehicleId: vehicleId,
    );
    _ref.invalidate(factoryDetailProvider);
    _ref.invalidate(playerProvider);
    return result;
  }

  Future<ProductionLogisticsStartResult> startProductionToWarehouseTransfer({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
    String? vehicleId,
  }) async {
    final result = await _productionLogisticsService.startProductionToWarehouseTransfer(
      productionInventoryId: productionInventoryId,
      buyerWarehouseId: buyerWarehouseId,
      quantity: quantity,
      vehicleId: vehicleId,
    );
    _ref.invalidate(factoryDetailProvider);
    _ref.invalidate(playerProvider);
    return result;
  }
}

final factoryActionProvider = Provider((ref) => FactoryActionNotifier(ref));
