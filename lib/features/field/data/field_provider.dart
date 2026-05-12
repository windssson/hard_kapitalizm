import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';

final fieldListStreamProvider = StreamProvider.autoDispose<List<FieldModel>>((
  ref,
) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const Stream.empty();

  return supabase
      .from('fields')
      .stream(primaryKey: ['id'])
      .eq('player_id', user.id)
      .map((event) => event.map((e) => FieldModel.fromJson(e)).toList());
});

final fieldTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('field_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);
});

final fieldConstructionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      final response = await supabase
          .from('building_constructions')
          .select()
          .eq('player_id', user.id)
          .eq('building_kind', 'field')
          .eq('status', 'in_progress')
          .order('started_at')
          .limit(1);

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;
      return rows.first as Map<String, dynamic>;
    });

final fieldDetailProvider = FutureProvider.family<FieldDetailModel, String>((
  ref,
  fieldId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  final fieldResponse = await supabase
      .from('fields')
      .select('*, city:cities(name)')
      .eq('id', fieldId)
      .eq('player_id', user.id)
      .single();

  final field = FieldModel.fromJson(fieldResponse);

  final fieldTypeResponse = await supabase
      .from('field_types')
      .select()
      .eq('id', field.fieldTypeId)
      .single();

  final slotsResponse = await supabase
      .from('production_slots')
      .select()
      .eq('owner_kind', 'field')
      .eq('owner_id', fieldId)
      .order('slot_index');

  final inventoriesResponse = await supabase
      .from('production_inventory')
      .select()
      .eq('owner_kind', 'field')
      .eq('owner_id', fieldId);

  final slotRows = (slotsResponse as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  final inventoryRows = (inventoriesResponse as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final productIds = <String>{
    ...slotRows
        .map((e) => e['product_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty),
    ...inventoryRows
        .map((e) => e['product_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty),
  }.toList();

  Map<String, ProductModel> productsById = const {};
  if (productIds.isNotEmpty) {
    final productResponse = await supabase
        .from('products')
        .select()
        .inFilter('id', productIds);
    productsById = {
      for (final row in productResponse as List<dynamic>)
        (row['id'] ?? '').toString(): ProductModel.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
    };
  }

  return FieldDetailModel(
    field: field,
    fieldType: FieldTypeDetailModel.fromJson(fieldTypeResponse),
    cityName: (fieldResponse['city']?['name'] ?? 'Bilinmeyen Sehir').toString(),
    slots: slotRows
        .map((e) {
          final productId = e['product_id']?.toString();
          return ProductionSlotModel.fromJson({
            ...e,
            'product': productId != null ? productsById[productId]?.toJson() : null,
          });
        })
        .toList(),
    inventories: inventoryRows
        .map((e) {
          final productId = e['product_id']?.toString();
          return ProductionInventoryModel.fromJson({
            ...e,
            'product': productId != null ? productsById[productId]?.toJson() : null,
          });
        })
        .toList(),
  );
});

class FieldActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  Future<Map<String, dynamic>> addProductionSlot(String fieldId) async {
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
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setProductionSlotProduct({
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
        'set_production_slot_product',
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

  Future<List<ProductModel>> getAcceptedProducts(
    List<String> acceptedProductIds,
  ) async {
    if (acceptedProductIds.isEmpty) return const [];

    final response = await _supabase
        .from('products')
        .select()
        .inFilter('id', acceptedProductIds)
        .order('urun_adi');

    return (response as List<dynamic>)
        .map(
          (e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getEligibleWarehouseSlotsForInventory({
    required ProductionInventoryModel inventory,
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

final fieldActionProvider = Provider((ref) => FieldActionNotifier());
