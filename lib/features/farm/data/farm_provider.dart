import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/data/production_entry_service.dart';
import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_list_item_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';

final farmListProvider =
    FutureProvider<List<FarmListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  await processProductionEntry(
    supabase: supabase,
    ownerKind: 'farm',
  );

  final response = await supabase.rpc('get_farm_list_items');
  final rows = response as List<dynamic>;

  return rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    return FarmListItemModel(
      farm: FarmModel.fromJson(
        Map<String, dynamic>.from(map['farm'] as Map),
      ),
      cityName: (map['city_name'] ?? 'Bilinmeyen Şehir').toString(),
      farmTypeName: (map['farm_type_name'] ?? 'Bilinmeyen Tarla').toString(),
      farmTypeIcon: (map['farm_type_icon'] ?? 'farm.webp').toString(),
      outputStockQuantity:
          (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
      inputStockQuantity:
          (map['input_stock_quantity'] as num?)?.toInt() ?? 0,
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
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.farmTypes;
});

final farmConstructionProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
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

      final rows = response as List<dynamic>? ?? const [];
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first as Map);
    });

final farmDetailProvider = FutureProvider.family<FarmDetailModel, String>((
  ref,
  farmId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanıcı girişi yapılmamış.');
  }

  await processProductionEntry(
    supabase: supabase,
    ownerKind: 'farm',
    ownerId: farmId,
  );

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
    cityName: (farmPayload['city_name'] ?? 'Bilinmeyen Şehir').toString(),
    slots: slotRows.map(FarmProductionSlotModel.fromJson).toList(),
    inventories: inventoryRows
        .map(FarmProductionInventoryModel.fromJson)
        .toList(),
  );
});

final activeFarmUpgradeProvider =
    FutureProvider.family<BuildingUpgradeModel?, String>((ref, farmId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_upgrade',
        params: {
          'p_building_kind': 'farm',
          'p_entity_id': farmId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingUpgradeModel.fromJsonNullable(
        Map<String, dynamic>.from(response as Map),
      );
    });

final activeFarmBoostProvider =
    FutureProvider.family<BuildingBoostModel?, String>((ref, farmId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_boost',
        params: {
          'p_building_kind': 'farm',
          'p_entity_id': farmId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingBoostModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

class FarmActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  FarmActionNotifier(this._ref);

  Map<String, dynamic> _sync(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

  Future<void> _refreshAttentionNotifications() async {
    try {
      await _supabase.rpc('refresh_player_attention_notifications');
    } catch (_) {
      // Ignore attention refresh errors; primary action already succeeded.
    }
    _ref.invalidate(playerNotificationDashboardProvider);
    _ref.invalidate(homeDashboardProvider);
  }

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
      _ref.invalidate(farmConstructionProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(
    String constructionId, {
    bool syncProviders = true,
  }) async {
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
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(farmListProvider);
        _ref.invalidate(farmConstructionProvider);
      }
      return result;
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
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(farmListProvider);
        _ref.invalidate(farmConstructionProvider);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceConstructionTimeWithAd(
    String constructionId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'reduce_construction_time_with_ad',
        params: {
          'p_player_id': user.id,
          'p_construction_id': constructionId,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(farmListProvider);
        _ref.invalidate(farmConstructionProvider);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFarmUpgrade(
    String farmId, {
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
          'p_building_kind': 'farm',
          'p_entity_id': farmId,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeFarmUpgradeProvider(farmId));
        _ref.invalidate(farmDetailProvider(farmId));
      }
      return result;
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
      _ref.invalidate(farmListProvider);
      _ref.invalidate(farmDetailProvider);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message, 'code': e.code};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishFarmUpgradeWithGold(
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
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(farmListProvider);
        final entityId = result['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(farmDetailProvider(entityId));
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceFarmUpgradeTimeWithAd(
    String upgradeId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'reduce_building_upgrade_time_with_ad',
        params: {
          'p_player_id': user.id,
          'p_upgrade_id': upgradeId,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(farmListProvider);
        final entityId = result['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(farmDetailProvider(entityId));
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFarmBoost({
    required String farmId,
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
          'p_building_kind': 'farm',
          'p_entity_id': farmId,
          'p_duration_hours': durationHours,
          'p_star_cost': starCost,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeFarmBoostProvider(farmId));
        _ref.invalidate(farmDetailProvider(farmId));
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFarmBoostWithAdReward({
    required String farmId,
    int durationMinutes = 30,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_building_boost_with_ad_reward',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'farm',
          'p_entity_id': farmId,
          'p_duration_minutes': durationMinutes,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeFarmBoostProvider(farmId));
        _ref.invalidate(farmDetailProvider(farmId));
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addProductionSlot(
    String farmId, {
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
          'p_owner_kind': 'farm',
          'p_owner_id': farmId,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(farmListProvider);
        _ref.invalidate(farmDetailProvider(farmId));
      }
      return result;
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
        _ref.invalidate(farmListProvider);
        final ownerId = responseMap['owner_id']?.toString();
        if (ownerId != null && ownerId.isNotEmpty) {
          _ref.invalidate(farmDetailProvider(ownerId));
        }
      }
      await _refreshAttentionNotifications();
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
        _ref.invalidate(farmListProvider);
        final ownerId = responseMap['owner_id']?.toString();
        if (ownerId != null && ownerId.isNotEmpty) {
          _ref.invalidate(farmDetailProvider(ownerId));
        }
      }
      await _refreshAttentionNotifications();
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
        _ref.invalidate(farmListProvider);
        final ownerId = responseMap['owner_id']?.toString();
        if (ownerId != null && ownerId.isNotEmpty) {
          _ref.invalidate(farmDetailProvider(ownerId));
        }
      }
      await _refreshAttentionNotifications();
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

  Future<List<Map<String, dynamic>>> getPlayerWarehousesRaw() {
    return _productionLogisticsService.getPlayerWarehousesRaw();
  }

  Future<List<Map<String, dynamic>>> getPlayerWarehousesWithSlotsRaw() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum acilmamis.');

    final response = await _supabase.rpc(
      'get_player_active_warehouses_with_slots',
    );

    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>>
  getProductionRouteVehicleOptions({
    required String sourceCityId,
    required String targetCityId,
    required double totalVolume,
  }) {
    return _productionLogisticsService.getRouteVehicleOptions(
      sourceCityId: sourceCityId,
      targetCityId: targetCityId,
      totalVolume: totalVolume,
    );
  }

  Future<ProductionLogisticsStartResult> startMultiWarehouseToProductionTransfer({
    required String sourceWarehouseId,
    String? productionInventoryId,
    required List<Map<String, dynamic>> items,
    String? vehicleId,
    bool syncProviders = true,
  }) async {
    final result = await _productionLogisticsService
        .startMultiWarehouseToProductionTransfer(
          sourceWarehouseId: sourceWarehouseId,
          productionInventoryId: productionInventoryId,
          items: items,
          vehicleId: vehicleId,
        );
    if (syncProviders) {
      _ref.invalidate(farmDetailProvider);
      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(warehouseDetailProvider(sourceWarehouseId));
    }
    await _refreshAttentionNotifications();
    return result;
  }

  Future<ProductionLogisticsStartResult> startMultiProductionToWarehouseTransfer({
    required String sourceOwnerKind,
    required String sourceOwnerId,
    required String buyerWarehouseId,
    required List<Map<String, dynamic>> items,
    String? vehicleId,
    bool syncProviders = true,
  }) async {
    final result = await _productionLogisticsService
        .startMultiProductionToWarehouseTransfer(
          sourceOwnerKind: sourceOwnerKind,
          sourceOwnerId: sourceOwnerId,
          buyerWarehouseId: buyerWarehouseId,
          items: items,
          vehicleId: vehicleId,
        );
    if (syncProviders) {
      _ref.invalidate(farmDetailProvider);
      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(warehouseDetailProvider(buyerWarehouseId));
    }
    await _refreshAttentionNotifications();
    return result;
  }

  Future<Map<String, dynamic>> sellFarm({
    required String farmId,
    required bool confirm,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'sell_building',
        params: {
          'p_building_id': farmId,
          'p_building_kind': 'farm',
          'p_confirm': confirm,
        },
      );
      _ref.invalidate(farmListProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final farmActionProvider = Provider((ref) => FarmActionNotifier(ref));
