import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/data/production_entry_service.dart';
import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_list_item_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';

// ─── Fetch helpers ────────────────────────────────────────────────────────────

Future<List<FactoryListItemModel>> _fetchFactoryList() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return const [];

  await processProductionEntry(supabase: supabase, ownerKind: 'factory');

  final response = await supabase.rpc('get_factory_list_items');
  final rows = response as List<dynamic>;

  return rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    return FactoryListItemModel(
      factory: FactoryModel.fromJson(
        Map<String, dynamic>.from(map['factory'] as Map),
      ),
      cityName: (map['city_name'] ?? 'Bilinmeyen Şehir').toString(),
      factoryTypeName: (map['factory_type_name'] ?? 'Bilinmeyen Fabrika')
          .toString(),
      factoryTypeIcon: (map['factory_type_icon'] ?? 'factory.webp').toString(),
      inputStockQuantity: (map['input_stock_quantity'] as num?)?.toInt() ?? 0,
      outputStockQuantity: (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
      selectedProduct: map['selected_product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['selected_product'] as Map),
            ),
      productionSlots: (map['production_slots'] as List<dynamic>? ?? const [])
          .map(
            (row) => ProductionSlotContractModel.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
    );
  }).toList();
}

Future<FactoryDetailModel> _fetchFactoryDetail(
  String factoryId, [
  Ref? ref,
]) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');

  final result = await processProductionEntry(
    supabase: supabase,
    ownerKind: 'factory',
    ownerId: factoryId,
  );
  if (ref != null && result.isNotEmpty) {
    ref.read(mutationSyncServiceProvider).applyRaw(result);
  }

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
    cityName: (map['city_name'] ?? 'Bilinmeyen Şehir').toString(),
    product: map['product'] == null
        ? null
        : ProductModel.fromJson(
            Map<String, dynamic>.from(map['product'] as Map),
          ),
    productionSlots: (map['production_slots'] as List<dynamic>? ?? const [])
        .map(
          (row) => ProductionSlotContractModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(),
    inventories: (map['inventories'] as List<dynamic>? ?? const [])
        .map(
          (row) => FactoryProductionInventoryModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(),
  );
}

// ─── FactoryListNotifier ──────────────────────────────────────────────────────

class FactoryListNotifier extends AsyncNotifier<List<FactoryListItemModel>> {
  @override
  Future<List<FactoryListItemModel>> build() => _fetchFactoryList();

  Future<List<FactoryListItemModel>> refresh() async {
    final list = await _fetchFactoryList();
    state = AsyncData(list);
    return list;
  }

  void addFactory(FactoryListItemModel item) {
    final current = state.value ?? const [];
    state = AsyncData([...current, item]);
  }

  void removeFactory(String factoryId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((f) => f.factory.id != factoryId).toList());
  }

  void replaceFactory(FactoryListItemModel item) {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((f) => f.factory.id == item.factory.id);
    if (idx < 0) return;
    final next = [...current];
    next[idx] = item;
    state = AsyncData(next);
  }

  void patchFactoryActive({required String factoryId, required bool isActive}) {
    _patchFactory(
      factoryId: factoryId,
      patcher: (item) =>
          item.copyWith(factory: item.factory.copyWith(isActive: isActive)),
    );
  }

  void patchFactoryLevel({required String factoryId, required int level}) {
    _patchFactory(
      factoryId: factoryId,
      patcher: (item) =>
          item.copyWith(factory: item.factory.copyWith(level: level)),
    );
  }

  void patchFactoryProduct({
    required String factoryId,
    required String? productId,
    ProductModel? product,
  }) {
    _patchFactory(
      factoryId: factoryId,
      patcher: (item) => item.copyWith(
        factory: item.factory.copyWith(productId: productId),
        selectedProduct: product,
      ),
    );
  }

  void patchFactorySpecs({
    required String factoryId,
    int? level,
    int? inputCapacity,
    int? outputCapacity,
    double? boostMultiplier,
  }) {
    _patchFactory(
      factoryId: factoryId,
      patcher: (item) => item.copyWith(
        factory: item.factory.copyWith(
          level: level ?? item.factory.level,
          inputCapacity: inputCapacity ?? item.factory.inputCapacity,
          outputCapacity: outputCapacity ?? item.factory.outputCapacity,
          boostMultiplier: boostMultiplier ?? item.factory.boostMultiplier,
        ),
      ),
    );
  }

  void patchFactoryConfig({
    required String factoryId,
    String? productId,
    int? qualityLevel,
    String? brandId,
    ProductModel? product,
  }) {
    _patchFactory(
      factoryId: factoryId,
      patcher: (item) {
        final newProductId = productId ?? item.factory.productId;
        final isProductChanged =
            productId != null && productId != item.factory.productId;
        return item.copyWith(
          factory: item.factory.copyWith(
            productId: newProductId,
            qualityLevel: qualityLevel ?? item.factory.qualityLevel,
            brandId: brandId ?? item.factory.brandId,
          ),
          selectedProduct:
              product ?? (isProductChanged ? null : item.selectedProduct),
        );
      },
    );
  }

  void _patchFactory({
    required String factoryId,
    required FactoryListItemModel Function(FactoryListItemModel) patcher,
  }) {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((f) => f.factory.id == factoryId);
    if (idx < 0) return;
    final next = [...current];
    next[idx] = patcher(next[idx]);
    state = AsyncData(next);
  }
}

final factoryListProvider =
    AsyncNotifierProvider<FactoryListNotifier, List<FactoryListItemModel>>(
      FactoryListNotifier.new,
    );

// ─── FactoryDetailNotifier ────────────────────────────────────────────────────

class FactoryDetailNotifier extends AsyncNotifier<FactoryDetailModel> {
  FactoryDetailNotifier(this._factoryId);

  final String _factoryId;
  static final Set<String> activeFactoryIds = {};

  @override
  Future<FactoryDetailModel> build() {
    ref.onDispose(() {
      activeFactoryIds.remove(_factoryId);
    });
    activeFactoryIds.add(_factoryId);
    return _fetchFactoryDetail(_factoryId, ref);
  }

  Future<FactoryDetailModel> refresh() async {
    final detail = await _fetchFactoryDetail(_factoryId, ref);
    state = AsyncData(detail);
    return detail;
  }

  void replaceFactory(FactoryModel factory) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(factory: factory));
  }

  void patchFactoryActive(bool isActive) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(factory: current.factory.copyWith(isActive: isActive)),
    );
  }

  void patchFactoryLevel(int level) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(factory: current.factory.copyWith(level: level)),
    );
  }

  void patchFactorySpecs({
    int? level,
    int? inputCapacity,
    int? outputCapacity,
    double? boostMultiplier,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        factory: current.factory.copyWith(
          level: level ?? current.factory.level,
          inputCapacity: inputCapacity ?? current.factory.inputCapacity,
          outputCapacity: outputCapacity ?? current.factory.outputCapacity,
          boostMultiplier: boostMultiplier ?? current.factory.boostMultiplier,
        ),
      ),
    );
  }

  void patchFactoryProduct({
    required String? productId,
    ProductModel? product,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        factory: current.factory.copyWith(productId: productId),
        product: product,
      ),
    );
  }

  void patchFactoryConfig({
    String? productId,
    int? qualityLevel,
    String? brandId,
    ProductModel? product,
  }) {
    final current = state.value;
    if (current == null) return;
    final updatedFactory = current.factory.copyWith(
      productId: productId ?? current.factory.productId,
      qualityLevel: qualityLevel ?? current.factory.qualityLevel,
      brandId: brandId ?? current.factory.brandId,
    );
    final isProductChanged =
        productId != null && productId != current.factory.productId;
    state = AsyncData(
      current.copyWith(
        factory: updatedFactory,
        product: product ?? (isProductChanged ? null : current.product),
      ),
    );
  }

  void insertInventory(FactoryProductionInventoryModel item) {
    final current = state.value;
    if (current == null) return;
    final updated = [
      ...current.inventories.where((i) => i.id != item.id),
      item,
    ];
    state = AsyncData(current.copyWith(inventories: updated));
  }

  void patchInventoryChanges({
    required String id,
    required Map<String, dynamic> changes,
    ProductModel? resolvedProduct,
  }) {
    final current = state.value;
    if (current == null) return;
    final updated = current.inventories.map((inv) {
      if (inv.id != id) return inv;
      final newProdId = changes['product_id']?.toString() ?? inv.productId;
      final productObj =
          resolvedProduct ?? (newProdId == inv.productId ? inv.product : null);
      return inv.copyWith(
        productId: newProdId,
        qualityLevel:
            (changes['quality_level'] as num?)?.toInt() ?? inv.qualityLevel,
        brandId: changes['brand_id']?.toString() ?? inv.brandId,
        quantity: (changes['quantity'] as num?)?.toInt() ?? inv.quantity,
        pendingQuantity:
            (changes['pending_quantity'] as num?)?.toDouble() ??
            inv.pendingQuantity,
        cost: (changes['cost'] as num?)?.toDouble() ?? inv.cost,
        product: productObj,
      );
    }).toList();
    state = AsyncData(current.copyWith(inventories: updated));
  }

  void removeInventory(String id) {
    final current = state.value;
    if (current == null) return;
    final updated = current.inventories.where((i) => i.id != id).toList();
    state = AsyncData(current.copyWith(inventories: updated));
  }

  void replaceInventory(List<FactoryProductionInventoryModel> inventories) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(inventories: inventories));
  }

  void patchInventoryQuantity({
    required String inventoryId,
    required int quantity,
  }) {
    final current = state.value;
    if (current == null) return;
    final updated = current.inventories.map((inv) {
      if (inv.id == inventoryId) {
        return inv.copyWith(quantity: quantity);
      }
      return inv;
    }).toList();
    state = AsyncData(current.copyWith(inventories: updated));
  }

  /// applyMutation: Player ve common dirty flagleri sync eder.
  void applyMutation(Map<String, dynamic> response) {
    ref.read(mutationSyncServiceProvider).applyRaw(response);
  }
}

final factoryDetailProvider =
    AsyncNotifierProvider.family<
      FactoryDetailNotifier,
      FactoryDetailModel,
      String
    >(FactoryDetailNotifier.new);

// ─── Fabrika Tipleri Provider ─────────────────────────────────────────────────

final factoryTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.factoryTypes;
});

// ─── Factory Construction Provider ───────────────────────────────────────────
// Fallback: construction verisi ayrı endpoint'ten geldiği için invalidate kullanılıyor.

Future<Map<String, dynamic>?> _fetchFactoryConstruction() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final response = await supabase.rpc(
    'get_player_building_constructions',
    params: {'p_building_kind': 'factory', 'p_status': 'in_progress'},
  );

  final rows = response as List<dynamic>? ?? const [];
  if (rows.isEmpty) return null;
  return Map<String, dynamic>.from(rows.first as Map);
}

class FactoryConstructionNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() => _fetchFactoryConstruction();

  Future<Map<String, dynamic>?> refresh() async {
    final data = await _fetchFactoryConstruction();
    state = AsyncData(data);
    return data;
  }

  void setConstruction(Map<String, dynamic>? data) {
    state = AsyncData(data);
  }

  void patchFinishAt(DateTime newFinishAt) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData({...current, 'finish_at': newFinishAt.toIso8601String()});
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final factoryConstructionProvider =
    AsyncNotifierProvider<FactoryConstructionNotifier, Map<String, dynamic>?>(
      FactoryConstructionNotifier.new,
    );

// ─── Active boost/upgrade providers ──────────────────────────────────────────

class ActiveFactoryUpgradeNotifier
    extends AsyncNotifier<BuildingUpgradeModel?> {
  ActiveFactoryUpgradeNotifier(this._factoryId);

  final String _factoryId;

  @override
  Future<BuildingUpgradeModel?> build() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) return null;

    final response = await supabase.rpc(
      'get_player_active_building_upgrade',
      params: {'p_building_kind': 'factory', 'p_entity_id': _factoryId},
    );

    if (response == null) return null;
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

final activeFactoryUpgradeProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveFactoryUpgradeNotifier, BuildingUpgradeModel?, String>(
      ActiveFactoryUpgradeNotifier.new,
    );

class ActiveFactoryBoostNotifier extends AsyncNotifier<BuildingBoostModel?> {
  ActiveFactoryBoostNotifier(this._factoryId);

  final String _factoryId;

  @override
  Future<BuildingBoostModel?> build() async {
    final supabase = Supabase.instance.client;
    if (supabase.auth.currentUser == null) return null;

    final response = await supabase.rpc(
      'get_player_active_building_boost',
      params: {'p_building_kind': 'factory', 'p_entity_id': _factoryId},
    );

    if (response == null) return null;
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

final activeFactoryBoostProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveFactoryBoostNotifier, BuildingBoostModel?, String>(
      ActiveFactoryBoostNotifier.new,
    );

// ─── FactoryActionNotifier ────────────────────────────────────────────────────

class FactoryActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  late final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService(ref: _ref);

  FactoryActionNotifier(this._ref);

  Map<String, dynamic> _sync(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

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
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishConstructionWithGold(
    String constructionId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'finish_construction_with_gold',
        params: {'p_player_id': user.id, 'p_construction_id': constructionId},
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceConstructionTimeWithAd(
    String constructionId, {
    int minutes = 30,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'reduce_construction_time_with_ad',
        params: {
          'p_player_id': user.id,
          'p_construction_id': constructionId,
          'p_minutes': minutes,
        },
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFactoryUpgrade(
    String factoryId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'start_building_upgrade',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'factory',
          'p_entity_id': factoryId,
        },
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> finishFactoryUpgradeWithGold(
    String upgradeId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'finish_building_upgrade_with_gold',
        params: {'p_player_id': user.id, 'p_upgrade_id': upgradeId},
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceFactoryUpgradeTimeWithAd(
    String upgradeId, {
    int minutes = 30,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'reduce_building_upgrade_time_with_ad',
        params: {
          'p_player_id': user.id,
          'p_upgrade_id': upgradeId,
          'p_minutes': minutes,
        },
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFactoryBoost({
    required String factoryId,
    required int durationHours,
    required int starCost,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

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
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFactoryBoostWithAdReward({
    required String factoryId,
    int durationMinutes = 30,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'start_building_boost_with_ad_reward',
        params: {
          'p_player_id': user.id,
          'p_building_kind': 'factory',
          'p_entity_id': factoryId,
          'p_duration_minutes': durationMinutes,
        },
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setFactoryProduct({
    required String factoryId,
    required String productId,
    required int qualityLevel,
    String? brandId,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'set_factory_product',
        params: {
          'p_player_id': user.id,
          'p_factory_id': factoryId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
          'p_brand_id': ?brandId,
        },
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setFactoryActive({
    required String factoryId,
    required bool isActive,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'set_factory_active',
        params: {'p_factory_id': factoryId, 'p_is_active': isActive},
      );
      final result = _sync(response);
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
      final slots =
          ((warehouseMap['warehouse_slots'] as List<dynamic>?) ?? const [])
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
        eligible.add({...warehouseMap, 'warehouse_slots': slots});
      }
    }

    return eligible;
  }

  Future<List<Map<String, dynamic>>>
  getEligibleWarehouseSlotsForInventoryAllCities({
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
      final slots =
          ((warehouseMap['warehouse_slots'] as List<dynamic>?) ?? const [])
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
        eligible.add({...warehouseMap, 'warehouse_slots': slots});
      }
    }

    return eligible;
  }

  Future<List<Map<String, dynamic>>> getPlayerWarehousesByCity(
    String cityId,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum acilmamis.');

    final response = await _supabase.rpc('get_player_active_warehouses_basic');

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

  Future<ProductionLogisticsStartResult>
  startMultiWarehouseToProductionTransfer({
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
    return result;
  }

  Future<ProductionLogisticsStartResult>
  startMultiProductionToWarehouseTransfer({
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
    return result;
  }

  Future<Map<String, dynamic>> sellFactory({
    required String factoryId,
    required bool confirm,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'sell_building',
        params: {
          'p_building_id': factoryId,
          'p_building_kind': 'factory',
          'p_confirm': confirm,
        },
      );
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final factoryActionProvider = Provider((ref) => FactoryActionNotifier(ref));
