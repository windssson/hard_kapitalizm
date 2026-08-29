import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_center_model.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_detail_model.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenderCenterNotifier extends AsyncNotifier<TenderCenterModel> {
  @override
  Future<TenderCenterModel> build() async {
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
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void patchBidSubmitted(String tenderId, double bidAmount) {
    final current = state.value;
    if (current == null) return;

    final updatedOpen = current.openTenders.map((item) {
      if (item.tenderId == tenderId) {
        return item.copyWith(
          hasPlayerBid: true,
          playerBidAmount: bidAmount,
          bidCount: item.bidCount + 1,
        );
      }
      return item;
    }).toList();

    state = AsyncData(current.copyWith(openTenders: updatedOpen));
  }
}

final tenderCenterProvider =
    AsyncNotifierProvider<TenderCenterNotifier, TenderCenterModel>(
  TenderCenterNotifier.new,
);

class TenderDetailNotifier extends AsyncNotifier<TenderDetailModel> {
  TenderDetailNotifier(this._tenderId);

  final String _tenderId;

  @override
  Future<TenderDetailModel> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await supabase.rpc(
      'get_tender_detail',
      params: {'p_tender_id': _tenderId},
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
  }

  void patchBidSubmitted(double bidAmount) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        playerBid: PlayerTenderBidSummaryModel(
          id: current.playerBid?.id ?? '',
          bidAmount: bidAmount,
          bondPaid: current.playerBid?.bondPaid ?? current.tender.bondAmount,
          status: 'active',
          submittedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final tenderDetailProvider =
    AsyncNotifierProvider.family<TenderDetailNotifier, TenderDetailModel, String>(
  TenderDetailNotifier.new,
);

class PlayerTenderDetailNotifier extends AsyncNotifier<TenderDetailModel> {
  PlayerTenderDetailNotifier(this._playerTenderId);

  final String _playerTenderId;

  @override
  Future<TenderDetailModel> build() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await supabase.rpc(
      'get_tender_detail',
      params: {'p_player_tender_id': _playerTenderId},
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
  }

  void patchDeliveryStarted({
    required int quantity,
    required String warehouseId,
    String? vehicleId,
  }) {
    final current = state.value;
    if (current == null) return;
    final currentPt = current.playerTender;
    if (currentPt == null) return;

    final updatedPt = currentPt.copyWith(
      inTransitQuantity: currentPt.inTransitQuantity + quantity,
      remainingQuantity: (currentPt.remainingQuantity - quantity).clamp(0, currentPt.requiredQuantity),
    );

    final updatedWarehouseOptions = current.warehouseOptions.map((wh) {
      if (wh.warehouseId == warehouseId) {
        return wh.copyWith(
          availableQuantity: (wh.availableQuantity - quantity).clamp(0, wh.availableQuantity),
        );
      }
      return wh;
    }).toList();

    state = AsyncData(
      current.copyWith(
        playerTender: updatedPt,
        warehouseOptions: updatedWarehouseOptions,
      ),
    );
  }

  void patchCancelled() {
    final current = state.value;
    if (current == null) return;
    final currentPt = current.playerTender;
    if (currentPt == null) return;
    state = AsyncData(
      current.copyWith(
        playerTender: currentPt.copyWith(status: 'cancelled'),
      ),
    );
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final playerTenderDetailProvider =
    AsyncNotifierProvider.family<PlayerTenderDetailNotifier, TenderDetailModel, String>(
  PlayerTenderDetailNotifier.new,
);

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
      _ref.read(tenderCenterProvider.notifier).refresh();
      _ref.read(tenderDetailProvider(tenderId).notifier).refresh();
      _ref.invalidate(warehouseListProvider);
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
      _ref.read(tenderCenterProvider.notifier).patchBidSubmitted(tenderId, bidAmount);
      _ref.read(tenderDetailProvider(tenderId).notifier).patchBidSubmitted(bidAmount);
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
      _ref.read(playerTenderDetailProvider(playerTenderId).notifier).patchDeliveryStarted(
        quantity: quantity,
        warehouseId: warehouseId,
        vehicleId: vehicleId,
      );
      _ref.read(tenderCenterProvider.notifier).refresh();
      _ref.invalidate(warehouseListProvider);
      _ref.invalidate(logisticsVehicleListProvider);
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
      _ref.read(playerTenderDetailProvider(playerTenderId).notifier).patchCancelled();
      _ref.read(tenderCenterProvider.notifier).refresh();
      _ref.invalidate(warehouseListProvider);
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> refreshTenderRuntime() async {
    try {
      final deliveryResponse = await _supabase.rpc('process_tender_deliveries');
      final tenderResponse = await _supabase.rpc('process_player_tenders');
      _ref.read(tenderCenterProvider.notifier).refresh();
      if (deliveryResponse != null && deliveryResponse is Map) {
        _sync(deliveryResponse);
      }
      if (tenderResponse != null && tenderResponse is Map) {
        _sync(tenderResponse);
      }
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
