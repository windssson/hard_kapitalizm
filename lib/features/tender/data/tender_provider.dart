import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_center_model.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_detail_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final tenderCenterProvider = FutureProvider<TenderCenterModel>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    return const TenderCenterModel(
      success: false,
      openTenders: [],
      myActiveTenders: [],
      myBidTenders: [],
      myRecentTenders: [],
      deliveryCount: 0,
      serverTime: null,
    );
  }

  final response = await supabase.rpc('get_tender_center');
  return TenderCenterModel.fromJson(Map<String, dynamic>.from(response as Map));
});

final tenderDetailProvider =
    FutureProvider.family<TenderDetailModel, String>((ref, tenderId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Oturum acilmamis.');
      }

      final response = await supabase.rpc(
        'get_tender_detail',
        params: {'p_tender_id': tenderId},
      );
      final detail = TenderDetailModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      if (!detail.success) {
        throw Exception(
          detail.message.isNotEmpty ? detail.message : 'İhale detayı alınamadı.',
        );
      }
      return detail;
    });

final playerTenderDetailProvider =
    FutureProvider.family<TenderDetailModel, String>((ref, playerTenderId) async {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('Oturum acilmamis.');
      }

      final response = await supabase.rpc(
        'get_tender_detail',
        params: {'p_player_tender_id': playerTenderId},
      );
      final detail = TenderDetailModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      if (!detail.success) {
        throw Exception(
          detail.message.isNotEmpty
              ? detail.message
              : 'Oyuncu ihalesi detayı alınamadı.',
        );
      }
      return detail;
    });

final _transferVehicleOptionsServiceProvider = Provider<
  TransferVehicleOptionsService
>((ref) {
  return TransferVehicleOptionsService();
});

final tenderVehicleOptionsProvider =
    FutureProvider.family<
      TransferVehicleOptionsResult<TenderVehicleOptionModel>,
      TenderVehicleOptionsRequest
    >((ref, request) async {
      final service = ref.read(_transferVehicleOptionsServiceProvider);
      final response = await service.getRouteOptions(
        RouteTransferVehicleOptionsRequest(
          sourceCityId: request.sourceCityId,
          targetCityId: request.targetCityId,
          totalVolume: request.totalVolume,
        ),
      );

      return mapTransferVehicleOptions(
        rows: response,
        mapper: TenderVehicleOptionModel.fromJson,
      );
    });

class TenderActionNotifier {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  TenderActionNotifier(this._ref);

  Map<String, dynamic> _sync(dynamic response) {
    final result = Map<String, dynamic>.from(response as Map);
    _ref.read(mutationSyncServiceProvider).applyRaw(result);
    return result;
  }

  Future<Map<String, dynamic>> acceptTender(String tenderId) async {
    try {
      final response = await _supabase.rpc(
        'accept_tender',
        params: {'p_tender_id': tenderId},
      );
      _ref.invalidate(tenderCenterProvider);
      _ref.invalidate(tenderDetailProvider);
      _ref.invalidate(playerTenderDetailProvider);
      _ref.invalidate(playerNotificationDashboardProvider);
      _ref.invalidate(homeDashboardProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitTenderBid({
    required String tenderId,
    required double bidAmount,
  }) async {
    try {
      final response = await _supabase.rpc(
        'submit_tender_bid',
        params: {
          'p_tender_id': tenderId,
          'p_bid_amount': bidAmount,
        },
      );
      _ref.invalidate(tenderCenterProvider);
      _ref.invalidate(tenderDetailProvider);
      _ref.invalidate(playerTenderDetailProvider);
      _ref.invalidate(playerNotificationDashboardProvider);
      _ref.invalidate(homeDashboardProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> startTenderDelivery({
    required String playerTenderId,
    required String warehouseId,
    String? vehicleId,
    required int quantity,
  }) async {
    try {
      final response = await _supabase.rpc(
        'start_tender_delivery',
        params: {
          'p_player_tender_id': playerTenderId,
          'p_warehouse_id': warehouseId,
          'p_vehicle_id': vehicleId,
          'p_quantity': quantity,
        },
      );
      _ref.invalidate(tenderCenterProvider);
      _ref.invalidate(playerTenderDetailProvider(playerTenderId));
      _ref.invalidate(playerNotificationDashboardProvider);
      _ref.invalidate(homeDashboardProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelPlayerTender(String playerTenderId) async {
    try {
      final response = await _supabase.rpc(
        'cancel_player_tender',
        params: {'p_player_tender_id': playerTenderId},
      );
      _ref.invalidate(tenderCenterProvider);
      _ref.invalidate(playerTenderDetailProvider(playerTenderId));
      _ref.invalidate(playerNotificationDashboardProvider);
      _ref.invalidate(homeDashboardProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> refreshTenderRuntime() async {
    try {
      final deliveryResponse = await _supabase.rpc('process_tender_deliveries');
      final tenderResponse = await _supabase.rpc('process_player_tenders');
      _ref.invalidate(tenderCenterProvider);
      _ref.invalidate(tenderDetailProvider);
      _ref.invalidate(playerTenderDetailProvider);
      _ref.invalidate(playerNotificationDashboardProvider);
      _ref.invalidate(homeDashboardProvider);
      return {
        'success': true,
        'delivery_result': deliveryResponse,
        'tender_result': tenderResponse,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final tenderActionProvider = Provider<TenderActionNotifier>((ref) {
  return TenderActionNotifier(ref);
});
