import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_history_item_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_performance_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _routeMismatchReason =
    'Aracin rotasi bu sehir ciftini desteklemiyor.';

final storesListProvider = FutureProvider<List<StoreModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return [];

  try {
    final results = await Future.wait([
      supabase.rpc(
        'get_stores_list',
        params: {'p_player_id': user.id},
      ),
      supabase.rpc(
        'get_player_building_constructions',
        params: {
          'p_building_kind': 'store',
          'p_status': 'in_progress',
        },
      ),
    ]);
    final response = results[0];
    final constructionResponse = results[1] as List<dynamic>;

    List<StoreModel> allStores = [];

    if (response != null && response['success'] == true) {
      final storesJson = response['stores'] as List<dynamic>;
      allStores = storesJson
          .map((json) => StoreModel.fromJson(json))
          .toList();
    }

    if (constructionResponse.isNotEmpty) {
      final catalogResults = await Future.wait([
        supabase.rpc('get_store_types_catalog'),
        supabase.rpc('get_cities_catalog'),
      ]);
      final allTypes = (catalogResults[0] as List)
          .map((json) => StoreTypeModel.fromJson(json))
          .toList();
      final allCities = (catalogResults[1] as List)
          .map((json) => CityModel.fromJson(json))
          .toList();

      for (final constr in constructionResponse) {
        final params = constr['params'] as Map<String, dynamic>;
        final storeTypeId = params['store_type_id'] as String?;
        final cityId = params['city_id'] as String?;

        final type = allTypes.firstWhere(
          (t) => t.id == storeTypeId,
          orElse: () => StoreTypeModel(
            id: 'unknown',
            name: 'Bilinmeyen',
            icon: 'default.webp',
          ),
        );

        final city = allCities.firstWhere(
          (c) => c.id == cityId,
          orElse: () => CityModel(
            id: '',
            name: 'Bilinmeyen Sehir',
            population: 0,
            taxRate: 0.0,
            mapPositionX: 0,
            mapPositionY: 0,
            isActive: true,
          ),
        );

        final startedAt = DateTime.parse(constr['started_at'] as String);
        final finishAt = DateTime.parse(constr['finish_at'] as String);
        final now = DateTime.now();

        final totalDuration = finishAt.difference(startedAt).inSeconds;
        final elapsed = now.difference(startedAt).inSeconds;
        final progress = totalDuration > 0
            ? (elapsed / totalDuration).clamp(0.0, 1.0)
            : 0.0;

        allStores.add(
          StoreModel(
            id: constr['id'] as String,
            name: params['name'] as String? ?? type.name,
            cityId: cityId,
            cityName: city.name,
            level: 1,
            isActive: false,
            currentSlotCount: 0,
            maxSlotCount: params['max_slot_count'] as int? ?? 0,
            slotCapacity: params['slot_capacity'] as int? ?? 0,
            storeType: type,
            summary: StoreSummaryModel(
              totalQuantity: 0,
              totalCapacity: params['slot_capacity'] as int? ?? 0,
              pendingQuantity: 0,
              availableCapacity: params['slot_capacity'] as int? ?? 0,
              usedCapacityRatio: 0.0,
            ),
            slots: const [],
            isUnderConstruction: true,
            startedAt: startedAt,
            finishAt: finishAt,
            constructionProgress: progress,
          ),
        );
      }
    }

    return allStores;
  } catch (e) {
    return [];
  }
});

final storeDetailProvider = FutureProvider.family<StoreModel, String>((
  ref,
  storeId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  final response = await supabase.rpc(
    'get_store_detail',
    params: {
      'p_player_id': user.id,
      'p_store_id': storeId,
    },
  );

  if (response['success'] == true) {
    return StoreModel.fromJson(response['store']);
  }

  throw Exception(
    response['message'] ?? 'Magaza detaylari alinirken hata olustu.',
  );
});

final storePerformanceProvider =
    FutureProvider.family<StorePerformanceResponseModel, String>((
      ref,
      storeId,
    ) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Kullanici girisi yapilmamis.');
      }

      final response = await supabase.rpc(
        'get_store_daily_performance',
        params: {
          'p_player_id': user.id,
          'p_store_id': storeId,
          'p_days': 14,
        },
      );

      final model = StorePerformanceResponseModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );

      if (!model.success) {
        throw Exception(model.message ?? 'Magaza performansi alinamadi.');
      }

      return model;
    });

final storeHistoryProvider =
    FutureProvider.family<List<StoreHistoryItemModel>, String>((ref, storeId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Kullanici girisi yapilmamis.');
      }

      final response = await supabase.rpc(
        'get_store_history_items',
        params: {'p_store_id': storeId},
      );

      return (response as List<dynamic>).map((row) {
        final json = Map<String, dynamic>.from(row as Map);
        return StoreHistoryItemModel(
          id: (json['id'] ?? '').toString(),
          type: (json['type'] ?? 'sale').toString(),
          happenedAt:
              DateTime.tryParse((json['happened_at'] ?? '').toString()) ??
              DateTime.now(),
          title: (json['title'] ?? '').toString(),
          subtitle: (json['subtitle'] ?? '').toString(),
          productName: (json['product_name'] ?? 'Urun').toString(),
          quantity: (json['quantity'] as num?)?.toInt() ?? 0,
          amount: (json['amount'] as num?)?.toDouble() ?? 0,
          secondaryAmount: (json['secondary_amount'] as num?)?.toDouble(),
          qualityLevel: (json['quality_level'] as num?)?.toInt(),
          status: (json['status'] ?? 'completed').toString(),
        );
      }).toList();
    });

final activeStoreUpgradeProvider =
    FutureProvider.family<BuildingUpgradeModel?, String>((ref, storeId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_upgrade',
        params: {
          'p_building_kind': 'store',
          'p_entity_id': storeId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingUpgradeModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

final activeStoreBoostProvider =
    FutureProvider.family<BuildingBoostModel?, String>((ref, storeId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_boost',
        params: {
          'p_building_kind': 'store',
          'p_entity_id': storeId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingBoostModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

final citiesProvider = FutureProvider<List<CityModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_active_cities');

  return (response as List).map((json) => CityModel.fromJson(json)).toList();
});

final storeTypesProvider = FutureProvider<List<StoreTypeModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_store_types_catalog');

  return (response as List)
      .map((json) => StoreTypeModel.fromJson(json))
      .toList();
});

class StoreActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createStore({
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
          'p_building_kind': 'store',
          'p_type_id': typeId,
          'p_city_id': cityId,
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

  Future<Map<String, dynamic>> completeConstruction(String constructionId) async {
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

  Future<Map<String, dynamic>> addStoreSlot(String storeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'add_store_slot',
        params: {
          'p_player_id': user.id,
          'p_store_id': storeId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startStoreUpgrade(String storeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_building_upgrade',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'store',
          'p_entity_id': storeId,
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

  Future<Map<String, dynamic>> finishStoreUpgradeWithGold(
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

  Future<Map<String, dynamic>> startStoreBoost({
    required String storeId,
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
          'p_building_kind': 'store',
          'p_entity_id': storeId,
          'p_duration_hours': durationHours,
          'p_star_cost': starCost,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAvailableProductsForStore(String storeId) async {
    try {
      final response = await _supabase.rpc(
        'get_available_products_for_store',
        params: {
          'p_store_id': storeId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setStoreSlotProduct({
    required String slotId,
    required String productId,
    int qualityLevel = 1,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_store_slot_product',
        params: {
          'p_player_id': user.id,
          'p_store_slot_id': slotId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setStoreSlotPrice({
    required String slotId,
    required double price,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_store_slot_price',
        params: {
          'p_player_id': user.id,
          'p_store_slot_id': slotId,
          'p_price': price,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> clearStoreSlotProduct(String slotId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'clear_store_slot_product',
        params: {
          'p_player_id': user.id,
          'p_store_slot_id': slotId,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setStoreSlotActive({
    required String slotId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_store_slot_active',
        params: {
          'p_player_id': user.id,
          'p_store_slot_id': slotId,
          'p_is_active': isActive,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getEligibleWarehousesForStock({
    required String productId,
    String? cityId,
    int? qualityLevel,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'get_player_active_warehouses_with_slots',
        params: {'p_city_id': cityId},
      );

      final warehouses = response as List<dynamic>;

      final eligible = warehouses.map((warehouse) {
        final slots = (warehouse['warehouse_slots'] as List<dynamic>)
            .where(
              (slot) =>
                  slot['product_id'] == productId &&
                  (qualityLevel == null ||
                      (slot['quality_level'] as num?)?.toInt() ==
                          qualityLevel) &&
                  (slot['quantity'] as num? ?? 0) > 0,
            )
            .toList();

        return {
          ...warehouse,
          'warehouse_slots': slots,
        };
      }).where((warehouse) {
        final slots = warehouse['warehouse_slots'] as List<dynamic>;
        return slots.isNotEmpty;
      }).toList();

      return {'success': true, 'warehouses': eligible};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> transferStockToStore({
    required String warehouseSlotId,
    required String storeSlotId,
    required int quantity,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'transfer_warehouse_slot_to_store_slot',
        params: {
          'p_player_id': user.id,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_store_slot_id': storeSlotId,
          'p_quantity': quantity,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<MarketTransferVehicleOptionModel>> getStoreTransferVehicleOptions({
    required String storeSlotId,
    required String warehouseSlotId,
    required int quantity,
  }) async {
    final response = await _supabase.rpc(
      'get_store_transfer_vehicle_options',
      params: {
        'p_store_slot_id': storeSlotId,
        'p_warehouse_slot_id': warehouseSlotId,
        'p_quantity': quantity,
      },
    );

    return (response as List<dynamic>)
        .map(
          (json) => MarketTransferVehicleOptionModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .where((option) => option.disabledReason != _routeMismatchReason)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPlayerWarehouses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await _supabase.rpc(
      'get_player_active_warehouses_basic',
    );

    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> startWarehouseToStoreTransfer({
    required String storeSlotId,
    required String warehouseSlotId,
    required int quantity,
    String? vehicleId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_warehouse_to_store_transfer',
        params: {
          'p_store_slot_id': storeSlotId,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_quantity': quantity,
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<MarketTransferVehicleOptionModel>>
      getStoreToWarehouseVehicleOptions({
    required String storeSlotId,
    required String warehouseId,
    required int quantity,
  }) async {
    final response = await _supabase.rpc(
      'get_store_to_warehouse_vehicle_options',
      params: {
        'p_store_slot_id': storeSlotId,
        'p_buyer_warehouse_id': warehouseId,
        'p_quantity': quantity,
      },
    );

    return (response as List<dynamic>)
        .map(
          (json) => MarketTransferVehicleOptionModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .where((option) => option.disabledReason != _routeMismatchReason)
        .toList();
  }

  Future<Map<String, dynamic>> startStoreToWarehouseTransfer({
    required String storeSlotId,
    required String warehouseId,
    required int quantity,
    String? vehicleId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_store_to_warehouse_transfer',
        params: {
          'p_store_slot_id': storeSlotId,
          'p_buyer_warehouse_id': warehouseId,
          'p_quantity': quantity,
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<StoreSaleResultModel> processStoreSalesOnEntry(String storeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const StoreSaleResultModel(
        success: false,
        processed: false,
        message: 'Oturum acilmamis.',
        processedAt: null,
        elapsedMinutes: 0,
        totalRevenue: 0,
        totalProfit: 0,
        totalSoldQuantity: 0,
        completedBoostCount: 0,
        items: [],
      );
    }

    try {
      final response = await _supabase.rpc(
        'process_store_sales_on_entry',
        params: {
          'p_player_id': user.id,
          'p_store_id': storeId,
        },
      );

      return StoreSaleResultModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      return StoreSaleResultModel(
        success: false,
        processed: false,
        message: e.toString(),
        processedAt: null,
        elapsedMinutes: 0,
        totalRevenue: 0,
        totalProfit: 0,
        totalSoldQuantity: 0,
        completedBoostCount: 0,
        items: const [],
      );
    }
  }
}

final storeActionProvider = Provider((ref) => StoreActionNotifier());
