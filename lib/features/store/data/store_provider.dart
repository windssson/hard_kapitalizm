import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_history_item_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_performance_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final storesListProvider = FutureProvider<List<StoreModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return [];

  try {
    final response = await supabase.rpc(
      'get_stores_list',
      params: {'p_player_id': user.id},
    );

    List<StoreModel> allStores = [];

    if (response != null && response['success'] == true) {
      final storesJson = response['stores'] as List<dynamic>;
      allStores = storesJson
          .map((json) => StoreModel.fromJson(json))
          .toList();
    }

    final typesResponse = await supabase.from('store_types').select();
    final allTypes = (typesResponse as List)
        .map((json) => StoreTypeModel.fromJson(json))
        .toList();

    final citiesResponse = await supabase.from('cities').select();
    final allCities = (citiesResponse as List)
        .map((json) => CityModel.fromJson(json))
        .toList();

    final constructionResponse = await supabase
        .from('building_constructions')
        .select('*')
        .eq('player_id', user.id)
        .eq('building_kind', 'store')
        .eq('status', 'in_progress');

    if (constructionResponse != null &&
        (constructionResponse as List).isNotEmpty) {
      for (final constr in constructionResponse) {
        final params = constr['params'] as Map<String, dynamic>;
        final storeTypeId = params['store_type_id'] as String?;
        final cityId = params['city_id'] as String?;

        final type = allTypes.firstWhere(
          (t) => t.id == storeTypeId,
          orElse: () => StoreTypeModel(
            id: 'unknown',
            name: 'Bilinmeyen',
            icon: 'default.webp',
          ),
        );

        final city = allCities.firstWhere(
          (c) => c.id == cityId,
          orElse: () => CityModel(
            id: '',
            name: 'Bilinmeyen Sehir',
            population: 0,
            taxRate: 0.0,
            mapPositionX: 0,
            mapPositionY: 0,
            isActive: true,
          ),
        );

        final startedAt = DateTime.parse(constr['started_at'] as String);
        final finishAt = DateTime.parse(constr['finish_at'] as String);
        final now = DateTime.now();

        final totalDuration = finishAt.difference(startedAt).inSeconds;
        final elapsed = now.difference(startedAt).inSeconds;
        final progress = totalDuration > 0
            ? (elapsed / totalDuration).clamp(0.0, 1.0)
            : 0.0;

        allStores.add(
          StoreModel(
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
              pendingQuantity: 0,
              availableCapacity: params['slot_capacity'] as int? ?? 0,
              usedCapacityRatio: 0.0,
            ),
            slots: const [],
            isUnderConstruction: true,
            startedAt: startedAt,
            finishAt: finishAt,
            constructionProgress: progress,
          ),
        );
      }
    }

    return allStores;
  } catch (e) {
    print('StoreListProvider Error: $e');
    return [];
  }
});

final storeDetailProvider = FutureProvider.family<StoreModel, String>((
  ref,
  storeId,
) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    throw Exception('Kullanici girisi yapilmamis.');
  }

  final response = await supabase.rpc(
    'get_store_detail',
    params: {
      'p_player_id': user.id,
      'p_store_id': storeId,
    },
  );

  if (response['success'] == true) {
    return StoreModel.fromJson(response['store']);
  }

  throw Exception(
    response['message'] ?? 'Magaza detaylari alinirken hata olustu.',
  );
});

final storePerformanceProvider =
    FutureProvider.family<StorePerformanceResponseModel, String>((
      ref,
      storeId,
    ) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Kullanici girisi yapilmamis.');
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
        throw Exception(model.message ?? 'Magaza performansi alinamadi.');
      }

      return model;
    });

final storeHistoryProvider =
    FutureProvider.family<List<StoreHistoryItemModel>, String>((ref, storeId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Kullanici girisi yapilmamis.');
      }

      final transfersResponse = await supabase
          .from('logistics_transfers')
          .select(
            'id, quantity, status, total_price, rental_cost, quality_level, started_at, finish_at, completed_at, '
            'buyer_store_id, seller_store_id, buyer_warehouse_id, seller_warehouse_id, product_id',
          )
          .or('buyer_store_id.eq.$storeId,seller_store_id.eq.$storeId')
          .neq('status', 'in_transit')
          .order('completed_at', ascending: false)
          .limit(50);

      final transferRows = (transfersResponse as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final warehouseIds = <String>{
        for (final row in transferRows) ...[
          if ((row['seller_warehouse_id'] ?? '').toString().isNotEmpty)
            row['seller_warehouse_id'].toString(),
          if ((row['buyer_warehouse_id'] ?? '').toString().isNotEmpty)
            row['buyer_warehouse_id'].toString(),
        ],
      }.toList();

      final productIds = <String>{
        for (final row in transferRows)
          if ((row['product_id'] ?? '').toString().isNotEmpty)
            row['product_id'].toString(),
      }.toList();

      final warehouseMap = <String, Map<String, dynamic>>{};
      if (warehouseIds.isNotEmpty) {
        final warehouseResponse = await supabase
            .from('warehouses')
            .select('id, name, city:cities(name)')
            .inFilter('id', warehouseIds);

        for (final row in warehouseResponse as List<dynamic>) {
          final json = Map<String, dynamic>.from(row as Map);
          warehouseMap[(json['id'] ?? '').toString()] = json;
        }
      }

      final productMap = <String, Map<String, dynamic>>{};
      if (productIds.isNotEmpty) {
        final productResponse = await supabase
            .from('products')
            .select('id, urun_adi')
            .inFilter('id', productIds);

        for (final row in productResponse as List<dynamic>) {
          final json = Map<String, dynamic>.from(row as Map);
          productMap[(json['id'] ?? '').toString()] = json;
        }
      }

      final salesResponse = await supabase
          .from('store_daily_performance')
          .select(
            'id, performance_date, product_name, quality_level, sold_quantity, revenue, profit, sale_event_count, last_sale_at',
          )
          .eq('player_id', user.id)
          .eq('store_id', storeId)
          .gt('sold_quantity', 0)
          .order('last_sale_at', ascending: false)
          .limit(50);

      final items = <StoreHistoryItemModel>[
        ...transferRows.map((json) {
          final isIncoming = (json['buyer_store_id'] ?? '').toString() == storeId;
          final happenedAt = DateTime.tryParse(
                (json['completed_at'] ?? json['finish_at'] ?? json['started_at'] ?? '')
                    .toString(),
              ) ??
              DateTime.now();
          final sellerWarehouse = warehouseMap[
              (json['seller_warehouse_id'] ?? '').toString()];
          final buyerWarehouse = warehouseMap[
              (json['buyer_warehouse_id'] ?? '').toString()];
          final product = productMap[(json['product_id'] ?? '').toString()];
          final productName = (product?['urun_adi'] ?? 'Urun').toString();
          final sourceWarehouseName = (sellerWarehouse?['name'] ?? 'Depo').toString();
          final sourceCityName =
              (sellerWarehouse?['city']?['name'] ?? 'Sehir').toString();
          final buyerWarehouseName = (buyerWarehouse?['name'] ?? 'Depo').toString();
          final buyerCityName =
              (buyerWarehouse?['city']?['name'] ?? 'Sehir').toString();
          final totalPrice = (json['total_price'] as num?)?.toDouble() ?? 0;

          return StoreHistoryItemModel(
            id: 'transfer_${json['id']}',
            type: isIncoming ? 'incoming_transfer' : 'outgoing_transfer',
            happenedAt: happenedAt,
            title: isIncoming
                ? (totalPrice > 0 ? 'Pazardan Geldi' : 'Depodan Geldi')
                : 'Depoya Gonderildi',
            subtitle: isIncoming
                ? '$sourceWarehouseName | $sourceCityName'
                : '$buyerWarehouseName | $buyerCityName',
            productName: productName,
            quantity: (json['quantity'] as num?)?.toInt() ?? 0,
            amount: totalPrice,
            secondaryAmount: (json['rental_cost'] as num?)?.toDouble(),
            qualityLevel: (json['quality_level'] as num?)?.toInt(),
            status: (json['status'] ?? 'completed').toString(),
          );
        }),
        ...(salesResponse as List<dynamic>).map((row) {
          final json = Map<String, dynamic>.from(row as Map);
          final happenedAt = DateTime.tryParse(
                (json['last_sale_at'] ?? json['performance_date'] ?? '').toString(),
              ) ??
              DateTime.now();
          return StoreHistoryItemModel(
            id: 'sale_${json['id']}',
            type: 'sale',
            happenedAt: happenedAt,
            title: 'Satis Ozeti',
            subtitle:
                '${(json['sale_event_count'] as num?)?.toInt() ?? 0} satis islemi',
            productName: (json['product_name'] ?? 'Urun').toString(),
            quantity: (json['sold_quantity'] as num?)?.toInt() ?? 0,
            amount: (json['revenue'] as num?)?.toDouble() ?? 0,
            secondaryAmount: (json['profit'] as num?)?.toDouble(),
            qualityLevel: (json['quality_level'] as num?)?.toInt(),
            status: 'completed',
          );
        }),
      ];

      items.sort((a, b) => b.happenedAt.compareTo(a.happenedAt));
      return items;
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

  return (response as List)
      .map((json) => StoreTypeModel.fromJson(json))
      .toList();
});

class StoreActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

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
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

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
      final response = await _supabase
          .from('warehouses')
          .select('*, city:cities(name), warehouse_slots(*, product:products(*))')
          .eq('player_id', user.id)
          .eq('is_active', true);

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

  Future<List<MarketTransferVehicleOptionModel>> getStoreTransferVehicleOptions({
    required String storeSlotId,
    required String warehouseSlotId,
    required int quantity,
  }) async {
    final response = await _supabase.rpc(
      'get_store_transfer_vehicle_options',
      params: {
        'p_store_slot_id': storeSlotId,
        'p_warehouse_slot_id': warehouseSlotId,
        'p_quantity': quantity,
      },
    );

    return (response as List<dynamic>)
        .map(
          (json) => MarketTransferVehicleOptionModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPlayerWarehouses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await _supabase
        .from('warehouses')
        .select('id, name, city_id, is_active, city:cities(name)')
        .eq('player_id', user.id)
        .eq('is_active', true)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> startWarehouseToStoreTransfer({
    required String storeSlotId,
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
        'start_warehouse_to_store_transfer',
        params: {
          'p_store_slot_id': storeSlotId,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_quantity': quantity,
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<MarketTransferVehicleOptionModel>>
      getStoreToWarehouseVehicleOptions({
    required String storeSlotId,
    required String warehouseId,
    required int quantity,
  }) async {
    final response = await _supabase.rpc(
      'get_store_to_warehouse_vehicle_options',
      params: {
        'p_store_slot_id': storeSlotId,
        'p_buyer_warehouse_id': warehouseId,
        'p_quantity': quantity,
      },
    );

    return (response as List<dynamic>)
        .map(
          (json) => MarketTransferVehicleOptionModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> startStoreToWarehouseTransfer({
    required String storeSlotId,
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
        'start_store_to_warehouse_transfer',
        params: {
          'p_store_slot_id': storeSlotId,
          'p_buyer_warehouse_id': warehouseId,
          'p_quantity': quantity,
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<StoreSaleResultModel> processStoreSalesOnEntry(String storeId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const StoreSaleResultModel(
        success: false,
        processed: false,
        message: 'Oturum acilmamis.',
        processedAt: null,
        elapsedMinutes: 0,
        totalRevenue: 0,
        totalProfit: 0,
        totalSoldQuantity: 0,
        items: [],
      );
    }

    try {
      final response = await _supabase.rpc(
        'process_store_sales_on_entry',
        params: {
          'p_player_id': user.id,
          'p_store_id': storeId,
        },
      );

      return StoreSaleResultModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      return StoreSaleResultModel(
        success: false,
        processed: false,
        message: e.toString(),
        processedAt: null,
        elapsedMinutes: 0,
        totalRevenue: 0,
        totalProfit: 0,
        totalSoldQuantity: 0,
        items: const [],
      );
    }
  }
}

final storeActionProvider = Provider((ref) => StoreActionNotifier());
