import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_detail_page_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_history_item_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_performance_model.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final storeHistoryDirtyProvider = StateProvider.family<bool, String>(
  (ref, storeId) => false,
);

final storePerformanceDirtyProvider = StateProvider.family<bool, String>(
  (ref, storeId) => false,
);

final cityStoreSaturationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, cityId) async {
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase.rpc(
      'get_city_store_saturations',
      params: {'p_city_id': cityId},
    );
    if (response is List) {
      return response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  } catch (e) {
    return [];
  }
});

Future<List<StoreModel>> _fetchStoresList() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return [];

  try {
    final response = await supabase.rpc('get_store_list_page_data');
    final storesJson = (response['stores'] as List<dynamic>? ?? const []);
    return storesJson
        .map((json) => StoreModel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  } catch (e) {
    return [];
  }
}

Future<StoreDetailPageModel> _fetchStoreDetailPage(String storeId) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanıcı girişi yapılmamış.');
  }

  final response = await supabase.rpc(
    'open_store_detail_page',
    params: {
      'p_store_id': storeId,
    },
  );

  final json = Map<String, dynamic>.from(response as Map);
  if (json['success'] != true) {
    throw Exception(
      json['message'] ?? 'Mağaza detay sayfası açılırken hata oluştu.',
    );
  }

  return StoreDetailPageModel.fromJson(json);
}

class StoresListNotifier extends AsyncNotifier<List<StoreModel>> {
  @override
  Future<List<StoreModel>> build() => _fetchStoresList();

  Future<List<StoreModel>> refresh() async {
    final stores = await _fetchStoresList();
    state = AsyncData(stores);
    return stores;
  }

  void replaceStore(StoreModel store) {
    final current = state.value;
    if (current == null) return;

    final index = current.indexWhere((item) => item.id == store.id);
    if (index < 0) return;

    final next = [...current];
    next[index] = store;
    state = AsyncData(next);
  }

  void patchStoreActive({
    required String storeId,
    required bool isActive,
  }) {
    final current = state.value;
    if (current == null) return;

    final storeIndex = current.indexWhere((item) => item.id == storeId);
    if (storeIndex < 0) return;

    final next = [...current];
    next[storeIndex] = next[storeIndex].copyWith(isActive: isActive);
    state = AsyncData(next);
  }

  void removeStore(String storeId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((item) => item.id != storeId).toList());
  }

  void patchSlotActive({
    required String storeId,
    required String slotId,
    required bool isActive,
  }) {
    _patchStoreSlot(
      storeId: storeId,
      slotId: slotId,
      patcher: (slot) => slot.copyWith(isActive: isActive),
    );
  }

  void patchSlotPrice({
    required String storeId,
    required String slotId,
    required double price,
  }) {
    _patchStoreSlot(
      storeId: storeId,
      slotId: slotId,
      patcher: (slot) => slot.copyWith(price: price),
    );
  }

  void bulkPatchSlotPrices({
    required String storeId,
    required List<dynamic> updatedSlots,
  }) {
    final current = state.value;
    if (current == null) return;
    final priceMap = <String, double>{};
    for (final item in updatedSlots) {
      if (item is Map) {
        final id = (item['slot_id'] ?? item['id'])?.toString();
        final price = (item['price'] as num?)?.toDouble();
        if (id != null && price != null) {
          priceMap[id] = price;
        }
      }
    }
    if (priceMap.isEmpty) return;

    final storeIndex = current.indexWhere((item) => item.id == storeId);
    if (storeIndex < 0) return;

    final store = current[storeIndex];
    final slots = store.slots.map((slot) {
      if (priceMap.containsKey(slot.id)) {
        return slot.copyWith(price: priceMap[slot.id]);
      }
      return slot;
    }).toList();

    final next = [...current];
    next[storeIndex] = store.copyWith(slots: slots);
    state = AsyncData(next);
  }

  void patchSlotCleared({
    required String storeId,
    required String slotId,
  }) {
    _patchStoreSlot(
      storeId: storeId,
      slotId: slotId,
      patcher: (slot) => StoreSlotModel(
        id: slot.id,
        storeId: slot.storeId,
        slotIndex: slot.slotIndex,
        brandId: '00000000-0000-0000-0000-000000000000',
        productId: null,
        productName: null,
        productIcon: null,
        quantity: slot.quantity,
        pendingQuantity: slot.pendingQuantity,
        qualityLevel: 0,
        price: 0,
        cost: 0,
        capacity: slot.capacity,
        boostMultiplier: slot.boostMultiplier,
        pendingSale: 0,
        isActive: slot.isActive,
        isEmpty: true,
        usedCapacityRatio: slot.usedCapacityRatio,
        product: null,
      ),
    );
  }

  void patchSlotProduct({
    required String storeId,
    required String slotId,
    required String productId,
    required int qualityLevel,
    String? brandId,
    String? productName,
    String? productIcon,
  }) {
    _patchStoreSlot(
      storeId: storeId,
      slotId: slotId,
      patcher: (slot) => slot.copyWith(
        productId: productId,
        productName: productName ?? slot.productName,
        productIcon: productIcon ?? slot.productIcon,
        brandId: brandId ?? slot.brandId,
        qualityLevel: qualityLevel,
        isEmpty: false,
      ),
    );
  }

  void _patchStoreSlot({
    required String storeId,
    required String slotId,
    required StoreSlotModel Function(StoreSlotModel slot) patcher,
  }) {
    final current = state.value;
    if (current == null) return;

    final storeIndex = current.indexWhere((item) => item.id == storeId);
    if (storeIndex < 0) return;

    final store = current[storeIndex];
    final slots = store.slots
        .map((slot) => slot.id == slotId ? patcher(slot) : slot)
        .toList();

    final next = [...current];
    next[storeIndex] = store.copyWith(slots: slots);
    state = AsyncData(next);
  }

  void patchStoreLevel({required String storeId, required int level}) {
    final current = state.value;
    if (current == null) return;
    final storeIndex = current.indexWhere((item) => item.id == storeId);
    if (storeIndex < 0) return;
    final store = current[storeIndex];
    final next = [...current];
    next[storeIndex] = store.copyWith(level: level);
    state = AsyncData(next);
  }
}

final storesListProvider =
    AsyncNotifierProvider<StoresListNotifier, List<StoreModel>>(
      StoresListNotifier.new,
    );

class StoreDetailPageNotifier extends AsyncNotifier<StoreDetailPageModel> {
  StoreDetailPageNotifier(this._storeId);

  final String _storeId;

  @override
  Future<StoreDetailPageModel> build() async {
    final page = await _fetchStoreDetailPage(_storeId);
    // Mağaza açıldığında satış hesaplanmış olabilir; player cash ve
    // history/performance dirty flaglerini sync et.
    _applyPageChanges(page);
    return page;
  }

  Future<StoreDetailPageModel> refresh() async {
    final page = await _fetchStoreDetailPage(_storeId);
    _applyPageChanges(page);
    state = AsyncData(page);
    return page;
  }

  void _applyPageChanges(StoreDetailPageModel page) {
    // Player cash/gold/level patch (open_store_detail_page changed.player bloğunu döner)
    if (page.changed.player != null) {
      ref.read(playerProvider.notifier).replacePlayer(page.changed.player!);
    }
    // Tax debt patch — open_store_detail_page response'unda tax_dirty true ise vergi sağlayıcılarını geçersiz kıl
    if (page.changed.taxDirty) {
      ref.invalidate(taxDebtProvider);
      ref.invalidate(playerTaxProvider);
    }
  }

  void replacePage(StoreDetailPageModel page) {
    state = AsyncData(page);
  }

  void patchStoreActive(bool isActive) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(store: current.store.copyWith(isActive: isActive)),
    );
  }

  void clearSaleResult() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      StoreDetailPageModel(
        success: current.success,
        store: current.store,
        storeWarehouse: current.storeWarehouse,
        activeBoost: current.activeBoost,
        activeUpgrade: current.activeUpgrade,
        saleResult: null,
        changed: current.changed,
      ),
    );
  }

  Future<StoreDetailPageModel> triggerTutorialFirstSale() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı girişi yapılmamış.');
    }

    final response = await supabase.rpc(
      'trigger_tutorial_first_sale',
      params: {
        'p_store_id': _storeId,
      },
    );

    final json = Map<String, dynamic>.from(response as Map);
    if (json['success'] != true) {
      throw Exception(
        json['message'] ?? 'Rehber satisi baslatilirken hata olustu.',
      );
    }

    final page = StoreDetailPageModel.fromJson(json);
    _applyPageChanges(page);
    state = AsyncData(page);
    return page;
  }

  void patchSlotActive({
    required String slotId,
    required bool isActive,
  }) {
    _patchStoreSlot(
      slotId: slotId,
      patcher: (slot) => slot.copyWith(isActive: isActive),
    );
  }

  void patchSlotPrice({
    required String slotId,
    required double price,
  }) {
    _patchStoreSlot(
      slotId: slotId,
      patcher: (slot) => slot.copyWith(price: price),
    );
  }

  void patchSlotCleared({
    required String slotId,
  }) {
    _patchStoreSlot(
      slotId: slotId,
      patcher: (slot) => StoreSlotModel(
        id: slot.id,
        storeId: slot.storeId,
        slotIndex: slot.slotIndex,
        brandId: '00000000-0000-0000-0000-000000000000',
        productId: null,
        productName: null,
        productIcon: null,
        quantity: slot.quantity,
        pendingQuantity: slot.pendingQuantity,
        qualityLevel: 0,
        price: 0,
        cost: 0,
        capacity: slot.capacity,
        boostMultiplier: slot.boostMultiplier,
        pendingSale: 0,
        isActive: slot.isActive,
        isEmpty: true,
        usedCapacityRatio: slot.usedCapacityRatio,
        product: null,
      ),
    );
  }

  void patchSlotProduct({
    required String slotId,
    required String productId,
    required int qualityLevel,
    String? brandId,
    String? productName,
    String? productIcon,
  }) {
    _patchStoreSlot(
      slotId: slotId,
      patcher: (slot) => slot.copyWith(
        productId: productId,
        productName: productName ?? slot.productName,
        productIcon: productIcon ?? slot.productIcon,
        brandId: brandId ?? slot.brandId,
        qualityLevel: qualityLevel,
        isEmpty: false,
      ),
    );
  }

  void markHistoryDirty([bool value = true]) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        changed: current.changed.copyWith(historyDirty: value),
      ),
    );
  }

  void markPerformanceDirty([bool value = true]) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        changed: current.changed.copyWith(performanceDirty: value),
      ),
    );
  }

  void _patchStoreSlot({
    required String slotId,
    required StoreSlotModel Function(StoreSlotModel slot) patcher,
  }) {
    final current = state.value;
    if (current == null) return;

    final slots = current.store.slots
        .map((slot) => slot.id == slotId ? patcher(slot) : slot)
        .toList();

    state = AsyncData(
      current.copyWith(
        store: current.store.copyWith(slots: slots),
      ),
    );
  }
  /// patchActiveBoost: Aktif boost bilgisini günceller.
  void patchActiveBoost(BuildingBoostModel? boost) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(activeBoost: boost));
  }

  /// patchActiveUpgrade: Aktif upgrade bilgisini günceller.
  void patchActiveUpgrade(BuildingUpgradeModel? upgrade) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(activeUpgrade: upgrade));
  }

  /// patchStoreWarehouse: Mağaza deposunu günceller.
  void patchStoreWarehouse(StoreWarehouseSummaryModel? warehouse) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(storeWarehouse: warehouse));
  }

  /// patchStoreLevel: Mağaza seviyesini günceller (liste + detay).
  void patchStoreLevel(int level) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(store: current.store.copyWith(level: level)),
    );
  }

  /// addSlot: Yeni bir mağaza slotu ekler.
  void addSlot(StoreSlotModel slot) {
    final current = state.value;
    if (current == null) return;
    final updatedSlots = [...current.store.slots, slot];
    state = AsyncData(
      current.copyWith(store: current.store.copyWith(slots: updatedSlots)),
    );
  }

  /// replaceSlot: Slot'u tamamen değiştirir.
  void replaceSlot(StoreSlotModel slot) {
    _patchStoreSlot(
      slotId: slot.id,
      patcher: (_) => slot,
    );
  }

  /// patchSlotQuantity: Slot miktarını günceller.
  void patchSlotQuantity({required String slotId, required int quantity}) {
    _patchStoreSlot(
      slotId: slotId,
      patcher: (slot) => slot.copyWith(quantity: quantity),
    );
  }

  /// bulkPatchSlotPrices: Toplu kâr marjı sonrasında slot fiyatlarını günceller.
  void bulkPatchSlotPrices(List<dynamic> updatedSlots) {
    final current = state.value;
    if (current == null) return;
    final priceMap = <String, double>{};
    for (final item in updatedSlots) {
      if (item is Map) {
        final id = (item['slot_id'] ?? item['id'])?.toString();
        final price = (item['price'] as num?)?.toDouble();
        if (id != null && price != null) {
          priceMap[id] = price;
        }
      }
    }
    if (priceMap.isEmpty) return;
    final updatedSlotsList = current.store.slots.map((slot) {
      if (priceMap.containsKey(slot.id)) {
        return slot.copyWith(price: priceMap[slot.id]);
      }
      return slot;
    }).toList();
    state = AsyncData(
      current.copyWith(store: current.store.copyWith(slots: updatedSlotsList)),
    );
  }

  /// bulkPatchSlotQuantities: Rafları doldurma sonrası slot stok ve maliyetlerini günceller.
  void bulkPatchSlotQuantities(List<dynamic> updatedStoreSlots) {
    final current = state.value;
    if (current == null) return;
    final qtyMap = <String, Map<String, dynamic>>{};
    for (final item in updatedStoreSlots) {
      if (item is Map) {
        final id = item['id']?.toString();
        if (id != null) {
          qtyMap[id] = Map<String, dynamic>.from(item);
        }
      }
    }
    if (qtyMap.isEmpty) return;
    final updatedSlotsList = current.store.slots.map((slot) {
      if (qtyMap.containsKey(slot.id)) {
        final data = qtyMap[slot.id]!;
        final qty = (data['quantity'] as num?)?.toInt() ?? slot.quantity;
        final cost = (data['cost'] as num?)?.toDouble() ?? slot.cost;
        return slot.copyWith(quantity: qty, cost: cost);
      }
      return slot;
    }).toList();
    state = AsyncData(
      current.copyWith(store: current.store.copyWith(slots: updatedSlotsList)),
    );
  }

  /// bulkPatchStoreWarehouseSlots: Mağaza deposu slot stoklarını günceller.
  void bulkPatchStoreWarehouseSlots(List<dynamic> updatedWarehouseSlots) {
    final current = state.value;
    if (current == null || current.storeWarehouse == null) return;
    final qtyMap = <String, int>{};
    for (final item in updatedWarehouseSlots) {
      if (item is Map) {
        final id = item['id']?.toString();
        final qty = (item['quantity'] as num?)?.toInt();
        if (id != null && qty != null) {
          qtyMap[id] = qty;
        }
      }
    }
    if (qtyMap.isEmpty) return;
    final updatedSlotsList = current.storeWarehouse!.slots.map((slot) {
      if (qtyMap.containsKey(slot.id)) {
        return slot.copyWith(quantity: qtyMap[slot.id]!);
      }
      return slot;
    }).where((slot) => slot.quantity > 0).toList();
    state = AsyncData(current.copyWith(
      storeWarehouse: current.storeWarehouse!.copyWith(slots: updatedSlotsList),
    ));
  }

  /// patchStoreWarehouseSlotQuantity: Tekil mağaza deposu slot miktarını günceller.
  void patchStoreWarehouseSlotQuantity({
    required String warehouseSlotId,
    required int quantity,
  }) {
    final current = state.value;
    if (current == null || current.storeWarehouse == null) return;
    final updatedSlotsList = current.storeWarehouse!.slots.map((slot) {
      if (slot.id == warehouseSlotId) {
        return slot.copyWith(quantity: quantity);
      }
      return slot;
    }).where((slot) => slot.quantity > 0).toList();
    state = AsyncData(current.copyWith(
      storeWarehouse: current.storeWarehouse!.copyWith(slots: updatedSlotsList),
    ));
  }

  /// applyMutation: Ham RPC response map'ini uygular.
  /// Player ve common dirty flagleri MutationSyncService üzerinden sync eder.
  void applyMutation(Map<String, dynamic> response) {
    ref.read(mutationSyncServiceProvider).applyRaw(response);
  }
}

final storeDetailPageProvider = AsyncNotifierProvider.family<
    StoreDetailPageNotifier,
    StoreDetailPageModel,
    String
  >(StoreDetailPageNotifier.new);

final storePerformanceProvider =
    FutureProvider.family<StorePerformanceResponseModel, String>((
      ref,
      storeId,
    ) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Kullanıcı girişi yapılmamış.');
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
        throw Exception(model.message ?? 'Mağaza performansı alınamadı.');
      }

      return model;
    });

final storeHistoryProvider =
    FutureProvider.family<List<StoreHistoryItemModel>, String>((ref, storeId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Kullanıcı girişi yapılmamış.');
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
          productName: (json['product_name'] ?? 'Ürün').toString(),
          quantity: (json['quantity'] as num?)?.toInt() ?? 0,
          amount: (json['amount'] as num?)?.toDouble() ?? 0,
          secondaryAmount: (json['secondary_amount'] as num?)?.toDouble(),
          qualityLevel: (json['quality_level'] as num?)?.toInt(),
          status: (json['status'] ?? 'completed').toString(),
        );
      }).toList();
    });

final citiesProvider = FutureProvider<List<CityModel>>((ref) async {
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.cities;
});

final storeTypesProvider = FutureProvider<List<StoreTypeModel>>((ref) async {
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.storeTypes;
});

class StoreActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TransferVehicleOptionsService _vehicleOptionsService =
      TransferVehicleOptionsService();

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

  Future<Map<String, dynamic>> reduceConstructionTimeWithAd(
    String constructionId,
  ) async {
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
      await tryCompleteDueBuildingUpgrades(_supabase);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message, 'code': e.code};
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

  Future<Map<String, dynamic>> reduceStoreUpgradeTimeWithAd(
    String upgradeId,
  ) async {
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

  Future<Map<String, dynamic>> startStoreBoostWithAdReward({
    required String storeId,
    int durationMinutes = 30,
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
          'p_building_kind': 'store',
          'p_entity_id': storeId,
          'p_duration_minutes': durationMinutes,
        },
      );
      return Map<String, dynamic>.from(response as Map);
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
    String? productId,
    int qualityLevel = 1,
    String? sourceWarehouseSlotId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      if (sourceWarehouseSlotId == null || sourceWarehouseSlotId.isEmpty) {
        return {
          'success': false,
          'message':
              'Mağaza slotu ürünü sadece mağazaya bağlı depo slotundan seçilebilir.',
        };
      }

      final response = await _supabase.rpc(
        'set_store_slot_product_from_warehouse_slot',
        params: {
          'p_player_id': user.id,
          'p_store_slot_id': slotId,
          'p_warehouse_slot_id': sourceWarehouseSlotId,
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

  Future<Map<String, dynamic>> bulkSetStoreSlotPrices({
    required List<Map<String, dynamic>> updates,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum açılmamış.'};
    }

    int successCount = 0;
    String? lastError;

    for (final item in updates) {
      final String slotId = item['slotId'] as String;
      final double price = (item['price'] as num).toDouble();
      try {
        final response = await _supabase.rpc(
          'set_store_slot_price',
          params: {
            'p_player_id': user.id,
            'p_store_slot_id': slotId,
            'p_price': price,
          },
        );
        final Map<String, dynamic> res =
            Map<String, dynamic>.from(response as Map);
        if (res['success'] == true) {
          successCount++;
        } else if (res['message'] != null) {
          lastError = res['message'].toString();
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    return {
      'success': successCount > 0,
      'updatedCount': successCount,
      'message': successCount > 0
          ? '$successCount reyon fiyatı güncellendi.'
          : (lastError ?? 'Fiyatlar güncellenemedi.'),
    };
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

  Future<Map<String, dynamic>> setStoreActive({
    required String storeId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_store_active',
        params: {
          'p_store_id': storeId,
          'p_is_active': isActive,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sellStore({
    required String storeId,
    required bool confirm,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'sell_store',
        params: {
          'p_store_id': storeId,
          'p_confirm': confirm,
        },
      );
      return Map<String, dynamic>.from(response as Map);
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

  Future<Map<String, dynamic>> transferStoreWarehouseStockToSlot({
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
        'transfer_store_warehouse_slot_to_store_slot',
        params: {
          'p_player_id': user.id,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_store_slot_id': storeSlotId,
          'p_quantity': quantity,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>>
      getStoreTransferVehicleOptions({
    required String sourceCityId,
    required String targetCityId,
    required double totalVolume,
  }) async {
    final response = await _vehicleOptionsService.getRouteOptions(
      RouteTransferVehicleOptionsRequest(
        sourceCityId: sourceCityId,
        targetCityId: targetCityId,
        totalVolume: totalVolume,
      ),
    );

    return mapTransferVehicleOptions(
      rows: response,
      mapper: MarketTransferVehicleOptionModel.fromJson,
    );
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
    required String sourceWarehouseId,
    required String storeId,
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
        'start_multi_logistics_transfer',
        params: {
          'p_source_entity_kind': 'warehouse',
          'p_source_entity_id': sourceWarehouseId,
          'p_target_entity_kind': 'store',
          'p_target_entity_id': storeId,
          'p_items': [
            {
              'source_warehouse_slot_id': warehouseSlotId,
              'quantity': quantity,
            },
          ],
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>>
      getStoreToWarehouseVehicleOptions({
    required String sourceCityId,
    required String targetCityId,
    required double totalVolume,
  }) async {
    final response = await _vehicleOptionsService.getRouteOptions(
      RouteTransferVehicleOptionsRequest(
        sourceCityId: sourceCityId,
        targetCityId: targetCityId,
        totalVolume: totalVolume,
      ),
    );

    return mapTransferVehicleOptions(
      rows: response,
      mapper: MarketTransferVehicleOptionModel.fromJson,
    );
  }

  Future<Map<String, dynamic>> startStoreToWarehouseTransfer({
    required String storeId,
    required String sourceWarehouseSlotId,
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
        'start_multi_logistics_transfer',
        params: {
          'p_source_entity_kind': 'store',
          'p_source_entity_id': storeId,
          'p_target_entity_kind': 'warehouse',
          'p_target_entity_id': warehouseId,
          'p_items': [
            {
              'source_warehouse_slot_id': sourceWarehouseSlotId,
              'quantity': quantity,
            },
          ],
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> returnStoreSlotStockToStoreWarehouse({
    required String storeSlotId,
    required int quantity,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'transfer_store_slot_to_store_warehouse',
        params: {
          'p_player_id': user.id,
          'p_store_slot_id': storeSlotId,
          'p_quantity': quantity,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fillStoreShelves({
    required String storeId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'fill_store_shelves',
        params: {
          'p_player_id': user.id,
          'p_store_id': storeId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> bulkUpdateStoreSlotPrices({
    required String storeId,
    required int markupPercent,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'bulk_update_store_slot_prices',
        params: {
          'p_player_id': user.id,
          'p_store_id': storeId,
          'p_markup_percent': markupPercent,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

}

final storeActionProvider = Provider((ref) => StoreActionNotifier());
