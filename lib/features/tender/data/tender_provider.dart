import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_center_model.dart';
import 'package:hard_kapitalizm/features/tender/models/tender_detail_model.dart';
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

  void patchBidSubmitted(String tenderId, double bidAmount, {bool isNewBid = true}) {
    final current = state.value;
    if (current == null) return;

    final updatedOpen = current.openTenders.map((item) {
      if (item.tenderId == tenderId) {
        final currentLowest = item.lowestBidAmount;
        final newLowest = currentLowest == null
            ? bidAmount
            : (bidAmount < currentLowest ? bidAmount : currentLowest);
        final wasPlayerBid = item.hasPlayerBid;
        final shouldIncrement = isNewBid && !wasPlayerBid;

        return item.copyWith(
          hasPlayerBid: true,
          playerBidAmount: bidAmount,
          bidCount: shouldIncrement ? (item.bidCount + 1) : item.bidCount,
          lowestBidAmount: newLowest,
        );
      }
      return item;
    }).toList();

    state = AsyncData(current.copyWith(openTenders: updatedOpen));
  }

  void insertTender(TenderListItemModel item) {
    final current = state.value;
    if (current == null) return;
    if (current.openTenders.any((t) => t.tenderId == item.tenderId)) return;
    state = AsyncData(current.copyWith(
      openTenders: [item, ...current.openTenders],
    ));
  }

  void patchTenderChanges(String tenderId, Map<String, dynamic> changes) {
    final current = state.value;
    if (current == null) return;

    final status = changes['status']?.toString();
    if (status != null && status != 'open') {
      final updatedOpen = current.openTenders.where((t) => t.tenderId != tenderId).toList();
      state = AsyncData(current.copyWith(openTenders: updatedOpen));
      return;
    }

    final updatedOpen = current.openTenders.map((item) {
      if (item.tenderId == tenderId) {
        return item.copyWith(
          bidCount: (changes['bid_count'] as num?)?.toInt() ?? item.bidCount,
          lowestBidAmount: changes.containsKey('lowest_bid_amount')
              ? (changes['lowest_bid_amount'] as num?)?.toDouble()
              : item.lowestBidAmount,
          status: status ?? item.status,
        );
      }
      return item;
    }).toList();

    state = AsyncData(current.copyWith(openTenders: updatedOpen));
  }

  void removeTender(String tenderId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      openTenders: current.openTenders.where((t) => t.tenderId != tenderId).toList(),
    ));
  }

  void insertPlayerTender(PlayerTenderSummaryModel pt) {
    final current = state.value;
    if (current == null) return;
    if (current.myActiveTenders.any((t) => t.playerTenderId == pt.playerTenderId)) return;
    state = AsyncData(current.copyWith(
      myActiveTenders: [pt, ...current.myActiveTenders],
    ));
  }

  void patchPlayerTenderChanges(String playerTenderId, Map<String, dynamic> changes) {
    final current = state.value;
    if (current == null) return;

    final status = changes['status']?.toString();
    final isDone = status == 'completed' || status == 'cancelled' || status == 'failed';

    PlayerTenderSummaryModel patchPt(PlayerTenderSummaryModel pt) {
      final req = (changes['required_quantity'] as num?)?.toInt() ?? pt.requiredQuantity;
      final del = (changes['delivered_quantity'] as num?)?.toInt() ?? pt.deliveredQuantity;
      final rem = (changes['remaining_quantity'] as num?)?.toInt() ?? (req - del).clamp(0, req);
      return pt.copyWith(
        status: status ?? pt.status,
        requiredQuantity: req,
        deliveredQuantity: del,
        remainingQuantity: rem,
        completedAt: changes.containsKey('completed_at')
            ? (changes['completed_at'] != null ? DateTime.tryParse(changes['completed_at'].toString()) : null)
            : pt.completedAt,
        failedAt: changes.containsKey('failed_at')
            ? (changes['failed_at'] != null ? DateTime.tryParse(changes['failed_at'].toString()) : null)
            : pt.failedAt,
      );
    }

    if (isDone) {
      final active = current.myActiveTenders.firstWhere(
        (t) => t.playerTenderId == playerTenderId,
        orElse: () => PlayerTenderSummaryModel(
          playerTenderId: playerTenderId,
          tenderId: '',
          title: 'İhale',
          cityName: '',
          productId: '',
          productName: '',
          productIcon: '',
          qualityLevel: 1,
          requiredQuantity: 0,
          deliveredQuantity: 0,
          remainingQuantity: 0,
          rewardCash: 0,
          bondPaid: 0,
          deadlineAt: DateTime.now(),
          completedAt: null,
          failedAt: null,
          status: status ?? 'completed',
        ),
      );
      final patched = patchPt(active);
      state = AsyncData(current.copyWith(
        myActiveTenders: current.myActiveTenders.where((t) => t.playerTenderId != playerTenderId).toList(),
        myRecentTenders: [patched, ...current.myRecentTenders.where((t) => t.playerTenderId != playerTenderId)],
      ));
      return;
    }

    final updatedActive = current.myActiveTenders.map((item) {
      if (item.playerTenderId == playerTenderId) {
        return patchPt(item);
      }
      return item;
    }).toList();

    state = AsyncData(current.copyWith(myActiveTenders: updatedActive));
  }

  void removePlayerTender(String playerTenderId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      myActiveTenders: current.myActiveTenders.where((t) => t.playerTenderId != playerTenderId).toList(),
      myRecentTenders: current.myRecentTenders.where((t) => t.playerTenderId != playerTenderId).toList(),
    ));
  }

  void patchDeliveryCount(int delta) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      deliveryCount: (current.deliveryCount + delta).clamp(0, 999999),
    ));
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
          submittedAt: current.playerBid?.submittedAt ?? DateTime.now(),
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
  static final Set<String> activePlayerTenderIds = {};

  @override
  Future<TenderDetailModel> build() async {
    ref.onDispose(() {
      activePlayerTenderIds.remove(_playerTenderId);
    });
    activePlayerTenderIds.add(_playerTenderId);

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

  void patchPlayerTenderChanges(Map<String, dynamic> changes) {
    final current = state.value;
    if (current == null) return;
    final currentPt = current.playerTender;
    if (currentPt == null) return;

    final req = (changes['required_quantity'] as num?)?.toInt() ?? currentPt.requiredQuantity;
    final del = (changes['delivered_quantity'] as num?)?.toInt() ?? currentPt.deliveredQuantity;
    final inT = (changes['in_transit_quantity'] as num?)?.toInt() ?? currentPt.inTransitQuantity;
    final rem = (changes['remaining_quantity'] as num?)?.toInt() ?? (req - del - inT).clamp(0, req);
    final st = changes['status']?.toString() ?? currentPt.status;

    state = AsyncData(current.copyWith(
      playerTender: currentPt.copyWith(
        requiredQuantity: req,
        deliveredQuantity: del,
        inTransitQuantity: inT,
        remainingQuantity: rem,
        status: st,
      ),
    ));
  }

  void upsertDelivery(TenderActiveDeliveryModel delivery) {
    final current = state.value;
    if (current == null) return;
    final idx = current.activeDeliveries.indexWhere((d) => d.id == delivery.id);
    if (idx >= 0) {
      final updated = [...current.activeDeliveries];
      updated[idx] = delivery;
      state = AsyncData(current.copyWith(activeDeliveries: updated));
    } else {
      state = AsyncData(current.copyWith(
        activeDeliveries: [delivery, ...current.activeDeliveries],
      ));
    }
  }

  void removeDelivery(String deliveryId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      activeDeliveries: current.activeDeliveries.where((d) => d.id != deliveryId).toList(),
    ));
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
      final result = _sync(response);
      final hasBidPatch = (result['changed']?['patches'] as List?)
          ?.any((p) => p is Map && p['entity'] == 'tender_bid') ?? false;
      if (!hasBidPatch && result['success'] == true) {
        _ref.read(tenderCenterProvider.notifier).patchBidSubmitted(tenderId, bidAmount, isNewBid: true);
        _ref.read(tenderDetailProvider(tenderId).notifier).patchBidSubmitted(bidAmount);
      }
      return result;
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
      return _sync(response);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> refreshTenderRuntime() async {
    try {
      _ref.read(tenderCenterProvider.notifier).refresh();
      return {
        'success': true,
        'backend_managed': true,
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final tenderActionProvider = Provider<TenderActionNotifier>((ref) {
  return TenderActionNotifier(ref);
});
