import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_type_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_performance_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_type_model.dart';

final logisticsCompanyTypesProvider =
    FutureProvider.autoDispose<List<LogisticsCompanyTypeModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('get_logistics_company_types_catalog');

      return (response as List)
          .map((json) => LogisticsCompanyTypeModel.fromJson(json))
          .toList();
    });

final logisticsVehicleTypesProvider =
    FutureProvider.autoDispose<List<LogisticsVehicleTypeModel>>((ref) async {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('get_logistics_vehicle_types_catalog');

      return (response as List)
          .map((json) => LogisticsVehicleTypeModel.fromJson(json))
          .toList();
    });

final activeCitiesProvider = FutureProvider.autoDispose<List<CityModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_active_cities');

  return (response as List).map((json) => CityModel.fromJson(json)).toList();
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

final logisticsVehicleListStreamProvider =
    StreamProvider.autoDispose<List<LogisticsVehicleModel>>((ref) {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return const Stream.empty();

      return supabase
          .from('logistics_vehicles')
          .stream(primaryKey: ['id'])
          .eq('player_id', user.id)
          .map(
            (event) => event.map((e) => LogisticsVehicleModel.fromJson(e)).toList(),
          );
    });

final logisticsVehiclePerformanceProvider =
    FutureProvider.autoDispose<Map<String, LogisticsVehiclePerformanceModel>>((ref) async {
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

class LogisticsActionNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> createLogisticsCompany({
    required String typeId,
    required String name,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'start_logistics_company_construction',
        params: {
          'p_player_id': user.id,
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

  Future<Map<String, dynamic>> purchaseVehicle({
    required String logisticsCompanyId,
    required String logisticsVehicleTypeId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'purchase_logistics_vehicle',
        params: {
          'p_player_id': user.id,
          'p_logistics_company_id': logisticsCompanyId,
          'p_logistics_vehicle_type_id': logisticsVehicleTypeId,
        },
      );

      return response as Map<String, dynamic>;
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
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
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

      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> refuelVehicle(String vehicleId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'refuel_logistics_vehicle',
        params: {
          'p_player_id': user.id,
          'p_vehicle_id': vehicleId,
        },
      );

      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> repairVehicle(String vehicleId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'repair_logistics_vehicle',
        params: {
          'p_player_id': user.id,
          'p_vehicle_id': vehicleId,
        },
      );

      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> setVehicleActive({
    required String vehicleId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await _supabase.rpc(
        'set_logistics_vehicle_active',
        params: {
          'p_player_id': user.id,
          'p_vehicle_id': vehicleId,
          'p_is_active': isActive,
        },
      );

      return response as Map<String, dynamic>;
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
    if (user == null) {
      return {'success': false, 'message': 'Oturum acilmamis.'};
    }

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
      final result = Map<String, dynamic>.from(response as Map);

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

final logisticsActionProvider = Provider((ref) => LogisticsActionNotifier());
