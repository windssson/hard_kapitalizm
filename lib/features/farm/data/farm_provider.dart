import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_list_item_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';

final farmListStreamProvider =
    FutureProvider.autoDispose<List<FarmListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  final farmsResponse = await supabase
      .from('farms')
      .select()
      .eq('player_id', user.id)
      .order('created_at', ascending: true);

  final farms = (farmsResponse as List<dynamic>)
      .map((e) => FarmModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  if (farms.isEmpty) return const [];

  final farmTypeIds = farms.map((e) => e.farmTypeId).toSet().toList();
  final cityIds = farms.map((e) => e.cityId).toSet().toList();
  final farmIds = farms.map((e) => e.id).toList();

  final farmTypesResponse = await supabase
      .from('farm_types')
      .select('id, name, icon')
      .inFilter('id', farmTypeIds);
  final citiesResponse = await supabase
      .from('cities')
      .select('id, name')
      .inFilter('id', cityIds);
  final slotsResponse = await supabase
      .from('production_slots')
      .select('id, owner_id, slot_index, product_id, is_active')
      .eq('owner_kind', 'farm')
      .inFilter('owner_id', farmIds)
      .order('slot_index', ascending: true);
  final outputInventoriesResponse = await supabase
      .from('production_inventory')
      .select('owner_id, quantity')
      .eq('owner_kind', 'farm')
      .eq('inventory_type', 'output')
      .inFilter('owner_id', farmIds);

  final slotRows = (slotsResponse as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final productIds = slotRows
      .map((e) => e['product_id']?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  Map<String, ProductModel> productsById = const {};
  if (productIds.isNotEmpty) {
    final productsResponse = await supabase
        .from('products')
        .select('id, urun_adi, urun_iconu')
        .inFilter('id', productIds);
    productsById = {
      for (final row in productsResponse as List<dynamic>)
        (row['id'] ?? '').toString(): ProductModel.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
    };
  }

  final farmTypeById = {
    for (final row in farmTypesResponse as List<dynamic>)
      (row['id'] ?? '').toString(): Map<String, dynamic>.from(row as Map),
  };
  final cityNameById = {
    for (final row in citiesResponse as List<dynamic>)
      (row['id'] ?? '').toString(): (row['name'] ?? 'Bilinmeyen Sehir').toString(),
  };

  final slotsByFarmId = <String, List<FarmSlotPreviewModel>>{};
  for (final row in slotRows) {
    final ownerId = (row['owner_id'] ?? '').toString();
    final productId = row['product_id']?.toString();
    final slot = FarmSlotPreviewModel.fromJson({
      ...row,
      'product': productId != null ? productsById[productId]?.toJson() : null,
    });
    slotsByFarmId.putIfAbsent(ownerId, () => []).add(slot);
  }

  final outputByFarmId = <String, int>{};
  for (final row in outputInventoriesResponse as List<dynamic>) {
    final map = Map<String, dynamic>.from(row as Map);
    final ownerId = (map['owner_id'] ?? '').toString();
    final quantity = (map['quantity'] as num?)?.toInt() ?? 0;
    outputByFarmId[ownerId] = (outputByFarmId[ownerId] ?? 0) + quantity;
  }

  return farms.map((farm) {
    final type = farmTypeById[farm.farmTypeId];
    return FarmListItemModel(
      farm: farm,
      cityName: cityNameById[farm.cityId] ?? 'Bilinmeyen Sehir',
      farmTypeName: (type?['name'] ?? 'Bilinmeyen Tarla').toString(),
      farmTypeIcon: (type?['icon'] ?? 'farm.webp').toString(),
      outputStockQuantity: outputByFarmId[farm.id] ?? 0,
      slots: slotsByFarmId[farm.id] ?? const [],
    );
  }).toList();
});

final farmTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('farm_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);
});

final farmConstructionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      final response = await supabase
          .from('building_constructions')
          .select()
          .eq('player_id', user.id)
          .eq('building_kind', 'farm')
          .eq('status', 'in_progress')
          .order('started_at')
          .limit(1);

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;
      return rows.first as Map<String, dynamic>;
    });

final farmDetailProvider = FutureProvider.family<FarmDetailModel, String>((
  ref,
  farmId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

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
    cityName: (farmPayload['city_name'] ?? 'Bilinmeyen Sehir').toString(),
    slots: slotRows.map(FarmProductionSlotModel.fromJson).toList(),
    inventories: inventoryRows
        .map(FarmProductionInventoryModel.fromJson)
        .toList(),
  );
});

class FarmActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(
    String constructionId,
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

  Future<Map<String, dynamic>> addProductionSlot(String farmId) async {
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
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignProductionSlotProduct({
    required String slotId,
    required String productId,
    required int qualityLevel,
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
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changeProductionSlotProduct({
    required String slotId,
    required String productId,
    required int qualityLevel,
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
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setProductionSlotActive({
    required String slotId,
    required bool isActive,
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
      return response as Map<String, dynamic>;
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
    required FarmProductionInventoryModel inventory,
    required String cityId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum acilmamis.');

    final response = await _supabase
        .from('warehouses')
        .select(
          'id, name, city_id, city:cities(name), warehouse_slots(*, product:products(*))',
        )
        .eq('player_id', user.id)
        .eq('city_id', cityId)
        .eq('is_active', true);

    final eligible = <Map<String, dynamic>>[];

    for (final warehouse in response as List<dynamic>) {
      final warehouseMap = Map<String, dynamic>.from(warehouse as Map);
      final slots = ((warehouseMap['warehouse_slots'] as List<dynamic>?) ?? const [])
          .where((slot) {
            final map = Map<String, dynamic>.from(slot as Map);
            return map['product_id'] == inventory.productId &&
                (map['quality_level'] as num?)?.toInt() == inventory.qualityLevel &&
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

    final response = await _supabase
        .from('warehouses')
        .select('id, name, city_id, city:cities(name)')
        .eq('player_id', user.id)
        .eq('city_id', cityId)
        .eq('is_active', true)
        .order('created_at');

    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
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
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final farmActionProvider = Provider((ref) => FarmActionNotifier());
