import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_guard_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/data/production_entry_service.dart';
import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_list_item_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';

Future<List<FieldListItemModel>> _fetchFieldList() async {
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
      cityName: (map['city_name'] ?? 'Bilinmeyen Şehir').toString(),
      fieldTypeName:
          (map['field_type_name'] ?? 'Bilinmeyen Çiftlik').toString(),
      fieldTypeIcon: (map['field_type_icon'] ?? 'field.webp').toString(),
      outputStockQuantity:
          (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
      inputStockQuantity:
          (map['input_stock_quantity'] as num?)?.toInt() ?? 0,
      slots: (map['slots'] as List<dynamic>? ?? const [])
          .map(
            (slot) => FieldSlotPreviewModel.fromJson(
              Map<String, dynamic>.from(slot as Map),
            ),
          )
          .toList(),
    );
  }).toList();
}

class FieldListNotifier extends AsyncNotifier<List<FieldListItemModel>> {
  @override
  Future<List<FieldListItemModel>> build() => _fetchFieldList();

  Future<List<FieldListItemModel>> refresh() async {
    final list = await _fetchFieldList();
    state = AsyncData(list);
    return list;
  }

  void patchFieldLevelAndCapacity({
    required String fieldId,
    required int level,
    required int outputCapacity,
    int? inputCapacity,
  }) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;
    final item = current[index];
    final updatedField = item.field.copyWith(
      level: level,
      outputCapacity: outputCapacity,
      inputCapacity: inputCapacity ?? item.field.inputCapacity,
    );
    final next = [...current];
    next[index] = item.copyWith(field: updatedField);
    state = AsyncData(next);
  }

  void patchSlotActive({
    required String fieldId,
    required String slotId,
    required bool isActive,
  }) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;
    final item = current[index];
    final updatedSlots = item.slots.map((s) {
      if (s.id == slotId) {
        return FieldSlotPreviewModel(
          id: s.id,
          slotIndex: s.slotIndex,
          isActive: isActive,
          productId: s.productId,
          product: s.product,
        );
      }
      return s;
    }).toList();
    final next = [...current];
    next[index] = item.copyWith(slots: updatedSlots);
    state = AsyncData(next);
  }

  void addSlot({
    required String fieldId,
    required FieldSlotPreviewModel slot,
  }) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;
    final item = current[index];
    final updatedSlots = [...item.slots, slot];
    final next = [...current];
    next[index] = item.copyWith(
      field: item.field.copyWith(
        currentSlotCount: item.field.currentSlotCount + 1,
      ),
      slots: updatedSlots,
    );
    state = AsyncData(next);
  }

  void removeField(String fieldId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((item) => item.field.id != fieldId).toList());
  }

  void patchSlotProduct({
    required String fieldId,
    required String slotId,
    required String? productId,
    ProductModel? product,
  }) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((item) => item.field.id == fieldId);
    if (index < 0) return;
    final item = current[index];
    final updatedSlots = item.slots.map((s) {
      if (s.id == slotId) {
        return FieldSlotPreviewModel(
          id: s.id,
          slotIndex: s.slotIndex,
          isActive: s.isActive,
          productId: productId,
          product: product,
        );
      }
      return s;
    }).toList();
    final next = [...current];
    next[index] = item.copyWith(slots: updatedSlots);
    state = AsyncData(next);
  }
}

final fieldListProvider =
    AsyncNotifierProvider<FieldListNotifier, List<FieldListItemModel>>(
      FieldListNotifier.new,
    );

final fieldTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.fieldTypes;
});

Future<Map<String, dynamic>?> _fetchFieldConstruction() async {
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

  final rows = response as List<dynamic>? ?? const [];
  if (rows.isEmpty) return null;
  return Map<String, dynamic>.from(rows.first as Map);
}

class FieldConstructionNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() => _fetchFieldConstruction();

  Future<Map<String, dynamic>?> refresh() async {
    final data = await _fetchFieldConstruction();
    state = AsyncData(data);
    return data;
  }

  void setConstruction(Map<String, dynamic>? data) {
    state = AsyncData(data);
  }

  void patchFinishAt(DateTime newFinishAt) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData({
      ...current,
      'finish_at': newFinishAt.toIso8601String(),
    });
  }

  void clear() {
    state = const AsyncData(null);
  }
}

final fieldConstructionProvider =
    AsyncNotifierProvider<FieldConstructionNotifier, Map<String, dynamic>?>(
      FieldConstructionNotifier.new,
    );

Future<FieldDetailModel> _fetchFieldDetail(String fieldId) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanıcı girişi yapılmamış.');
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
    cityName: (map['city_name'] ?? 'Bilinmeyen Şehir').toString(),
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
}

class FieldDetailNotifier extends AsyncNotifier<FieldDetailModel> {
  FieldDetailNotifier(this._fieldId);

  final String _fieldId;

  @override
  Future<FieldDetailModel> build() => _fetchFieldDetail(_fieldId);

  Future<FieldDetailModel> refresh() async {
    final detail = await _fetchFieldDetail(_fieldId);
    state = AsyncData(detail);
    return detail;
  }

  void patchFieldLevelAndCapacity({
    required int level,
    required int outputCapacity,
    int? inputCapacity,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        field: current.field.copyWith(
          level: level,
          outputCapacity: outputCapacity,
          inputCapacity: inputCapacity ?? current.field.inputCapacity,
        ),
      ),
    );
  }

  void patchSlotActive({
    required String slotId,
    required bool isActive,
  }) {
    final current = state.value;
    if (current == null) return;
    final updatedSlots = current.slots.map((slot) {
      if (slot.id == slotId) {
        return slot.copyWith(isActive: isActive);
      }
      return slot;
    }).toList();
    state = AsyncData(current.copyWith(slots: updatedSlots));
  }

  void addSlot(ProductionSlotModel slot) {
    final current = state.value;
    if (current == null) return;
    final updatedSlots = [...current.slots, slot];
    state = AsyncData(
      current.copyWith(
        field: current.field.copyWith(
          currentSlotCount: current.field.currentSlotCount + 1,
        ),
        slots: updatedSlots,
      ),
    );
  }

  void patchSlotsAndInventories({
    required List<ProductionSlotModel> slots,
    required List<ProductionInventoryModel> inventories,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        slots: slots,
        inventories: inventories,
      ),
    );
  }
}

final fieldDetailProvider = AsyncNotifierProvider.family<
    FieldDetailNotifier,
    FieldDetailModel,
    String
>(FieldDetailNotifier.new);

class ActiveFieldUpgradeNotifier extends AsyncNotifier<BuildingUpgradeModel?> {
  ActiveFieldUpgradeNotifier(this._fieldId);

  final String _fieldId;

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
        'p_building_kind': 'field',
        'p_entity_id': _fieldId,
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

final activeFieldUpgradeProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveFieldUpgradeNotifier, BuildingUpgradeModel?, String>(
      ActiveFieldUpgradeNotifier.new,
    );

class ActiveFieldBoostNotifier extends AsyncNotifier<BuildingBoostModel?> {
  ActiveFieldBoostNotifier(this._fieldId);

  final String _fieldId;

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
        'p_building_kind': 'field',
        'p_entity_id': _fieldId,
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

final activeFieldBoostProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveFieldBoostNotifier, BuildingBoostModel?, String>(
      ActiveFieldBoostNotifier.new,
    );

class FieldActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

  FieldActionNotifier(this._ref);

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
  }

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
      return _sync(response);
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
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        _ref.invalidate(fieldConstructionProvider);
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
        _ref.invalidate(fieldListProvider);
        _ref.invalidate(fieldConstructionProvider);
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
        _ref.invalidate(fieldConstructionProvider);
      }
      return result;
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
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeFieldUpgradeProvider(fieldId));
        _ref.invalidate(fieldDetailProvider(fieldId));
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
      _ref.invalidate(fieldListProvider);
      _ref.invalidate(fieldDetailProvider);
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
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(fieldListProvider);
        final entityId = result['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(fieldDetailProvider(entityId));
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceFieldUpgradeTimeWithAd(
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
        _ref.invalidate(fieldListProvider);
        final entityId = result['entity_id']?.toString();
        if (entityId != null && entityId.isNotEmpty) {
          _ref.invalidate(fieldDetailProvider(entityId));
        }
      }
      return result;
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
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeFieldBoostProvider(fieldId));
        _ref.invalidate(fieldDetailProvider(fieldId));
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startFieldBoostWithAdReward({
    required String fieldId,
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
          'p_building_kind': 'field',
          'p_entity_id': fieldId,
          'p_duration_minutes': durationMinutes,
        },
      );
      final result = _sync(response);
      if (syncProviders) {
        _ref.invalidate(activeFieldBoostProvider(fieldId));
        _ref.invalidate(fieldDetailProvider(fieldId));
      }
      return result;
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
      final result = _sync(response);
      if (syncProviders && result['success'] == true) {
        final slotJson = result['slot'];
        if (slotJson is Map) {
          final slotModel = ProductionSlotModel.fromJson(
            Map<String, dynamic>.from(slotJson),
          );
          _ref.read(fieldDetailProvider(fieldId).notifier).addSlot(slotModel);
          _ref.read(fieldListProvider.notifier).addSlot(
            fieldId: fieldId,
            slot: FieldSlotPreviewModel(
              id: slotModel.id,
              slotIndex: slotModel.slotIndex,
              isActive: slotModel.isActive,
              productId: slotModel.productId,
              product: slotModel.product,
            ),
          );
        } else {
          _ref.invalidate(fieldListProvider);
          _ref.invalidate(fieldDetailProvider(fieldId));
        }
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
      _sync(responseMap);
      if (syncProviders && responseMap['success'] == true) {
        final ownerId = (responseMap['owner_id'] ?? '').toString();
        final slotsJson = responseMap['slots'] as List<dynamic>?;
        final inventoriesJson = responseMap['inventories'] as List<dynamic>?;

        if (ownerId.isNotEmpty && slotsJson != null && inventoriesJson != null) {
          final parsedSlots = slotsJson
              .map((s) => ProductionSlotModel.fromJson(
                    Map<String, dynamic>.from(s as Map),
                  ))
              .toList();
          final parsedInventories = inventoriesJson
              .map((i) => ProductionInventoryModel.fromJson(
                    Map<String, dynamic>.from(i as Map),
                  ))
              .toList();
          _ref.read(fieldDetailProvider(ownerId).notifier).patchSlotsAndInventories(
            slots: parsedSlots,
            inventories: parsedInventories,
          );

          if (parsedSlots.isNotEmpty) {
            final updatedSlot = parsedSlots.cast<ProductionSlotModel?>().firstWhere(
              (s) => s?.id == slotId,
              orElse: () => parsedSlots.first,
            );
            _ref.read(fieldListProvider.notifier).patchSlotProduct(
              fieldId: ownerId,
              slotId: slotId,
              productId: productId,
              product: updatedSlot?.product,
            );
          }
        } else {
          _ref.invalidate(fieldListProvider);
          if (ownerId.isNotEmpty) {
            _ref.invalidate(fieldDetailProvider(ownerId));
          }
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
      _sync(responseMap);
      if (syncProviders && responseMap['success'] == true) {
        final ownerId = (responseMap['owner_id'] ?? '').toString();
        final slotsJson = responseMap['slots'] as List<dynamic>?;
        final inventoriesJson = responseMap['inventories'] as List<dynamic>?;

        if (ownerId.isNotEmpty && slotsJson != null && inventoriesJson != null) {
          final parsedSlots = slotsJson
              .map((s) => ProductionSlotModel.fromJson(
                    Map<String, dynamic>.from(s as Map),
                  ))
              .toList();
          final parsedInventories = inventoriesJson
              .map((i) => ProductionInventoryModel.fromJson(
                    Map<String, dynamic>.from(i as Map),
                  ))
              .toList();
          _ref.read(fieldDetailProvider(ownerId).notifier).patchSlotsAndInventories(
            slots: parsedSlots,
            inventories: parsedInventories,
          );

          if (parsedSlots.isNotEmpty) {
            final updatedSlot = parsedSlots.cast<ProductionSlotModel?>().firstWhere(
              (s) => s?.id == slotId,
              orElse: () => parsedSlots.first,
            );
            _ref.read(fieldListProvider.notifier).patchSlotProduct(
              fieldId: ownerId,
              slotId: slotId,
              productId: productId,
              product: updatedSlot?.product,
            );
          }
        } else {
          _ref.invalidate(fieldListProvider);
          if (ownerId.isNotEmpty) {
            _ref.invalidate(fieldDetailProvider(ownerId));
          }
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
      _sync(responseMap);
      if (syncProviders && responseMap['success'] == true) {
        final ownerId = (responseMap['owner_id'] ?? '').toString();
        if (ownerId.isNotEmpty) {
          _ref.read(fieldDetailProvider(ownerId).notifier).patchSlotActive(
            slotId: slotId,
            isActive: isActive,
          );
          _ref.read(fieldListProvider.notifier).patchSlotActive(
            fieldId: ownerId,
            slotId: slotId,
            isActive: isActive,
          );
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
      _ref.invalidate(fieldDetailProvider);
      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(warehouseDetailProvider(sourceWarehouseId));
      await _refreshAttentionNotifications();
    }
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
      _ref.invalidate(fieldDetailProvider);
      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(warehouseDetailProvider(buyerWarehouseId));
    }
    return result;
  }

  Future<Map<String, dynamic>> sellField({
    required String fieldId,
    required bool confirm,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'sell_building',
        params: {
          'p_building_id': fieldId,
          'p_building_kind': 'field',
          'p_confirm': confirm,
        },
      );
      final result = _sync(response);
      if (confirm && syncProviders && result['success'] == true) {
        _ref.invalidate(fieldListProvider);
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final fieldActionProvider = Provider((ref) => FieldActionNotifier(ref));
