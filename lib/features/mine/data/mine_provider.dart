import 'package:hard_kapitalizm/core/data/production_logistics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/production_product_service.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_list_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

// Maden Liste Provider
final mineListProvider =
    FutureProvider.autoDispose<List<MineListItemModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return const [];

  final response = await supabase.rpc('get_mine_list_items');
  final rows = response as List<dynamic>;

  return rows.map((row) {
    final map = Map<String, dynamic>.from(row as Map);
    return MineListItemModel(
      mine: MineModel.fromJson(
        Map<String, dynamic>.from(map['mine'] as Map),
      ),
      cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
      mineTypeName: (map['mine_type_name'] ?? 'Bilinmeyen Maden').toString(),
      mineTypeIcon: (map['mine_type_icon'] ?? 'mine.webp').toString(),
      outputStockQuantity:
          (map['output_stock_quantity'] as num?)?.toInt() ?? 0,
      selectedProduct: map['selected_product'] == null
          ? null
          : ProductModel.fromJson(
              Map<String, dynamic>.from(map['selected_product'] as Map),
            ),
    );
  }).toList();
});

// Maden Tipleri Provider
final mineTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final supabase = Supabase.instance.client;
  return await supabase.rpc('get_mine_types_catalog');
});

final mineConstructionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final response = await supabase.rpc(
    'get_player_building_constructions',
    params: {
      'p_building_kind': 'mine',
      'p_status': 'in_progress',
    },
  );

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

  final response = await supabase.rpc(
    'get_mine_detail_data',
    params: {'p_mine_id': mineId},
  );

  final map = Map<String, dynamic>.from(response as Map);
  return MineDetailModel(
    mine: MineModel.fromJson(
      Map<String, dynamic>.from(map['mine'] as Map),
    ),
    mineType: MineTypeDetailModel.fromJson(
      Map<String, dynamic>.from(map['mine_type'] as Map),
    ),
    cityName: (map['city_name'] ?? 'Bilinmeyen Sehir').toString(),
    product: map['product'] == null
        ? null
        : ProductModel.fromJson(
            Map<String, dynamic>.from(map['product'] as Map),
          ),
    inventories: (map['inventories'] as List<dynamic>? ?? const [])
        .map(
          (row) => MineProductionInventoryModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(),
  );
});

// Maden Aksiyonları
class MineActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ProductionLogisticsService _productionLogisticsService =
      ProductionLogisticsService();

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
      final response = await _supabase.rpc(
        'set_mine_active',
        params: {
          'p_mine_id': mineId,
          'p_is_active': isActive,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
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
  }) {
    return _productionLogisticsService.getWarehouseOptions(
      productionCityId: productionCityId,
    );
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

  Future<List<ProductionLogisticsVehicleOption>>
  getProductionOutputTransferVehicleOptions({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
  }) {
    return _productionLogisticsService
        .getProductionOutputTransferVehicleOptions(
          productionInventoryId: productionInventoryId,
          buyerWarehouseId: buyerWarehouseId,
          quantity: quantity,
        );
  }

  Future<ProductionLogisticsStartResult> startProductionToWarehouseTransfer({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
    String? vehicleId,
  }) {
    return _productionLogisticsService.startProductionToWarehouseTransfer(
      productionInventoryId: productionInventoryId,
      buyerWarehouseId: buyerWarehouseId,
      quantity: quantity,
      vehicleId: vehicleId,
    );
  }
}

final mineActionProvider = Provider((ref) => MineActionNotifier());
