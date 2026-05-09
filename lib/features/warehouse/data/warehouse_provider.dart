import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';

// Depo Listesi Provider
final warehouseListProvider = FutureProvider<List<WarehouseModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return [];

  try {
    final response = await supabase
        .from('warehouses')
        .select('*, warehouse_slots(*, product:products(*)), city:cities(name), warehouse_type:warehouse_types(icon)')
        .eq('player_id', user.id);

    List<WarehouseModel> allWarehouses = [];
    if (response != null) {
      final List<dynamic> data = response as List<dynamic>;
      allWarehouses = data.map((json) => WarehouseModel.fromJson(json)).toList();
    }

    final constructionResponse = await supabase
        .from('building_constructions')
        .select('*')
        .eq('player_id', user.id)
        .eq('building_kind', 'warehouse')
        .eq('status', 'in_progress');

    if (constructionResponse != null && (constructionResponse as List).isNotEmpty) {
      final typesResponse = await supabase.from('warehouse_types').select();
      final citiesResponse = await supabase.from('cities').select();

      for (var constr in (constructionResponse as List)) {
        final params = constr['params'] as Map<String, dynamic>;
        final typeId = params['warehouse_type_id'] as String?;
        final cityId = params['city_id'] as String?;

        final type = (typesResponse as List).firstWhere((t) => t['id'] == typeId, orElse: () => {'name': 'Depo', 'icon': 'warehouse.webp'});
        final city = (citiesResponse as List).firstWhere((c) => c['id'] == cityId, orElse: () => {'name': 'Bilinmeyen'});

        allWarehouses.add(WarehouseModel(
          id: constr['id'],
          playerId: user.id,
          warehouseTypeId: typeId ?? '',
          typeIcon: type['icon'],
          cityId: cityId ?? '',
          cityName: city['name'] ?? 'Bilinmeyen',
          name: params['name'] ?? type['name'],
          level: 1,
          capacity: (params['base_capacity'] ?? 0).toDouble(),
          reservedCapacity: 0,
          isActive: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isUnderConstruction: true,
          finishAt: DateTime.parse(constr['finish_at']),
        ));
      }
    }

    return allWarehouses;
  } catch (e) {
    print('WarehouseListProvider Error: $e');
    return [];
  }
});

// Depo Detay Provider
final warehouseDetailProvider = FutureProvider.family<WarehouseModel, String>((ref, warehouseId) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) throw Exception('Oturum açılmamış.');

  final response = await supabase
      .from('warehouses')
      .select('*, warehouse_slots(*, product:products(*)), city:cities(name), warehouse_type:warehouse_types(*)')
      .eq('id', warehouseId)
      .single();

  return WarehouseModel.fromJson(response);
});

// Depo Tip Detay Provider
final warehouseTypeDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, typeId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('warehouse_types').select().eq('id', typeId).single();
  return response;
});

// Tüm Ürünler Provider
final allProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('products').select().order('urun_adi');
  return (response as List).map((json) => ProductModel.fromJson(json)).toList();
});

// Depo Tipleri Provider
final warehouseTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('warehouse_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);
});

// Depo Aksiyonları
class WarehouseActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> addProductToWarehouse({
    required String warehouseId,
    required String productId,
    required int quantity,
    required int qualityLevel,
    required double cost,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

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
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

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

  Future<Map<String, dynamic>> finishConstructionWithGold(String constructionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

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
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

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
}

final warehouseActionProvider = Provider((ref) => WarehouseActionNotifier());
