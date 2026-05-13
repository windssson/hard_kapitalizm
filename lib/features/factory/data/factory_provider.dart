import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';

// Fabrika Listesi Provider (Stream)
final factoryListStreamProvider = StreamProvider.autoDispose<List<FactoryModel>>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return const Stream.empty();

  return supabase
      .from('factories')
      .stream(primaryKey: ['id'])
      .eq('player_id', user.id)
      .map((event) => event.map((e) => FactoryModel.fromJson(e)).toList());
});

// Fabrika Tipleri Provider
final factoryTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('factory_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);
});

final factoryConstructionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final response = await supabase
      .from('building_constructions')
      .select()
      .eq('player_id', user.id)
      .eq('building_kind', 'factory')
      .eq('status', 'in_progress')
      .order('started_at')
      .limit(1);

  final rows = response as List<dynamic>;
  if (rows.isEmpty) return null;
  return rows.first as Map<String, dynamic>;
});

final factoryDetailProvider = FutureProvider.family<FactoryDetailModel, String>((
  ref,
  factoryId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  final factoryResponse = await supabase
      .from('factories')
      .select('*, city:cities(name)')
      .eq('id', factoryId)
      .eq('player_id', user.id)
      .single();

  final factory = FactoryModel.fromJson(
    Map<String, dynamic>.from(factoryResponse),
  );

  final factoryTypeResponse = await supabase
      .from('factory_types')
      .select()
      .eq('id', factory.factoryTypeId)
      .single();

  final inventoryResponse = await supabase
      .from('production_inventory')
      .select()
      .eq('owner_kind', 'factory')
      .eq('owner_id', factoryId);

  final inventoryRows = (inventoryResponse as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final productIds = <String>{
    if ((factory.productId ?? '').isNotEmpty) factory.productId!,
    ...inventoryRows
        .map((e) => e['product_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty),
  }.toList();

  Map<String, ProductModel> productsById = const {};
  if (productIds.isNotEmpty) {
    final productsResponse = await supabase
        .from('products')
        .select()
        .inFilter('id', productIds);
    productsById = {
      for (final row in productsResponse as List<dynamic>)
        (row['id'] ?? '').toString(): ProductModel.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
    };
  }

  return FactoryDetailModel(
    factory: factory,
    factoryType: FactoryTypeDetailModel.fromJson(
      Map<String, dynamic>.from(factoryTypeResponse),
    ),
    cityName: (factoryResponse['city']?['name'] ?? 'Bilinmeyen Sehir').toString(),
    product: factory.productId != null ? productsById[factory.productId!] : null,
    inventories: inventoryRows
        .map(
          (row) => FactoryProductionInventoryModel.fromJson({
            ...row,
            'product': productsById[row['product_id']?.toString() ?? '']?.toJson(),
          }),
        )
        .toList(),
  );
});

// Fabrika Aksiyonları
class FactoryActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  Future<Map<String, dynamic>> setFactoryProduct({
    required String factoryId,
    required String productId,
    required int qualityLevel,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_factory_product',
        params: {
          'p_player_id': user.id,
          'p_factory_id': factoryId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setFactoryActive({
    required String factoryId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      await _supabase
          .from('factories')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', factoryId)
          .eq('player_id', user.id);
      return {'success': true};
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

final factoryActionProvider = Provider((ref) => FactoryActionNotifier());
