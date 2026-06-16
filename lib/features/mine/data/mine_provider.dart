import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/data/production_entry_service.dart';
import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

// Maden Liste Provider
final mineListProvider =
    FutureProvider<List<MineListItemModel>>((ref) async {
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
      cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
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
});

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

  final rows = response as List<dynamic>;
  if (rows.isEmpty) return null;
  return rows.first as Map<String, dynamic>;
});

final mineDetailProvider = FutureProvider.family<MineDetailModel, String>((
  ref,
  mineId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  await processProductionEntry(
    supabase: supabase,
    ownerKind: 'mine',
    ownerId: mineId,
  );

  final response = await supabase.rpc(
    'get_mine_detail_data',
    params: {'p_mine_id': mineId},
  );

  final map = Map<String, dynamic>.from(response as Map);
  return MineDetailModel(
    mine: MineModel.fromJson(
      Map<String, dynamic>.from(map['mine'] as Map),
    ),
    mineType: MineTypeDetailModel.fromJson(
      Map<String, dynamic>.from(map['mine_type'] as Map),
    ),
    cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
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
});

final activeMineUpgradeProvider =
    FutureProvider.family<BuildingUpgradeModel?, String>((ref, mineId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_upgrade',
        params: {
          'p_building_kind': 'mine',
          'p_entity_id': mineId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingUpgradeModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

final activeMineBoostProvider =
    FutureProvider.family<BuildingBoostModel?, String>((ref, mineId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_building_boost',
        params: {
          'p_building_kind': 'mine',
          'p_entity_id': mineId,
        },
      );

      if (response == null) {
        return null;
      }

      return BuildingBoostModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

// Maden Aksiyonları
class MineActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  MineActionNotifier(this._ref);

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
      _ref.invalidate(playerProvider);
      return response as Map<String, dynamic>;
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
      if (syncProviders) {
        _ref.invalidate(mineListProvider);
        _ref.invalidate(mineConstructionProvider);
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
        _ref.invalidate(mineListProvider);
        _ref.invalidate(mineConstructionProvider);
        _ref.invalidate(playerProvider);
      }
      return response as Map<String, dynamic>;
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
      if (syncProviders) {
        _ref.invalidate(activeMineUpgradeProvider(mineId));
        _ref.invalidate(mineDetailProvider(mineId));
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
      _ref.invalidate(mineListProvider);
      _ref.invalidate(mineDetailProvider);
      _ref.invalidate(playerProvider);
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
      final responseMap = Map<String, dynamic>.from(response as Map);
      if (syncProviders) {
        _ref.invalidate(mineListProvider);
        final entityId = responseMap['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(mineDetailProvider(entityId));
        }
        _ref.invalidate(playerProvider);
      }
      return responseMap;
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
      if (syncProviders) {
        _ref.invalidate(activeMineBoostProvider(mineId));
        _ref.invalidate(mineDetailProvider(mineId));
        _ref.invalidate(playerProvider);
      }
      return response as Map<String, dynamic>;
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
      if (syncProviders) {
        _ref.invalidate(mineListProvider);
        _ref.invalidate(mineDetailProvider(mineId));
      }
      return Map<String, dynamic>.from(response as Map);
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
      if (syncProviders) {
        _ref.invalidate(mineListProvider);
        _ref.invalidate(mineDetailProvider(mineId));
      }
      return Map<String, dynamic>.from(response as Map);
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
        _ref.invalidate(mineDetailProvider);
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
      _ref.invalidate(mineDetailProvider);
      _ref.invalidate(playerProvider);
    }
    return result;
  }
}

final mineActionProvider = Provider((ref) => MineActionNotifier(ref));
