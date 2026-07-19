import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_type_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_finance_entry_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_finance_summary_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_performance_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_type_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const logisticsFuelProductId = 'YAKIT';

final logisticsEntryStateProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('get_logistics_entry_state');
      return Map<String, dynamic>.from(response as Map);
    });

final logisticsCompanyTypesProvider =
    FutureProvider<List<LogisticsCompanyTypeModel>>((ref) async {
      final catalogs = await ref.watch(staticCatalogsProvider.future);
      return catalogs.logisticsCompanyTypes;
    });

final logisticsVehicleTypesProvider =
    FutureProvider<List<LogisticsVehicleTypeModel>>((ref) async {
      final catalogs = await ref.watch(staticCatalogsProvider.future);
      return catalogs.logisticsVehicleTypes;
    });

final activeCitiesProvider = FutureProvider<List<CityModel>>((ref) async {
  final catalogs = await ref.watch(staticCatalogsProvider.future);
  return catalogs.cities;
});

final playerLogisticsCompanyProvider =
    FutureProvider.autoDispose<LogisticsCompanyModel?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      final response = await supabase.rpc('get_player_logistics_company');
      if (response == null) return null;

      return LogisticsCompanyModel.fromJson(response as Map<String, dynamic>);
    });

final playerLogisticsConstructionProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return null;

      final response = await supabase.rpc(
        'get_player_building_constructions',
        params: {
          'p_building_kind': 'logistics_company',
          'p_status': 'in_progress',
        },
      );

      final rows = response as List<dynamic>;
      if (rows.isEmpty) return null;

      return rows.first as Map<String, dynamic>;
    });

final logisticsVehicleListProvider =
    FutureProvider<List<LogisticsVehicleModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return [];

      final response = await supabase.rpc(
        'get_player_logistics_vehicles',
        params: {'p_player_id': user.id},
      );

      final list = response as List<dynamic>;
      return list
          .map(
            (json) => LogisticsVehicleModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    });

final logisticsVehiclePerformanceProvider =
    FutureProvider.autoDispose<Map<String, LogisticsVehiclePerformanceModel>>((
      ref,
    ) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return const {};

      final response = await supabase.rpc(
        'get_player_logistics_vehicle_performance',
      );

      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final stats = <String, LogisticsVehiclePerformanceModel>{};

      for (final row in rows) {
        final vehicleId = row['vehicle_id']?.toString();
        if (vehicleId == null || vehicleId.isEmpty) continue;

        stats[vehicleId] = LogisticsVehiclePerformanceModel(
          vehicleId: vehicleId,
          totalTrips: (row['total_trips'] as num?)?.toInt() ?? 0,
          completedTrips: (row['completed_trips'] as num?)?.toInt() ?? 0,
          activeTrips: (row['active_trips'] as num?)?.toInt() ?? 0,
          rentalTrips: (row['rental_trips'] as num?)?.toInt() ?? 0,
          rentalRevenue: (row['rental_revenue'] as num?)?.toDouble() ?? 0.0,
          lastActivityAt: DateTime.tryParse(
            row['last_activity_at']?.toString() ?? '',
          ),
        );
      }

      return stats;
    });

final logisticsFinanceSummaryProvider =
    FutureProvider.autoDispose<LogisticsFinanceSummaryModel>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return const LogisticsFinanceSummaryModel.empty();

      final response = await supabase.rpc(
        'get_player_logistics_finance_summary',
      );
      if (response == null) return const LogisticsFinanceSummaryModel.empty();

      return LogisticsFinanceSummaryModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    });

final logisticsFinanceEntriesProvider =
    FutureProvider.autoDispose<List<LogisticsFinanceEntryModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return const [];

      final response = await supabase.rpc(
        'get_player_logistics_finance_entries',
        params: {'p_limit': 500},
      );

      return (response as List<dynamic>)
          .map(
            (json) => LogisticsFinanceEntryModel.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    });

final playerLogisticsFuelWarehouseSourcesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return const [];

      final response = await supabase.rpc(
        'get_player_active_warehouses_with_slots',
      );

      final warehouses = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final sources = <Map<String, dynamic>>[];

      for (final warehouse in warehouses) {
        final warehouseId = warehouse['id']?.toString() ?? '';
        final warehouseName = warehouse['name']?.toString() ?? 'Depo';
        final city = warehouse['city'] as Map<String, dynamic>?;
        final cityName = city?['name']?.toString() ?? 'Bilinmeyen Sehir';
        final slots =
            (warehouse['warehouse_slots'] as List<dynamic>? ?? const []);

        for (final rawSlot in slots) {
          final slot = Map<String, dynamic>.from(rawSlot as Map);
          if ((slot['product_id']?.toString() ?? '') !=
              logisticsFuelProductId) {
            continue;
          }
          final quantity = (slot['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0) continue;

          sources.add({
            'warehouse_id': warehouseId,
            'warehouse_name': warehouseName,
            'city_name': cityName,
            'slot_id': slot['id']?.toString() ?? '',
            'quantity': quantity,
            'quality_level': (slot['quality_level'] as num?)?.toInt() ?? 0,
            'cost': (slot['cost'] as num?)?.toDouble() ?? 0.0,
          });
        }
      }

      return sources;
    });

class LogisticsActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  LogisticsActionNotifier(this._ref);

  Map<String, dynamic> _sync(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

  Future<Map<String, dynamic>> createLogisticsCompany({
    required String typeId,
    required String name,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_logistics_company_construction',
        params: {'p_player_id': user.id, 'p_type_id': typeId, 'p_name': name},
      );
      if (syncProviders) {
        _ref.invalidate(playerLogisticsCompanyProvider);
        _ref.invalidate(playerLogisticsConstructionProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completeConstruction(
    String constructionId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'complete_building_construction',
        params: {'p_player_id': user.id, 'p_construction_id': constructionId},
      );
      if (syncProviders) {
        _ref.invalidate(playerLogisticsCompanyProvider);
        _ref.invalidate(playerLogisticsConstructionProvider);
      }
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
      if (syncProviders) {
        _ref.invalidate(playerLogisticsCompanyProvider);
        _ref.invalidate(playerLogisticsConstructionProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> reduceConstructionTimeWithAd(
    String constructionId, {
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'reduce_construction_time_with_ad',
        params: {'p_player_id': user.id, 'p_construction_id': constructionId},
      );
      if (syncProviders) {
        _ref.invalidate(playerLogisticsCompanyProvider);
        _ref.invalidate(playerLogisticsConstructionProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> purchaseVehicle({
    required String logisticsCompanyId,
    required String logisticsVehicleTypeId,
    bool syncProviders = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'purchase_logistics_vehicle',
        params: {
          'p_player_id': user.id,
          'p_logistics_company_id': logisticsCompanyId,
          'p_logistics_vehicle_type_id': logisticsVehicleTypeId,
        },
      );
      if (syncProviders) {
        _ref.invalidate(logisticsVehicleListProvider);
        _ref.invalidate(playerLogisticsCompanyProvider);
        _ref.invalidate(logisticsFinanceSummaryProvider);
        _ref.invalidate(logisticsFinanceEntriesProvider);
      }
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setVehicleRental({
    required String vehicleId,
    required bool isAvailableForRent,
    required double rentalPrice,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    if (isAvailableForRent && rentalPrice <= 0) {
      return {
        'success': false,
        'message': 'Kira fiyati sifirdan buyuk olmali.',
      };
    }

    try {
      final response = await _supabase.rpc(
        'set_logistics_vehicle_rental',
        params: {
          'p_player_id': user.id,
          'p_vehicle_id': vehicleId,
          'p_is_available_for_rent': isAvailableForRent,
          'p_rental_price': rentalPrice,
        },
      );
      _ref.invalidate(logisticsVehicleListProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> refuelVehicle(String vehicleId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'refuel_logistics_vehicle',
        params: {'p_player_id': user.id, 'p_vehicle_id': vehicleId},
      );
      _ref.invalidate(logisticsVehicleListProvider);
      _ref.invalidate(playerLogisticsCompanyProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> repairVehicle(String vehicleId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'repair_logistics_vehicle',
        params: {'p_player_id': user.id, 'p_vehicle_id': vehicleId},
      );
      _ref.invalidate(logisticsVehicleListProvider);
      _ref.invalidate(logisticsFinanceSummaryProvider);
      _ref.invalidate(logisticsFinanceEntriesProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> transferWarehouseFuelToCompany({
    required String logisticsCompanyId,
    required String warehouseSlotId,
    required int quantity,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'transfer_warehouse_fuel_to_logistics_company',
        params: {
          'p_logistics_company_id': logisticsCompanyId,
          'p_warehouse_slot_id': warehouseSlotId,
          'p_quantity': quantity,
        },
      );
      _ref.invalidate(playerLogisticsCompanyProvider);
      _ref.invalidate(playerLogisticsFuelWarehouseSourcesProvider);
      _ref.invalidate(logisticsVehicleListProvider);
      _ref.invalidate(logisticsFinanceSummaryProvider);
      _ref.invalidate(logisticsFinanceEntriesProvider);
      _ref.invalidate(warehouseListProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setVehicleActive({
    required String vehicleId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    try {
      final response = await _supabase.rpc(
        'set_logistics_vehicle_active',
        params: {
          'p_player_id': user.id,
          'p_vehicle_id': vehicleId,
          'p_is_active': isActive,
        },
      );
      _ref.invalidate(logisticsVehicleListProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setVehicleRoute({
    required String vehicleId,
    required String cityAId,
    required String cityBId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {'success': false, 'message': 'Oturum acilmamis.'};

    if (cityAId == cityBId) {
      return {
        'success': false,
        'message': 'Bir arac icin iki farkli sehir secmelisiniz.',
      };
    }

    try {
      final response = await _supabase.rpc(
        'set_logistics_vehicle_route',
        params: {
          'p_player_id': user.id,
          'p_vehicle_id': vehicleId,
          'p_route_city_a_id': cityAId,
          'p_route_city_b_id': cityBId,
        },
      );
      _ref.invalidate(logisticsVehicleListProvider);
      final result = _sync(response);

      return {
        'success': true,
        'message': result['message'] ?? 'Arac rotasi guncellendi.',
      };
    } on PostgrestException catch (e) {
      final message =
          e.message.toLowerCase().contains('set_logistics_vehicle_route')
          ? 'Rota guncelleme islemi su anda tamamlanamadi.'
          : e.message;
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final logisticsActionProvider = Provider((ref) => LogisticsActionNotifier(ref));
