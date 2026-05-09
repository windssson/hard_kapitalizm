import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';

final storesListProvider = FutureProvider<List<StoreModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return [];

  try {
    // 1. Mevcut aktif dükkanları çek (RPC)
    final response = await supabase.rpc(
      'get_stores_list',
      params: {'p_player_id': user.id},
    );

    List<StoreModel> allStores = [];

    if (response != null && response['success'] == true) {
      final List<dynamic> storesJson = response['stores'] as List<dynamic>;
      allStores = storesJson.map((json) => StoreModel.fromJson(json)).toList();
    }

    // 2. Yardımcı verileri çek (İnşaat eşleştirmesi için)
    final typesResponse = await supabase.from('store_types').select();
    final List<StoreTypeModel> allTypes = (typesResponse as List)
        .map((json) => StoreTypeModel.fromJson(json))
        .toList();

    final citiesResponse = await supabase.from('cities').select();
    final List<CityModel> allCities = (citiesResponse as List)
        .map((json) => CityModel.fromJson(json))
        .toList();

    // 3. Devam eden inşaatları çek
    final constructionResponse = await supabase
        .from('building_constructions')
        .select('*')
        .eq('player_id', user.id)
        .eq('building_kind', 'store')
        .eq('status', 'in_progress');

    if (constructionResponse != null && (constructionResponse as List).isNotEmpty) {
      for (var constr in (constructionResponse as List)) {
        final params = constr['params'] as Map<String, dynamic>;
        final storeTypeId = params['store_type_id'] as String?;
        final cityId = params['city_id'] as String?;
        
        final type = allTypes.firstWhere(
          (t) => t.id == storeTypeId,
          orElse: () => StoreTypeModel(id: 'unknown', name: 'Bilinmeyen', icon: 'default.webp'),
        );

        final city = allCities.firstWhere(
          (c) => c.id == cityId,
          orElse: () => CityModel(id: '', name: 'Bilinmeyen Sehir', population: 0, taxRate: 0.0, mapPositionX: 0, mapPositionY: 0, isActive: true),
        );

        final startedAt = DateTime.parse(constr['started_at'] as String);
        final finishAt = DateTime.parse(constr['finish_at'] as String);
        final now = DateTime.now();
        
        final totalDuration = finishAt.difference(startedAt).inSeconds;
        final elapsed = now.difference(startedAt).inSeconds;
        double progress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;

        allStores.add(StoreModel(
          id: constr['id'] as String,
          name: params['name'] as String? ?? type.name,
          cityId: cityId,
          cityName: city.name,
          level: 1,
          isActive: false,
          currentSlotCount: 0,
          maxSlotCount: params['max_slot_count'] as int? ?? 0,
          storeType: type,
          summary: StoreSummaryModel(
            totalQuantity: 0,
            totalCapacity: params['slot_capacity'] as int? ?? 0,
            availableCapacity: params['slot_capacity'] as int? ?? 0,
            usedCapacityRatio: 0.0,
          ),
          slots: [],
          isUnderConstruction: true,
          startedAt: startedAt,
          finishAt: finishAt,
          constructionProgress: progress,
        ));
      }
    }

    return allStores;
  } catch (e) {
    print('StoreListProvider Error: $e');
    return [];
  }
});

final storeDetailProvider = FutureProvider.family<StoreModel, String>((ref, storeId) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');

  final response = await supabase.rpc(
    'get_store_detail',
    params: {
      'p_player_id': user.id,
      'p_store_id': storeId,
    },
  );

  if (response['success'] == true) {
    return StoreModel.fromJson(response['store']);
  } else {
    throw Exception(response['message'] ?? 'Mağaza detayları alınırken hata oluştu.');
  }
});

final citiesProvider = FutureProvider<List<CityModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('cities').select().eq('is_active', true);
  
  return (response as List).map((json) => CityModel.fromJson(json)).toList();
});

final storeTypesProvider = FutureProvider<List<StoreTypeModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('store_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);
  
  return (response as List).map((json) => StoreTypeModel.fromJson(json)).toList();
});

class StoreActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createStore({
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

  Future<Map<String, dynamic>> addStoreSlot(String storeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

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
    required String productId,
    int qualityLevel = 1,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

    try {
      final response = await _supabase.rpc(
        'set_store_slot_product',
        params: {
          'p_player_id': user.id,
          'p_store_slot_id': slotId,
          'p_product_id': productId,
          'p_quality_level': qualityLevel,
        },
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  Future<Map<String, dynamic>> getEligibleWarehousesForStock({
    required String productId,
    required String cityId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

    try {
      // Oyuncunun bu şehirdeki aktif depolarını ve slotlarını çek
      final response = await _supabase
          .from('warehouses')
          .select('*, warehouse_slots(*)')
          .eq('player_id', user.id)
          .eq('city_id', cityId)
          .eq('is_active', true);

      final List<dynamic> warehouses = response as List<dynamic>;
      
      // Filtrele: Ürün bu depoda var mı ve miktarı > 0 mı?
      final eligible = warehouses.where((w) {
        final slots = w['warehouse_slots'] as List<dynamic>;
        return slots.any((s) => s['product_id'] == productId && (s['quantity'] as num) > 0);
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
    if (user == null) return {'success': false, 'message': 'Oturum açılmamış.'};

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
}

final storeActionProvider = Provider((ref) => StoreActionNotifier());
