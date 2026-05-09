import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_type_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_model.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_vehicle_type_model.dart';

final logisticsCompanyTypesProvider = FutureProvider.autoDispose<List<LogisticsCompanyTypeModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('logistics_company_types')
      .select()
      .order('required_level', ascending: true)
      .order('cost', ascending: true);

  return (response as List)
      .map((json) => LogisticsCompanyTypeModel.fromJson(json))
      .toList();
});

final logisticsVehicleTypesProvider = FutureProvider.autoDispose<List<LogisticsVehicleTypeModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('logistics_vehicle_types')
      .select()
      .order('purchase_price', ascending: true);

  return (response as List)
      .map((json) => LogisticsVehicleTypeModel.fromJson(json))
      .toList();
});

final playerLogisticsCompanyProvider = FutureProvider.autoDispose<LogisticsCompanyModel?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final response = await supabase
      .from('logistics_companies')
      .select()
      .eq('player_id', user.id)
      .order('created_at')
      .limit(1);

  final rows = response as List<dynamic>;
  if (rows.isEmpty) return null;

  return LogisticsCompanyModel.fromJson(rows.first as Map<String, dynamic>);
});

final playerLogisticsConstructionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final response = await supabase
      .from('building_constructions')
      .select()
      .eq('player_id', user.id)
      .eq('building_kind', 'logistics_company')
      .eq('status', 'in_progress')
      .order('started_at')
      .limit(1);

  final rows = response as List<dynamic>;
  if (rows.isEmpty) return null;

  return rows.first as Map<String, dynamic>;
});

final logisticsCompanyListStreamProvider = StreamProvider.autoDispose<List<LogisticsCompanyModel>>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return const Stream.empty();

  return supabase
      .from('logistics_companies')
      .stream(primaryKey: ['id'])
      .eq('player_id', user.id)
      .map((event) => event.map((e) => LogisticsCompanyModel.fromJson(e)).toList());
});

final logisticsVehicleListStreamProvider = StreamProvider.autoDispose<List<LogisticsVehicleModel>>((ref) {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) return const Stream.empty();

  return supabase
      .from('logistics_vehicles')
      .stream(primaryKey: ['id'])
      .eq('player_id', user.id)
      .map((event) => event.map((e) => LogisticsVehicleModel.fromJson(e)).toList());
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

  Future<Map<String, dynamic>> finishConstructionWithGold(String constructionId) async {
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
}

final logisticsActionProvider = Provider((ref) => LogisticsActionNotifier());
