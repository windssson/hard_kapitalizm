import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_history_item_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';

Future<void> _tryCompleteDueWarehouseUpgrades(
  SupabaseClient supabase,
) async {
  try {
    await supabase.rpc(
      'complete_due_warehouse_upgrades',
      params: {'p_limit': 100},
    );
  } on PostgrestException catch (e) {
    final message = e.message.toLowerCase();
    final permissionDenied =
        e.code == '42501' ||
        message.contains('permission denied') ||
        message.contains('complete_due_warehouse_upgrades');
    if (!permissionDenied) rethrow;
  }
}

Future<List<WarehouseModel>> _fetchWarehouseList() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  try {
    await _tryCompleteDueWarehouseUpgrades(supabase);
    final response = await supabase.rpc('get_warehouse_list_page_data');
    final data = response['warehouses'] as List<dynamic>? ?? const [];
    return data
        .map((json) => WarehouseModel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  } catch (e) {
    throw Exception('Depo listesi alinamadi: $e');
  }
}

Future<WarehouseModel> _fetchWarehouseDetail(String warehouseId) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) throw Exception('Oturum acilmamis.');

  try {
    await _tryCompleteDueWarehouseUpgrades(supabase);
  } catch (_) {}

  final response = await supabase.rpc(
    'get_player_warehouse_detail',
    params: {'p_warehouse_id': warehouseId},
  );

  if (response == null) {
    throw Exception('Depo bulunamadi.');
  }

  return WarehouseModel.fromJson(response as Map<String, dynamic>);
}

class WarehouseListNotifier extends AsyncNotifier<List<WarehouseModel>> {
  @override
  Future<List<WarehouseModel>> build() => _fetchWarehouseList();

  Future<List<WarehouseModel>> refresh() async {
    final warehouses = await _fetchWarehouseList();
    state = AsyncData(warehouses);
    return warehouses;
  }

  void replaceWarehouse(WarehouseModel warehouse) {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((item) => item.id == warehouse.id);
    if (index < 0) return;

    final next = [...current];
    next[index] = warehouse;
    state = AsyncData(next);
  }

  void prependWarehouse(WarehouseModel warehouse) {
    final current = state.value ?? const <WarehouseModel>[];
    state = AsyncData([
      warehouse,
      ...current.where((item) => item.id != warehouse.id),
    ]);
  }

  void patchSlotPrice({
    required String warehouseId,
    required String slotId,
    required double price,
  }) {
    _patchSlot(
      warehouseId: warehouseId,
      slotId: slotId,
      patcher: (slot) => slot.copyWith(price: price),
    );
  }

  void patchSlotSaleStatus({
    required String warehouseId,
    required String slotId,
    required bool isAvailableForSale,
  }) {
    _patchSlot(
      warehouseId: warehouseId,
      slotId: slotId,
      patcher: (slot) => slot.copyWith(isAvailableForSale: isAvailableForSale),
    );
  }

  void removeSlot({
    required String warehouseId,
    required String slotId,
  }) {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((item) => item.id == warehouseId);
    if (index < 0) return;

    final warehouse = current[index];
    final next = [...current];
    next[index] = warehouse.copyWith(
      slots: warehouse.slots.where((slot) => slot.id != slotId).toList(),
    );
    state = AsyncData(next);
  }

  void patchSlotQuantity({
    required String warehouseId,
    required String slotId,
    required int quantity,
  }) {
    _patchSlot(
      warehouseId: warehouseId,
      slotId: slotId,
      patcher: (slot) => slot.copyWith(quantity: quantity),
    );
  }

  void _patchSlot({
    required String warehouseId,
    required String slotId,
    required WarehouseSlotModel Function(WarehouseSlotModel slot) patcher,
  }) {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((item) => item.id == warehouseId);
    if (index < 0) return;

    final warehouse = current[index];
    final slots = warehouse.slots
        .map((slot) => slot.id == slotId ? patcher(slot) : slot)
        .toList();

    final next = [...current];
    next[index] = warehouse.copyWith(slots: slots);
    state = AsyncData(next);
  }
}

final warehouseListProvider =
    AsyncNotifierProvider<WarehouseListNotifier, List<WarehouseModel>>(
      WarehouseListNotifier.new,
    );

class WarehouseDetailNotifier extends AsyncNotifier<WarehouseModel> {
  WarehouseDetailNotifier(this._warehouseId);

  final String _warehouseId;

  @override
  Future<WarehouseModel> build() => _fetchWarehouseDetail(_warehouseId);

  Future<WarehouseModel> refresh() async {
    final warehouse = await _fetchWarehouseDetail(_warehouseId);
    state = AsyncData(warehouse);
    return warehouse;
  }

  void replaceWarehouse(WarehouseModel warehouse) {
    state = AsyncData(warehouse);
  }

  void patchSlotPrice({
    required String slotId,
    required double price,
  }) {
    _patchSlot(
      slotId: slotId,
      patcher: (slot) => slot.copyWith(price: price),
    );
  }

  void patchSlotSaleStatus({
    required String slotId,
    required bool isAvailableForSale,
  }) {
    _patchSlot(
      slotId: slotId,
      patcher: (slot) => slot.copyWith(isAvailableForSale: isAvailableForSale),
    );
  }

  void removeSlot(String slotId) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        slots: current.slots.where((slot) => slot.id != slotId).toList(),
      ),
    );
  }

  void patchSlotQuantity({
    required String slotId,
    required int quantity,
  }) {
    _patchSlot(
      slotId: slotId,
      patcher: (slot) => slot.copyWith(quantity: quantity),
    );
  }

  void _patchSlot({
    required String slotId,
    required WarehouseSlotModel Function(WarehouseSlotModel slot) patcher,
  }) {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        slots: current.slots
            .map((slot) => slot.id == slotId ? patcher(slot) : slot)
            .toList(),
      ),
    );
  }
}

final warehouseDetailProvider = AsyncNotifierProvider.family<
    WarehouseDetailNotifier,
    WarehouseModel,
    String
  >(WarehouseDetailNotifier.new);

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
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.products;
});

final warehouseTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.warehouseTypes;
});

final warehouseHistoryProvider =
    FutureProvider.family<List<WarehouseHistoryItemModel>, String>((
      ref,
      warehouseId,
    ) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Kullanici girisi yapilmamis.');
      }

      final response = await supabase.rpc(
        'get_warehouse_history_items',
        params: {'p_warehouse_id': warehouseId},
      );

      return (response as List<dynamic>)
          .map(
            (row) => WarehouseHistoryItemModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    });

final activeWarehouseUpgradeProvider =
    FutureProvider.autoDispose.family<BuildingUpgradeModel?, String>((ref, warehouseId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        return null;
      }

      final response = await supabase.rpc(
        'get_player_active_warehouse_upgrade',
        params: {'p_warehouse_id': warehouseId},
      );

      if (response == null) {
        return null;
      }

      return BuildingUpgradeModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

final anyActiveWarehouseUpgradeProvider =
    FutureProvider.autoDispose<BuildingUpgradeModel?>((ref) async {
      final supabase = Supabase.instance.client;
      return fetchAnyActiveBuildingUpgrade(supabase);
    });

class WarehouseActionNotifier {
  WarehouseActionNotifier(this._ref);

  final Ref _ref;
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

  Future<Map<String, dynamic>> startWarehouseUpgrade(
    String warehouseId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_warehouse_upgrade',
        params: {
          'p_player_id': user.id,
          'p_warehouse_id': warehouseId,
        },
      );
      final responseMap = Map<String, dynamic>.from(response as Map);
      if (syncProviders && responseMap['success'] == true) {
        _ref.invalidate(activeWarehouseUpgradeProvider(warehouseId));
        _ref.invalidate(warehouseDetailProvider(warehouseId));
        _ref.invalidate(warehouseListProvider);
        _ref.invalidate(playerProvider);
      }
      return responseMap;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeDueWarehouseUpgrades() async {
    try {
      await _tryCompleteDueWarehouseUpgrades(_supabase);
      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(playerProvider);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message, 'code': e.code};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishWarehouseUpgradeWithGold(
    String upgradeId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'finish_warehouse_upgrade_with_gold',
        params: {
          'p_player_id': user.id,
          'p_upgrade_id': upgradeId,
        },
      );
      final responseMap = Map<String, dynamic>.from(response as Map);
      if (syncProviders && responseMap['success'] == true) {
        final entityId = responseMap['entity_id']?.toString();
        _ref.invalidate(warehouseListProvider);
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(activeWarehouseUpgradeProvider(entityId));
          _ref.invalidate(warehouseDetailProvider(entityId));
        }
        _ref.invalidate(playerProvider);
      }
      return responseMap;
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

final warehouseActionProvider = Provider((ref) => WarehouseActionNotifier(ref));
