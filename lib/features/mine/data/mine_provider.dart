import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/data/production_entry_service.dart';
import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

// ─── Maden Liste Notifier ───────────────────────────────────────────────────

class MineListNotifier extends AsyncNotifier<List<MineListItemModel>> {
  @override
  Future<List<MineListItemModel>> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return const [];

    await processProductionEntry(
      supabase: supabase,
      ownerKind: 'mine',
    );

    final response = await supabase.rpc('get_mine_list_items');
    final rows = response as List<dynamic>;

    return rows.map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      return MineListItemModel(
        mine: MineModel.fromJson(
          Map<String, dynamic>.from(map['mine'] as Map),
        ),
        cityName: (map['city_name'] ?? 'Bilinmeyen Şehir').toString(),
        mineTypeName: (map['mine_type_name'] ?? 'Bilinmeyen Maden').toString(),
        mineTypeIcon: (map['mine_type_icon'] ?? 'mine.webp').toString(),
        outputStockQuantity:
            (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
        selectedProduct: map['selected_product'] == null
            ? null
            : ProductModel.fromJson(
                Map<String, dynamic>.from(map['selected_product'] as Map),
              ),
      );
    }).toList();
  }

  void patchMineActive({
    required String mineId,
    required bool isActive,
  }) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((item) {
      if (item.mine.id == mineId) {
        return item.copyWith(
          mine: item.mine.copyWith(isActive: isActive),
        );
      }
      return item;
    }).toList();
    state = AsyncData(updated);
  }

  void patchMineProduct({
    required String mineId,
    required String productId,
    ProductModel? product,
  }) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((item) {
      if (item.mine.id == mineId) {
        return item.copyWith(
          mine: item.mine.copyWith(productId: productId),
          selectedProduct: product ?? item.selectedProduct,
        );
      }
      return item;
    }).toList();
    state = AsyncData(updated);
  }

  void patchMineLevel({
    required String mineId,
    required int level,
  }) {
    final current = state.value;
    if (current == null) return;
    final updated = current.map((item) {
      if (item.mine.id == mineId) {
        return item.copyWith(
          mine: item.mine.copyWith(level: level),
        );
      }
      return item;
    }).toList();
    state = AsyncData(updated);
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final mineListProvider =
    AsyncNotifierProvider<MineListNotifier, List<MineListItemModel>>(
  MineListNotifier.new,
);

// Maden Tipleri Provider
final mineTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.mineTypes;
});

final mineConstructionProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final response = await supabase.rpc(
    'get_player_building_constructions',
    params: {
      'p_building_kind': 'mine',
      'p_status': 'in_progress',
    },
  );

  final rows = response as List<dynamic>? ?? const [];
  if (rows.isEmpty) return null;
  return Map<String, dynamic>.from(rows.first as Map);
});

// ─── Maden Detay Notifier ───────────────────────────────────────────────────

class MineDetailNotifier extends AsyncNotifier<MineDetailModel> {
  MineDetailNotifier(this._mineId);

  final String _mineId;

  @override
  Future<MineDetailModel> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Kullanıcı girişi yapılmamış.');
    }

    await processProductionEntry(
      supabase: supabase,
      ownerKind: 'mine',
      ownerId: _mineId,
    );

    final response = await supabase.rpc(
      'get_mine_detail_data',
      params: {'p_mine_id': _mineId},
    );

    final map = Map<String, dynamic>.from(response as Map);
    return MineDetailModel(
      mine: MineModel.fromJson(
        Map<String, dynamic>.from(map['mine'] as Map),
      ),
      mineType: MineTypeDetailModel.fromJson(
        Map<String, dynamic>.from(map['mine_type'] as Map),
      ),
      cityName: (map['city_name'] ?? 'Bilinmeyen Şehir').toString(),
      product: map['product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['product'] as Map),
            ),
      inventories: (map['inventories'] as List<dynamic>? ?? const [])
          .map(
            (row) => MineProductionInventoryModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
    );
  }

  void patchMineActive(bool isActive) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        mine: current.mine.copyWith(isActive: isActive),
      ),
    );
  }

  void patchMineProduct({
    required String productId,
    required ProductModel product,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        mine: current.mine.copyWith(productId: productId),
        product: product,
      ),
    );
  }

  void patchMineLevel(int level) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        mine: current.mine.copyWith(level: level),
      ),
    );
  }

  void replaceInventory(List<MineProductionInventoryModel> newInventories) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(inventories: newInventories));
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final mineDetailProvider =
    AsyncNotifierProvider.family<MineDetailNotifier, MineDetailModel, String>(
  MineDetailNotifier.new,
);

class ActiveMineUpgradeNotifier extends AsyncNotifier<BuildingUpgradeModel?> {
  ActiveMineUpgradeNotifier(this._mineId);

  final String _mineId;

  @override
  Future<BuildingUpgradeModel?> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await supabase.rpc(
      'get_player_active_building_upgrade',
      params: {
        'p_building_kind': 'mine',
        'p_entity_id': _mineId,
      },
    );

    if (response == null) {
      return null;
    }

    return BuildingUpgradeModel.fromJsonNullable(
      Map<String, dynamic>.from(response as Map),
    );
  }

  void setUpgrade(BuildingUpgradeModel? upgrade) {
    state = AsyncData(upgrade);
  }

  void reduceTime(Duration duration) {
    final current = state.value;
    if (current == null) return;
    final reducedFinishAt = current.finishAt.subtract(duration);
    state = AsyncData(current.copyWith(finishAt: reducedFinishAt));
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final activeMineUpgradeProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveMineUpgradeNotifier, BuildingUpgradeModel?, String>(
      ActiveMineUpgradeNotifier.new,
    );

class ActiveMineBoostNotifier extends AsyncNotifier<BuildingBoostModel?> {
  ActiveMineBoostNotifier(this._mineId);

  final String _mineId;

  @override
  Future<BuildingBoostModel?> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await supabase.rpc(
      'get_player_active_building_boost',
      params: {
        'p_building_kind': 'mine',
        'p_entity_id': _mineId,
      },
    );

    if (response == null) {
      return null;
    }

    return BuildingBoostModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  void setBoost(BuildingBoostModel? boost) {
    state = AsyncData(boost);
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final activeMineBoostProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveMineBoostNotifier, BuildingBoostModel?, String>(
      ActiveMineBoostNotifier.new,
    );

// Maden Aksiyonları
class MineActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  MineActionNotifier(this._ref);

  Map<String, dynamic> _sync(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

  Future<Map<String, dynamic>> createMine({
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
          'p_building_kind': 'mine',
          'p_type_id': typeId,
          'p_name': name,
        },
      );
      _ref.invalidate(mineConstructionProvider);
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
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

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
        _ref.invalidate(mineListProvider);
        _ref.invalidate(mineConstructionProvider);
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
        _ref.invalidate(mineListProvider);
        _ref.invalidate(mineConstructionProvider);
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
        _ref.invalidate(mineListProvider);
        _ref.invalidate(mineConstructionProvider);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startMineUpgrade(
    String mineId, {
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
          'p_building_kind': 'mine',
          'p_entity_id': mineId,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeMineUpgradeProvider(mineId));
        _ref.invalidate(mineDetailProvider(mineId));
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
      _ref.invalidate(mineListProvider);
      _ref.invalidate(mineDetailProvider);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message, 'code': e.code};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishMineUpgradeWithGold(
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
        _ref.invalidate(mineListProvider);
        final entityId = result['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(mineDetailProvider(entityId));
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceMineUpgradeTimeWithAd(
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
        _ref.invalidate(mineListProvider);
        final entityId = result['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(mineDetailProvider(entityId));
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startMineBoost({
    required String mineId,
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
          'p_building_kind': 'mine',
          'p_entity_id': mineId,
          'p_duration_hours': durationHours,
          'p_star_cost': starCost,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeMineBoostProvider(mineId));
        _ref.invalidate(mineDetailProvider(mineId));
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startMineBoostWithAdReward({
    required String mineId,
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
          'p_building_kind': 'mine',
          'p_entity_id': mineId,
          'p_duration_minutes': durationMinutes,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeMineBoostProvider(mineId));
        _ref.invalidate(mineDetailProvider(mineId));
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<SelectableProductionProductModel>> getSelectableProducts({
    required String typeId,
  }) {
    return fetchSelectableProductionProducts(
      supabase: _supabase,
      ownerKind: 'mine',
      typeId: typeId,
    );
  }

  Future<Map<String, dynamic>> setMineProduct({
    required String mineId,
    required String productId,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_mine_product',
        params: {
          'p_mine_id': mineId,
          'p_player_id': user.id,
          'p_product_id': productId,
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      if (syncProviders) {
        final productJson = result['product'];
        ProductModel? product;
        if (productJson is Map) {
          try {
            product = ProductModel.fromJson(
              Map<String, dynamic>.from(productJson),
            );
          } catch (_) {}
        }
        if (product != null) {
          _ref
              .read(mineDetailProvider(mineId).notifier)
              .patchMineProduct(productId: productId, product: product);
          _ref
              .read(mineListProvider.notifier)
              .patchMineProduct(
                mineId: mineId,
                productId: productId,
                product: product,
              );
        } else {
          _ref.invalidate(mineListProvider);
          _ref.invalidate(mineDetailProvider(mineId));
        }

        final inventoriesRaw = result['inventories'] as List<dynamic>?;
        if (inventoriesRaw != null) {
          final newInventories = inventoriesRaw
              .map((i) => MineProductionInventoryModel.fromJson(
                    Map<String, dynamic>.from(i as Map),
                  ))
              .toList();
          _ref
              .read(mineDetailProvider(mineId).notifier)
              .replaceInventory(newInventories);
        }
      }
      return result;
    } catch (e) {
      final message = e.toString();
      if (message.contains('PGRST202')) {
        return {
          'success': false,
          'message':
              'Backend tarafinda set_mine_product fonksiyonu bulunamadi veya schema cache guncel degil.',
        };
      }
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setMineActive({
    required String mineId,
    required bool isActive,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_mine_active',
        params: {
          'p_mine_id': mineId,
          'p_is_active': isActive,
        },
      );
      final result = Map<String, dynamic>.from(response as Map);
      if (syncProviders) {
        _ref
            .read(mineDetailProvider(mineId).notifier)
            .patchMineActive(isActive);
        _ref
            .read(mineListProvider.notifier)
            .patchMineActive(mineId: mineId, isActive: isActive);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
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
      _ref.invalidate(mineDetailProvider);
      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(warehouseDetailProvider(buyerWarehouseId));
    }
    return result;
  }

  Future<Map<String, dynamic>> sellMine({
    required String mineId,
    required bool confirm,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'sell_building',
        params: {
          'p_building_id': mineId,
          'p_building_kind': 'mine',
          'p_confirm': confirm,
        },
      );
      _ref.invalidate(mineListProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final mineActionProvider = Provider((ref) => MineActionNotifier(ref));
