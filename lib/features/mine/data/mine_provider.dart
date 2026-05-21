import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

// Maden Liste Provider
final mineListStreamProvider =
    FutureProvider.autoDispose<List<MineListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  final minesResponse = await supabase
      .from('mines')
      .select()
      .eq('player_id', user.id)
      .order('created_at', ascending: true);

  final mines = (minesResponse as List<dynamic>)
      .map((e) => MineModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  if (mines.isEmpty) return const [];

  final mineTypeIds = mines.map((e) => e.mineTypeId).toSet().toList();
  final cityIds = mines.map((e) => e.cityId).toSet().toList();
  final mineIds = mines.map((e) => e.id).toList();
  final productIds = <String>{
    ...mines
        .map((e) => e.productId ?? '')
        .where((e) => e.isNotEmpty),
  }.toList();

  final mineTypesResponse = await supabase
      .from('mine_types')
      .select('id, name, icon')
      .inFilter('id', mineTypeIds);
  final citiesResponse = await supabase
      .from('cities')
      .select('id, name')
      .inFilter('id', cityIds);
  final outputInventoriesResponse = await supabase
      .from('production_inventory')
      .select('owner_id, quantity')
      .eq('owner_kind', 'mine')
      .eq('inventory_type', 'output')
      .inFilter('owner_id', mineIds);

  Map<String, ProductModel> productsById = const {};
  if (productIds.isNotEmpty) {
    final productsResponse = await supabase
        .from('products')
        .select('id, urun_adi, urun_iconu, uretim_adedi')
        .inFilter('id', productIds);
    productsById = {
      for (final row in productsResponse as List<dynamic>)
        (row['id'] ?? '').toString(): ProductModel.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
    };
  }

  final mineTypeById = {
    for (final row in mineTypesResponse as List<dynamic>)
      (row['id'] ?? '').toString(): Map<String, dynamic>.from(row as Map),
  };
  final cityNameById = {
    for (final row in citiesResponse as List<dynamic>)
      (row['id'] ?? '').toString():
          (row['name'] ?? 'Bilinmeyen Sehir').toString(),
  };
  final outputByMineId = <String, int>{};
  for (final row in outputInventoriesResponse as List<dynamic>) {
    final map = Map<String, dynamic>.from(row as Map);
    final ownerId = (map['owner_id'] ?? '').toString();
    final quantity = (map['quantity'] as num?)?.toInt() ?? 0;
    outputByMineId[ownerId] = (outputByMineId[ownerId] ?? 0) + quantity;
  }

  return mines.map((mine) {
    final type = mineTypeById[mine.mineTypeId];
    return MineListItemModel(
      mine: mine,
      cityName: cityNameById[mine.cityId] ?? 'Bilinmeyen Sehir',
      mineTypeName: (type?['name'] ?? 'Bilinmeyen Maden').toString(),
      mineTypeIcon: (type?['icon'] ?? 'mine.webp').toString(),
      outputStockQuantity: outputByMineId[mine.id] ?? 0,
      selectedProduct:
          mine.productId != null ? productsById[mine.productId!] : null,
    );
  }).toList();
});

// Maden Tipleri Provider
final mineTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase
      .from('mine_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);
});

final mineConstructionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final response = await supabase
      .from('building_constructions')
      .select()
      .eq('player_id', user.id)
      .eq('building_kind', 'mine')
      .eq('status', 'in_progress')
      .order('started_at')
      .limit(1);

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

  final mineResponse = await supabase
      .from('mines')
      .select('*, city:cities(name)')
      .eq('id', mineId)
      .eq('player_id', user.id)
      .single();

  final mine = MineModel.fromJson(Map<String, dynamic>.from(mineResponse));

  final mineTypeResponse = await supabase
      .from('mine_types')
      .select()
      .eq('id', mine.mineTypeId)
      .single();

  final inventoryResponse = await supabase
      .from('production_inventory')
      .select()
      .eq('owner_kind', 'mine')
      .eq('owner_id', mineId);

  final inventoryRows = (inventoryResponse as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  final productIds = <String>{
    if ((mine.productId ?? '').isNotEmpty) mine.productId!,
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

  return MineDetailModel(
    mine: mine,
    mineType: MineTypeDetailModel.fromJson(
      Map<String, dynamic>.from(mineTypeResponse),
    ),
    cityName: (mineResponse['city']?['name'] ?? 'Bilinmeyen Sehir').toString(),
    product: mine.productId != null ? productsById[mine.productId!] : null,
    inventories: inventoryRows
        .map(
          (row) => MineProductionInventoryModel.fromJson({
            ...row,
            'product': productsById[row['product_id']?.toString() ?? '']?.toJson(),
          }),
        )
        .toList(),
  );
});

// Maden Aksiyonları
class MineActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      await _supabase
          .from('mines')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', mineId)
          .eq('player_id', user.id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
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

final mineActionProvider = Provider((ref) => MineActionNotifier());
