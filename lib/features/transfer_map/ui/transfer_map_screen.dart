import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_history_item_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';

enum _ActiveTransferFilter {
  all('Tumu'),
  rental('Kiralik'),
  owned('Ozmal'),
  intercity('Sehirler Arasi'),
  sameCity('Ayni Sehir'),
  urgent('Yaklasan');

  const _ActiveTransferFilter(this.label);
  final String label;
}

enum _HistoryTransferFilter {
  all('Tumu'),
  completed('Tamamlandi'),
  cancelled('Iptal'),
  rental('Kiralik'),
  owned('Ozmal');

  const _HistoryTransferFilter(this.label);
  final String label;
}

enum _HistorySortOption {
  newest('En Yeni'),
  oldest('En Eski'),
  expensive('En Pahali'),
  longest('En Uzun');

  const _HistorySortOption(this.label);
  final String label;
}

class TransferMapScreen extends ConsumerStatefulWidget {
  const TransferMapScreen({super.key});

  @override
  ConsumerState<TransferMapScreen> createState() => _TransferMapScreenState();
}

class _TransferMapScreenState extends ConsumerState<TransferMapScreen> {
  final int _selectedIndex = 2;
  Timer? _dueTransferTimer;
  bool _isCompletingDueTransfers = false;
  int _selectedTab = 0;
  _ActiveTransferFilter _activeFilter = _ActiveTransferFilter.all;
  _HistoryTransferFilter _historyFilter = _HistoryTransferFilter.all;
  _HistorySortOption _historySort = _HistorySortOption.newest;
  String? _selectedTransferId;
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final Map<String, GlobalKey> _transferCardKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transfers = ref.read(buyerTransferMapProvider).value;
      if (transfers != null) {
        _scheduleDueTransferCheckForTransfers(transfers);
      }
    });
  }

  @override
  void dispose() {
    _dueTransferTimer?.cancel();
    _activeScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  void _scheduleDueTransferCheckForTransfers(
    List<TransferMapItemModel> transfers,
  ) {
    _dueTransferTimer?.cancel();

    if (!mounted || transfers.isEmpty) return;

    final now = DateTime.now();
    final pendingTransfers = transfers
        .where((transfer) => transfer.status == 'in_transit')
        .toList();

    if (pendingTransfers.isEmpty) return;

    DateTime? nextDueAt;
    for (final transfer in pendingTransfers) {
      if (nextDueAt == null || transfer.finishAt.isBefore(nextDueAt)) {
        nextDueAt = transfer.finishAt;
      }
    }

    if (nextDueAt == null) return;

    final delay = nextDueAt.isAfter(now)
        ? nextDueAt.difference(now)
        : Duration.zero;

    _dueTransferTimer = Timer(delay, () async {
      if (!mounted) return;
      await _checkDueTransfers();
      final refreshedTransfers = ref.read(buyerTransferMapProvider).value;
      if (refreshedTransfers != null) {
        _scheduleDueTransferCheckForTransfers(refreshedTransfers);
      }
    });
  }

  void _onNavSelected(int index) {
    if (index == _selectedIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/company');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 3:
        context.go('/market');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  Set<String> _affectedIds(Map<String, dynamic> result, String key) {
    final affected = result['affected'];
    if (affected is! Map) return const {};
    final values = affected[key];
    if (values is! List) return const {};
    return values
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  void _invalidateAffectedTransferTargets(Map<String, dynamic> result) {
    final warehouseIds = _affectedIds(result, 'warehouse_ids');
    final storeIds = _affectedIds(result, 'store_ids');
    final factoryIds = _affectedIds(result, 'factory_ids');
    final farmIds = _affectedIds(result, 'farm_ids');
    final fieldIds = _affectedIds(result, 'field_ids');
    final mineIds = _affectedIds(result, 'mine_ids');

    if (storeIds.isNotEmpty) {
      ref.invalidate(storesListProvider);
      for (final storeId in storeIds) {
        ref.invalidate(storeDetailPageProvider(storeId));
      }
    }

    if (warehouseIds.isNotEmpty) {
      ref.invalidate(warehouseListProvider);
      for (final warehouseId in warehouseIds) {
        ref.invalidate(warehouseDetailProvider(warehouseId));
      }
    }

    if (factoryIds.isNotEmpty) {
      ref.invalidate(factoryListProvider);
      for (final factoryId in factoryIds) {
        ref.invalidate(factoryDetailProvider(factoryId));
      }
    }

    if (farmIds.isNotEmpty) {
      ref.invalidate(farmListProvider);
      for (final farmId in farmIds) {
        ref.invalidate(farmDetailProvider(farmId));
      }
    }

    if (fieldIds.isNotEmpty) {
      ref.invalidate(fieldListProvider);
      for (final fieldId in fieldIds) {
        ref.invalidate(fieldDetailProvider(fieldId));
      }
    }

    if (mineIds.isNotEmpty) {
      ref.invalidate(mineListProvider);
      for (final mineId in mineIds) {
        ref.invalidate(mineDetailProvider(mineId));
      }
    }
  }

  Future<void> _checkDueTransfers() async {
    if (_isCompletingDueTransfers) return;

    final transfers = ref.read(buyerTransferMapProvider).value;
    if (transfers == null || transfers.isEmpty) return;
    final now = DateTime.now();
    final dueTransfers = transfers
        .where((transfer) => !transfer.finishAt.isAfter(now))
        .toList();

    if (dueTransfers.isEmpty) return;

    _isCompletingDueTransfers = true;
    try {
      var completedCount = 0;
      final affectedWarehouseIds = <String>{};
      final affectedStoreIds = <String>{};
      final affectedFactoryIds = <String>{};
      final affectedFarmIds = <String>{};
      final affectedFieldIds = <String>{};
      final affectedMineIds = <String>{};

      for (final transfer in dueTransfers) {
        final result = await _completeTransfer(ref, transfer);
        if (result['success'] == true) {
          completedCount += 1;
          affectedWarehouseIds.addAll(_affectedIds(result, 'warehouse_ids'));
          affectedStoreIds.addAll(_affectedIds(result, 'store_ids'));
          affectedFactoryIds.addAll(_affectedIds(result, 'factory_ids'));
          affectedFarmIds.addAll(_affectedIds(result, 'farm_ids'));
          affectedFieldIds.addAll(_affectedIds(result, 'field_ids'));
          affectedMineIds.addAll(_affectedIds(result, 'mine_ids'));
        }
      }

      ref.invalidate(buyerTransferMapProvider);
      ref.invalidate(buyerTransferHistoryProvider);
      _invalidateAffectedTransferTargets({
        'affected': {
          'warehouse_ids': affectedWarehouseIds.toList(),
          'store_ids': affectedStoreIds.toList(),
          'factory_ids': affectedFactoryIds.toList(),
          'farm_ids': affectedFarmIds.toList(),
          'field_ids': affectedFieldIds.toList(),
          'mine_ids': affectedMineIds.toList(),
        },
      });
      if (!mounted) return;

      if (completedCount > 0) {
        AppSnackbar.show(
          context,
          title: 'Teslimat Tamamlandi',
          message: _buildDeliveryCompletionMessage(
            dueTransfers,
            completedCount,
          ),
          type: SnackbarType.success,
        );
      }
    } finally {
      _isCompletingDueTransfers = false;
      final refreshedTransfers = ref.read(buyerTransferMapProvider).value;
      if (refreshedTransfers != null) {
        _scheduleDueTransferCheckForTransfers(refreshedTransfers);
      }
    }
  }

  Future<Map<String, dynamic>> _completeTransfer(
    WidgetRef ref,
    TransferMapItemModel transfer,
  ) {
    if (_isLogisticsTransferType(transfer.transferType)) {
      return ref
          .read(warehouseActionProvider)
          .completeLogisticsTransfer(transfer.id);
    }
    return Future.value({
      'success': false,
      'message':
          'Eski market transfer akisi kapatildi. Bu kayit yeni sistem disinda kalmis.',
    });
  }

  Future<void> _showTransferInfo(TransferMapItemModel transfer) async {
    final accentColor = transfer.isRental ? Colors.orange : AppColors.gold;
    final routeDistanceKm = _estimateRouteDistanceKm(
      transfer.sellerWarehouse.city,
      transfer.buyerWarehouse.city,
    );
    final totalCost = transfer.totalPrice + transfer.transportCost;
    final unitCost = transfer.displayQuantity > 0
        ? totalCost / transfer.displayQuantity
        : 0.0;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardBg,
        insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 24.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560.w,
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
            child: Consumer(
              builder: (context, ref, _) {
                final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
                final remaining = transfer.finishAt.difference(now);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            transfer.isRental
                                ? Icons.local_shipping
                                : Icons.directions_car,
                            color: accentColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transfer.displayTitle,
                                style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Transfer Detaylari',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textMuted,
                            size: 20.sp,
                          ),
                          splashRadius: 20.r,
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildDialogInfoRow(
                                    Icons.my_location,
                                    'Cikis (${transfer.sellerKindLabel})',
                                    '${transfer.sellerWarehouse.name} | ${transfer.sellerWarehouse.city.name}',
                                  ),
                                  Divider(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    height: 22.h,
                                  ),
                                  _buildDialogInfoRow(
                                    Icons.location_on,
                                    'Varis (${transfer.buyerKindLabel})',
                                    '${transfer.buyerWarehouse.name} | ${transfer.buyerWarehouse.city.name}',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 14.h),
                            _buildDialogDetailRow(
                              'Miktar',
                              '${transfer.displayQuantity} adet',
                            ),
                            if (!transfer.isMultiItem) ...[
                              _buildDialogDetailRow(
                                'Kalite',
                                'Kalite ${transfer.qualityLevel}',
                              ),
                              _buildDialogDetailRow(
                                'Brand',
                                transfer.hasBrand
                                    ? 'Brandli Urun'
                                    : 'Standart Brand',
                              ),
                            ],
                            if (transfer.isMultiItem)
                              _buildDialogDetailRow(
                                'Kalem Sayisi',
                                '${transfer.itemCount} farkli urun',
                              ),
                            _buildDialogDetailRow(
                              'Nakliye Tipi',
                              transfer.isRental ? 'Kiralik Arac' : 'Ozmal Arac',
                            ),
                            _buildDialogDetailRow(
                              'Rota',
                              _isSameCityTransfer(transfer)
                                  ? 'Ayni Sehir'
                                  : 'Sehirler Arasi',
                            ),
                            _buildDialogDetailRow(
                              'Mesafe',
                              '${routeDistanceKm.toStringAsFixed(0)} km',
                            ),
                            _buildDialogDetailRow(
                              'Urun Bedeli',
                              _formatCurrency(transfer.totalPrice),
                            ),
                            _buildDialogDetailRow(
                              'Kira Bedeli',
                              _formatCurrency(transfer.rentalCost),
                            ),
                            _buildDialogDetailRow(
                              'Nakliye Maliyeti',
                              _formatCurrency(transfer.transportCost),
                            ),
                            _buildDialogDetailRow(
                              'Toplam Maliyet',
                              _formatCurrency(totalCost),
                            ),
                            _buildDialogDetailRow(
                              'Birim Maliyet',
                              _formatCurrency(unitCost),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    color: accentColor,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      'Kalan Sure: ${_formatRemaining(remaining)}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /*
  Future<void> _confirmFinishWithStars(
    BuildContext context,
    WidgetRef ref,
    TransferMapItemModel transfer,
    int starCost,
  ) async {
    final player = ref.read(playerProvider).value;
    final currentGold = player?.gold ?? 0;

    if (currentGold < starCost) {
      AppSnackbar.show(
        context,
        title: 'Yetersiz Yildiz',
        message: 'Bu islemi gerceklestirmek icin yeterli yildiziniz yok. Gerekli: $starCost, Mevcut: ${currentGold.toInt()}',
        type: SnackbarType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: AppColors.gold, size: 24.sp),
            SizedBox(width: 8.w),
            const Text('Hemen Bitir', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Bu transferi $starCost ⭐ harcayarak aninda tamamlamak istiyor musunuz?\n\nMevcut Yildiziniz: ${currentGold.toInt()}',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgec',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Tamamla',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.gold,
        ),
      ),
    );

    try {
      final result = await ref
          .read(marketActionProvider)
          .finishMarketTransferWithStars(transfer.id);

      if (context.mounted) {
        Navigator.of(context).pop(); // Pop loading dialog
      }

      if (result['success'] == true) {
        if (context.mounted) {
          Navigator.of(context).pop(); // Pop details dialog
        }

        ref.invalidate(buyerTransferMapProvider);
        ref.invalidate(buyerTransferHistoryProvider);
        ref.invalidate(playerProvider);
        _invalidateAffectedTransferTargets(result);

        if (context.mounted) {
          AppSnackbar.show(
            context,
            title: 'Basarili',
            message: 'Transfer yildiz kullanilarak aninda tamamlandi!',
            type: SnackbarType.success,
          );
        }
      } else {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message: result['message'] ?? 'Transfer tamamlanirken bir hata olustu.',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Pop loading dialog
      }
      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    }
  }

  */
  Widget _buildDialogInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.gold, size: 16.sp),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transfersAsync = ref.watch(buyerTransferMapProvider);
    final historyAsync = ref.watch(buyerTransferHistoryProvider);
    ref.listen<AsyncValue<List<TransferMapItemModel>>>(
      buyerTransferMapProvider,
      (_, next) {
        next.whenData(_scheduleDueTransferCheckForTransfers);
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Transfer Haritasi'),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
              child: _buildModeSelector(),
            ),
            Expanded(
              child: _selectedTab == 0
                  ? transfersAsync.when(
                      data: (transfers) {
                        _pruneTransferCardKeys(transfers);
                        final filteredTransfers = _applyActiveFilter(transfers);
                        final activeCounts = _countActiveFilters(transfers);
                        TransferMapItemModel? selectedTransfer;
                        if (filteredTransfers.isNotEmpty) {
                          for (final item in filteredTransfers) {
                            if (item.id == _selectedTransferId) {
                              selectedTransfer = item;
                              break;
                            }
                          }
                          selectedTransfer ??= filteredTransfers.first;
                        }
                        final dueCount = transfers
                            .where(
                              (transfer) =>
                                  !transfer.finishAt.isAfter(DateTime.now()),
                            )
                            .length;

                        return RefreshIndicator(
                          onRefresh: () async {
                            await _checkDueTransfers();
                            ref.invalidate(buyerTransferMapProvider);
                          },
                          child: filteredTransfers.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  children: [
                                    SizedBox(height: 8.h),
                                    _buildActiveOverview(
                                      transfers,
                                      counts: activeCounts,
                                    ),
                                    SizedBox(height: 8.h),
                                    _buildActiveFilterBar(
                                      transfers,
                                      counts: activeCounts,
                                    ),
                                    SizedBox(height: 120.h),
                                    _buildEmptyState(
                                      hasAnyTransfers: transfers.isNotEmpty,
                                    ),
                                  ],
                                )
                              : CustomScrollView(
                                  controller: _activeScrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          12.w,
                                          8.h,
                                          12.w,
                                          0,
                                        ),
                                        child: Column(
                                          children: [
                                            _buildActiveOverview(
                                              transfers,
                                              counts: activeCounts,
                                            ),
                                            SizedBox(height: 8.h),
                                            _buildActiveFilterBar(
                                              transfers,
                                              counts: activeCounts,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (dueCount > 0)
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: EdgeInsets.fromLTRB(
                                            12.w,
                                            8.h,
                                            12.w,
                                            0,
                                          ),
                                          child: _buildDueTransfersBanner(
                                            dueCount,
                                          ),
                                        ),
                                      ),
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          12.w,
                                          8.h,
                                          12.w,
                                          0,
                                        ),
                                        child: RepaintBoundary(
                                          child: _buildMapCard(
                                            filteredTransfers,
                                            selectedTransferId:
                                                selectedTransfer?.id ??
                                                _selectedTransferId,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(
                                        12.w,
                                        16.h,
                                        12.w,
                                        24.h,
                                      ),
                                      sliver: SliverList(
                                        delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                            final transfer =
                                                filteredTransfers[index];
                                            return KeyedSubtree(
                                              key: _cardKeyFor(transfer.id),
                                              child: RepaintBoundary(
                                                child: _buildTransferSummaryCard(
                                                  transfer,
                                                  isSelected:
                                                      transfer.id ==
                                                      (selectedTransfer?.id ??
                                                          _selectedTransferId),
                                                ),
                                              ),
                                            );
                                          },
                                          childCount: filteredTransfers.length,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    )
                  : historyAsync.when(
                      data: (history) {
                        final historyCounts = _countHistoryFilters(history);
                        final filteredHistory = _sortHistory(
                          _applyHistoryFilter(history),
                        );
                        return RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(buyerTransferHistoryProvider);
                          },
                          child: filteredHistory.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                children: [
                                  SizedBox(height: 12.h),
                                  _buildHistoryOverview(history),
                                  SizedBox(height: 12.h),
                                  _buildHistoryFilterBar(
                                    history,
                                    counts: historyCounts,
                                  ),
                                  SizedBox(height: 10.h),
                                  _buildHistorySortBar(),
                                  SizedBox(height: 120.h),
                                  _buildHistoryEmptyState(
                                    hasAnyHistory: history.isNotEmpty,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                controller: _historyScrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  16.w,
                                  12.h,
                                  16.w,
                                  24.h,
                                ),
                                itemCount: filteredHistory.length + 1,
                                itemBuilder: (context, index) =>
                                    index == 0
                                    ? Column(
                                        children: [
                                          _buildHistoryOverview(history),
                                          SizedBox(height: 12.h),
                                          _buildHistoryFilterBar(
                                            history,
                                            counts: historyCounts,
                                          ),
                                          SizedBox(height: 10.h),
                                          _buildHistorySortBar(),
                                          SizedBox(height: 2.h),
                                        ],
                                      )
                                    : _buildHistoryCard(filteredHistory[index - 1]),
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: 12.h),
                              ),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Map<_ActiveTransferFilter, int> _countActiveFilters(
    List<TransferMapItemModel> transfers,
  ) {
    final now = DateTime.now();
    final counts = <_ActiveTransferFilter, int>{
      for (final filter in _ActiveTransferFilter.values) filter: 0,
    };

    for (final transfer in transfers) {
      counts[_ActiveTransferFilter.all] =
          (counts[_ActiveTransferFilter.all] ?? 0) + 1;
      if (transfer.isRental) {
        counts[_ActiveTransferFilter.rental] =
            (counts[_ActiveTransferFilter.rental] ?? 0) + 1;
      } else {
        counts[_ActiveTransferFilter.owned] =
            (counts[_ActiveTransferFilter.owned] ?? 0) + 1;
      }

      final sameCity = _isSameCityTransfer(transfer);
      if (sameCity) {
        counts[_ActiveTransferFilter.sameCity] =
            (counts[_ActiveTransferFilter.sameCity] ?? 0) + 1;
      } else {
        counts[_ActiveTransferFilter.intercity] =
            (counts[_ActiveTransferFilter.intercity] ?? 0) + 1;
      }

      if (transfer.finishAt.difference(now).inMinutes <= 10) {
        counts[_ActiveTransferFilter.urgent] =
            (counts[_ActiveTransferFilter.urgent] ?? 0) + 1;
      }
    }

    return counts;
  }

  Widget _buildActiveFilterBar(
    List<TransferMapItemModel> transfers, {
    Map<_ActiveTransferFilter, int>? counts,
  }) {
    final resolvedCounts = counts ?? _countActiveFilters(transfers);

    return SizedBox(
      height: 32.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final filter = _ActiveTransferFilter.values[index];
          final isSelected = filter == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() {
              _activeFilter = filter;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.55)
                      : AppColors.border.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.gold : Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '${resolvedCounts[filter] ?? 0}',
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.goldLight
                            : AppColors.textMuted,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemCount: _ActiveTransferFilter.values.length,
      ),
    );
  }

  Widget _buildOverviewStrip(List<_OverviewItem> items) {
    return SizedBox(
      height: 72.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 118.w,
            padding: EdgeInsets.fromLTRB(10.w, 9.h, 10.w, 8.h),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: item.color.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: item.color, size: 15.sp),
                SizedBox(height: 6.h),
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildActiveOverview(
    List<TransferMapItemModel> transfers, {
    Map<_ActiveTransferFilter, int>? counts,
  }) {
    final resolvedCounts = counts ?? _countActiveFilters(transfers);

    return _buildOverviewStrip([
      _OverviewItem(
        label: 'Aktif transfer',
        value: '${resolvedCounts[_ActiveTransferFilter.all] ?? transfers.length}',
        color: AppColors.gold,
        icon: Icons.route,
      ),
      _OverviewItem(
        label: 'Yaklasan teslimat',
        value: '${resolvedCounts[_ActiveTransferFilter.urgent] ?? 0}',
        color: AppColors.red,
        icon: Icons.timer_outlined,
      ),
      _OverviewItem(
        label: 'Sehirler arasi',
        value: '${resolvedCounts[_ActiveTransferFilter.intercity] ?? 0}',
        color: AppColors.blue,
        icon: Icons.swap_horiz,
      ),
      _OverviewItem(
        label: 'Kiralik aracli',
        value: '${resolvedCounts[_ActiveTransferFilter.rental] ?? 0}',
        color: Colors.orange,
        icon: Icons.local_shipping_outlined,
      ),
    ]);
  }

  Map<_HistoryTransferFilter, int> _countHistoryFilters(
    List<TransferHistoryItemModel> history,
  ) {
    final counts = <_HistoryTransferFilter, int>{
      for (final filter in _HistoryTransferFilter.values) filter: 0,
    };

    for (final item in history) {
      counts[_HistoryTransferFilter.all] =
          (counts[_HistoryTransferFilter.all] ?? 0) + 1;
      if (item.status == 'completed') {
        counts[_HistoryTransferFilter.completed] =
            (counts[_HistoryTransferFilter.completed] ?? 0) + 1;
      }
      if (item.status == 'cancelled') {
        counts[_HistoryTransferFilter.cancelled] =
            (counts[_HistoryTransferFilter.cancelled] ?? 0) + 1;
      }
      if (item.isRental) {
        counts[_HistoryTransferFilter.rental] =
            (counts[_HistoryTransferFilter.rental] ?? 0) + 1;
      } else {
        counts[_HistoryTransferFilter.owned] =
            (counts[_HistoryTransferFilter.owned] ?? 0) + 1;
      }
    }

    return counts;
  }

  Widget _buildHistoryFilterBar(
    List<TransferHistoryItemModel> history, {
    Map<_HistoryTransferFilter, int>? counts,
  }) {
    final resolvedCounts = counts ?? _countHistoryFilters(history);

    return SizedBox(
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final filter = _HistoryTransferFilter.values[index];
          final isSelected = filter == _historyFilter;
          return GestureDetector(
            onTap: () => setState(() {
              _historyFilter = filter;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.16)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.55)
                      : AppColors.border.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.gold : Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '${resolvedCounts[filter] ?? 0}',
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.goldLight
                            : AppColors.textMuted,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemCount: _HistoryTransferFilter.values.length,
      ),
    );
  }

  Widget _buildHistorySortBar() {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _HistorySortOption.values.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final option = _HistorySortOption.values[index];
          final isSelected = option == _historySort;
          return GestureDetector(
            onTap: () => setState(() {
              _historySort = option;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.blue.withValues(alpha: 0.18)
                    : AppColors.cardBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isSelected
                      ? AppColors.blue.withValues(alpha: 0.55)
                      : AppColors.border.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  color: isSelected ? AppColors.blue : Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryOverview(List<TransferHistoryItemModel> history) {
    final completedCount = history
        .where((item) => item.status == 'completed')
        .length;
    final cancelledCount = history
        .where((item) => item.status == 'cancelled')
        .length;
    final rentalCount = history.where((item) => item.isRental).length;
    final brandedCount = history.where((item) => item.hasBrand).length;
    final totalValue = history.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice + item.transportCost,
    );

    return _buildOverviewStrip([
      _OverviewItem(
        label: 'Gecmis kayit',
        value: '${history.length}',
        color: AppColors.gold,
        icon: Icons.history,
      ),
      _OverviewItem(
        label: 'Tamamlanan',
        value: '$completedCount',
        color: AppColors.green,
        icon: Icons.check_circle_outline,
      ),
      _OverviewItem(
        label: 'Iptal edilen',
        value: '$cancelledCount',
        color: AppColors.red,
        icon: Icons.cancel_outlined,
      ),
      _OverviewItem(
        label: 'Kiralik gecmis',
        value: '$rentalCount',
        color: Colors.orange,
        icon: Icons.local_shipping_outlined,
      ),
      _OverviewItem(
        label: 'Markali',
        value: '$brandedCount',
        color: AppColors.gold,
        icon: Icons.workspace_premium_outlined,
      ),
      _OverviewItem(
        label: 'Toplam hacim',
        value: totalValue.toStringAsFixed(0),
        color: AppColors.blue,
        icon: Icons.payments_outlined,
      ),
    ]);
  }

  Widget _buildDueTransfersBanner(int dueCount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: AppColors.gold, size: 16.sp),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              '$dueCount transfer teslimata hazir. Otomatik tamamlanacak.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TransferMapItemModel> _applyActiveFilter(
    List<TransferMapItemModel> transfers, {
    _ActiveTransferFilter? override,
  }) {
    final filter = override ?? _activeFilter;
    final now = DateTime.now();
    return transfers.where((transfer) {
      switch (filter) {
        case _ActiveTransferFilter.all:
          return true;
        case _ActiveTransferFilter.rental:
          return transfer.isRental;
        case _ActiveTransferFilter.owned:
          return !transfer.isRental;
        case _ActiveTransferFilter.intercity:
          return !_isSameCityTransfer(transfer);
        case _ActiveTransferFilter.sameCity:
          return _isSameCityTransfer(transfer);
        case _ActiveTransferFilter.urgent:
          return transfer.finishAt.difference(now).inMinutes <= 10;
      }
    }).toList();
  }

  void _pruneTransferCardKeys(List<TransferMapItemModel> transfers) {
    final validIds = transfers.map((transfer) => transfer.id).toSet();
    _transferCardKeys.removeWhere((key, _) => !validIds.contains(key));
  }

  List<TransferHistoryItemModel> _applyHistoryFilter(
    List<TransferHistoryItemModel> history, {
    _HistoryTransferFilter? override,
  }) {
    final filter = override ?? _historyFilter;
    return history.where((item) {
      switch (filter) {
        case _HistoryTransferFilter.all:
          return true;
        case _HistoryTransferFilter.completed:
          return item.status == 'completed';
        case _HistoryTransferFilter.cancelled:
          return item.status == 'cancelled';
        case _HistoryTransferFilter.rental:
          return item.isRental;
        case _HistoryTransferFilter.owned:
          return !item.isRental;
      }
    }).toList();
  }

  List<TransferHistoryItemModel> _sortHistory(
    List<TransferHistoryItemModel> history, {
    _HistorySortOption? override,
  }) {
    final sort = override ?? _historySort;
    final items = [...history];
    switch (sort) {
      case _HistorySortOption.newest:
        items.sort((a, b) {
          final aDate = a.completedAt ?? a.finishAt;
          final bDate = b.completedAt ?? b.finishAt;
          return bDate.compareTo(aDate);
        });
        break;
      case _HistorySortOption.oldest:
        items.sort((a, b) {
          final aDate = a.completedAt ?? a.finishAt;
          final bDate = b.completedAt ?? b.finishAt;
          return aDate.compareTo(bDate);
        });
        break;
      case _HistorySortOption.expensive:
        items.sort(
          (a, b) => (b.totalPrice + b.transportCost).compareTo(
            a.totalPrice + a.transportCost,
          ),
        );
        break;
      case _HistorySortOption.longest:
        items.sort(
          (a, b) => b.finishAt
              .difference(b.startedAt)
              .compareTo(a.finishAt.difference(a.startedAt)),
        );
        break;
    }
    return items;
  }

  bool _isSameCityTransfer(TransferMapItemModel transfer) {
    return transfer.sellerWarehouse.city.id == transfer.buyerWarehouse.city.id;
  }

  bool _isLogisticsTransferType(String transferType) {
    return transferType == 'warehouse_to_warehouse' ||
        transferType == 'market_to_warehouse' ||
        transferType == 'warehouse_to_store' ||
        transferType == 'store_to_warehouse' ||
        transferType == 'warehouse_to_production' ||
        transferType == 'production_to_warehouse' ||
        transferType == 'market_to_warehouse_multi' ||
        transferType == 'warehouse_to_warehouse_multi' ||
        transferType == 'warehouse_to_store_multi' ||
        transferType == 'store_to_warehouse_multi' ||
        transferType == 'internal_transfer';
  }

  String _buildDeliveryCompletionMessage(
    List<TransferMapItemModel> dueTransfers,
    int completedCount,
  ) {
    final buyerKinds = dueTransfers
        .take(completedCount <= 0 ? dueTransfers.length : completedCount)
        .map((transfer) => transfer.buyerEndpoint.kind)
        .toSet();

    if (buyerKinds.length == 1) {
      final kind = buyerKinds.first;
      switch (kind) {
        case 'store':
        case 'store_slot':
          return '$completedCount transfer magazaya ulasti.';
        case 'production':
        case 'production_inventory':
          return '$completedCount transfer uretim hattina ulasti.';
        default:
          return '$completedCount transfer depoya ulasti.';
      }
    }

    return '$completedCount transfer hedeflerine ulasti.';
  }

  void _focusTransferCard(
    List<TransferMapItemModel> transfers,
    String transferId,
  ) {
    final index = transfers.indexWhere((item) => item.id == transferId);
    if (index < 0 || !_activeScrollController.hasClients) return;
    final cardContext = _transferCardKeys[transferId]?.currentContext;
    if (cardContext != null) {
      Scrollable.ensureVisible(
        cardContext,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
  }

  GlobalKey _cardKeyFor(String transferId) {
    return _transferCardKeys.putIfAbsent(transferId, GlobalKey.new);
  }

  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeButton(
                index: 0,
                label: 'Aktif',
                icon: Icons.route,
              ),
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: _buildModeButton(
                index: 1,
                label: 'Gecmis',
                icon: Icons.history,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTab == index) return;
        setState(() {
          _selectedTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.3),
                    AppColors.gold.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: isSelected ? AppColors.gold : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard(
    List<TransferMapItemModel> transfers, {
    String? selectedTransferId,
  }) {
    final cities = <TransferMapCityModel>[
      for (final transfer in transfers) transfer.sellerWarehouse.city,
      for (final transfer in transfers) transfer.buyerWarehouse.city,
    ];
    final uniqueCities = <String, TransferMapCityModel>{
      for (final city in cities) city.id: city,
    }.values.toList();
    final cityTransferCounts = <String, int>{};
    for (final transfer in transfers) {
      cityTransferCounts.update(
        transfer.sellerWarehouse.city.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      cityTransferCounts.update(
        transfer.buyerWarehouse.city.id,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    const double minLat = 35.9;
    const double maxLat = 42.7;
    const double minLon = 25.7;
    const double maxLon = 47.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 7.w,
                        height: 7.w,
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Canli Takip',
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 13.sp,
                          color: AppColors.gold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${transfers.length} hat',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final mapHeight = width / 1.35; // Sabit en/boy orani

                    Offset project(TransferMapCityModel city) {
                      final normalizedX = (city.y - minLon) / (maxLon - minLon);
                      final normalizedY = (maxLat - city.x) / (maxLat - minLat);
                      return Offset(
                        normalizedX * width,
                        normalizedY * mapHeight,
                      );
                    }

                    return SizedBox(
                      height: mapHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: const AssetImage('assets/backmap.webp'),
                                  fit: BoxFit.fill,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withValues(alpha: 0.5),
                                    BlendMode.darken,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TransferMapPainter(
                                transfers: transfers,
                                projector: project,
                                selectedTransferId: selectedTransferId,
                              ),
                            ),
                          ),
                          ...uniqueCities.map((city) {
                            final position = project(city);
                            const markerWidth = 80.0;
                            return Positioned(
                              left: position.dx - markerWidth / 2,
                              top: position.dy - 8.w,
                              width: markerWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 16.w,
                                        height: 16.w,
                                        decoration: BoxDecoration(
                                          color: AppColors.gold,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.gold.withValues(
                                                alpha: 0.4,
                                              ),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        right: -10.w,
                                        top: -8.h,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4.w,
                                            vertical: 1.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.red,
                                            borderRadius:
                                                BorderRadius.circular(999.r),
                                          ),
                                          child: Text(
                                            '${cityTransferCounts[city.id] ?? 0}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.8,
                                      ),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      city.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          Positioned.fill(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final now =
                                    ref.watch(secondTickerProvider).value ??
                                    DateTime.now();
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (final transfer in transfers)
                                      _TransferMapMovingMarker(
                                        transfer: transfer,
                                        selectedTransferId: selectedTransferId,
                                        start: project(
                                          transfer.sellerWarehouse.city,
                                        ),
                                        end: project(
                                          transfer.buyerWarehouse.city,
                                        ),
                                        progress: _calculateProgress(
                                          transfer,
                                          now: now,
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _selectedTransferId = transfer.id;
                                          });
                                          _focusTransferCard(
                                            transfers,
                                            transfer.id,
                                          );
                                          _showTransferInfo(transfer);
                                        },
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferSummaryCard(
    TransferMapItemModel transfer, {
    bool isSelected = false,
  }) {
    final accentColor = transfer.isRental ? Colors.orange : AppColors.gold;
    final sameCity = _isSameCityTransfer(transfer);
    final routeDistanceKm = _estimateRouteDistanceKm(
      transfer.sellerWarehouse.city,
      transfer.buyerWarehouse.city,
    );
    final totalCost = transfer.totalPrice + transfer.transportCost;
    final unitLogisticsCost = transfer.displayQuantity > 0
        ? transfer.transportCost / transfer.displayQuantity
        : 0.0;
    final logisticsLabel = transfer.isRental
        ? 'Nakliye ${_formatCurrency(unitLogisticsCost)} / adet'
        : 'Ozmal transfer';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTransferId = transfer.id;
        });
        final currentTransfers = _applyActiveFilter(
          ref.read(buyerTransferMapProvider).value ?? const [],
        );
        _focusTransferCard(currentTransfers, transfer.id);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? AppColors.blue.withValues(alpha: 0.8)
                : AppColors.borderGold.withValues(alpha: 0.2),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? AppColors.blue : Colors.black).withValues(
                alpha: isSelected ? 0.16 : 0.2,
              ),
              blurRadius: isSelected ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: BrandedProductImage(
                  fileName: transfer.product.icon,
                  brandName: transfer.brandName,
                  fit: BoxFit.contain,
                  showFrame: false,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          transfer.displayTitle,
                          style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            transfer.isRental ? 'Kiralik' : 'Ozmal',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        _buildTransferChip(
                          sameCity ? 'Ayni Sehir' : 'Sehirler Arasi',
                          sameCity ? AppColors.green : AppColors.blue,
                        ),
                        if (isSelected) ...[
                          SizedBox(width: 6.w),
                          _buildTransferChip('Odakta', AppColors.blue),
                        ],
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${transfer.sellerWarehouse.city.name} -> ${transfer.buyerWarehouse.city.name}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12.sp,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${transfer.sellerWarehouse.name} -> ${transfer.buyerWarehouse.name}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildInlineMetaChip(
                '${transfer.sellerKindLabel} -> ${transfer.buyerKindLabel}',
                AppColors.gold,
              ),
              if (!transfer.isMultiItem)
                _buildInlineMetaChip(
                  _buildQualityBrandSummary(
                    qualityLevel: transfer.qualityLevel,
                    hasBrand: transfer.hasBrand,
                  ),
                  Colors.white,
                ),
              _buildInlineMetaChip(
                '${routeDistanceKm.toStringAsFixed(0)} km',
                sameCity ? AppColors.green : AppColors.blue,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            ),
            child: _TransferLiveMeta(
              transfer: transfer,
              accentColor: accentColor,
              formatRemaining: _formatRemaining,
              formatDateTime: _formatDateTime,
            ),
          ),
          SizedBox(height: 12.h),
          _buildCompactMetaRow(
            leftIcon: Icons.inventory_2_outlined,
            leftText: '${transfer.displayQuantity} adet',
            rightIcon: Icons.payments_outlined,
            rightText: _formatCurrency(transfer.totalPrice),
          ),
          SizedBox(height: 6.h),
          _buildCompactMetaRow(
            leftIcon: Icons.local_shipping_outlined,
            leftText: _formatCurrency(transfer.transportCost + transfer.rentalCost),
            rightIcon: transfer.isRental
                ? Icons.local_shipping_outlined
                : Icons.directions_car_outlined,
            rightText: logisticsLabel,
          ),
          if (transfer.isMultiItem) ...[
            SizedBox(height: 6.h),
            _buildCompactMetaRow(
              leftIcon: Icons.payments_outlined,
              leftText: _formatCurrency(totalCost),
              rightIcon: Icons.list_alt_outlined,
              rightText: '${transfer.itemCount} kalem',
            ),
          ],
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: _TransferProgressBar(
              transfer: transfer,
              accentColor: accentColor,
              calculateProgress: _calculateProgress,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${transfer.sellerWarehouse.name} -> ${transfer.buyerWarehouse.name}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.sp,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedTransferId = transfer.id;
                  });
                  final currentTransfers = _applyActiveFilter(
                    ref.read(buyerTransferMapProvider).value ?? const [],
                  );
                  _focusTransferCard(currentTransfers, transfer.id);
                  _showTransferInfo(transfer);
                },
                icon: Icon(Icons.open_in_full, size: 14.sp, color: AppColors.gold),
                label: Text(
                  'Detay',
                  style: TextStyle(color: AppColors.gold, fontSize: 12.sp),
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetaRow({
    required IconData leftIcon,
    required String leftText,
    required IconData rightIcon,
    required String rightText,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildMetaLine(leftIcon, leftText),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildMetaLine(rightIcon, rightText),
        ),
      ],
    );
  }

  Widget _buildMetaLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 12.sp),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool hasAnyTransfers}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.route_outlined,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: 54.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Aktif Transfer Yok',
            style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            hasAnyTransfers
                ? 'Secili filtrede gosterilecek aktif transfer yok. Farkli bir filtre secerek tekrar bakabilirsiniz.'
                : 'Marketten satin aldiginiz urunler yola ciktiginda veya bir satisa gonderdiginizde burada canli olarak takip edebilirsiniz.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (hasAnyTransfers) ...[
            SizedBox(height: 18.h),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _activeFilter = _ActiveTransferFilter.all;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
              ),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Filtreyi Temizle'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState({required bool hasAnyHistory}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_outlined,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: 54.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Gecmis Kayit Bulunamadi',
            style: AppTextStyles.h2.copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            hasAnyHistory
                ? 'Secili filtre icin gecmis kaydi bulunamadi. Farkli bir filtre ile tekrar deneyin.'
                : 'Tamamlanan veya iptal edilen tum sevkiyatlariniz burada loglanacaktir.',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (hasAnyHistory) ...[
            SizedBox(height: 18.h),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _historyFilter = _HistoryTransferFilter.all;
                  _historySort = _HistorySortOption.newest;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
              ),
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('Filtreleri Sifirla'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TransferHistoryItemModel item) {
    final statusColor = item.status == 'completed'
        ? AppColors.green
        : Colors.orange;
    final completedText = item.completedAt == null
        ? '-'
        : _formatDateTime(item.completedAt!);
    final totalMinutes = item.finishAt.difference(item.startedAt).inMinutes;
    final unitLogisticsCost = item.displayQuantity > 0
        ? item.transportCost / item.displayQuantity
        : 0.0;
    final totalCost = item.totalPrice + item.transportCost;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: BrandedProductImage(
                  fileName: item.product.icon,
                  brandName: item.brandName,
                  fit: BoxFit.contain,
                  showFrame: false,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayTitle,
                      style: AppTextStyles.h2.copyWith(fontSize: 16.sp),
                    ),
                    Text(
                      '${item.sellerWarehouse.city.name} -> ${item.buyerWarehouse.city.name}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 11.sp,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${item.sellerWarehouse.name} -> ${item.buyerWarehouse.name}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTransferChip(_statusLabel(item.status), statusColor),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _buildInlineMetaChip(
                '${item.sellerKind} -> ${item.buyerKind}',
                AppColors.gold,
              ),
              if (!item.isMultiItem)
                _buildInlineMetaChip(
                  _buildQualityBrandSummary(
                    qualityLevel: item.qualityLevel,
                    hasBrand: item.hasBrand,
                  ),
                  Colors.white,
                ),
              _buildInlineMetaChip('${totalMinutes} dk', statusColor),
            ],
          ),
          SizedBox(height: 12.h),
          _buildCompactMetaRow(
            leftIcon: Icons.inventory_2_outlined,
            leftText: '${item.displayQuantity} adet',
            rightIcon: Icons.payments_outlined,
            rightText: _formatCurrency(item.totalPrice),
          ),
          SizedBox(height: 6.h),
          _buildCompactMetaRow(
            leftIcon: Icons.local_shipping_outlined,
            leftText: _formatCurrency(item.transportCost + item.rentalCost),
            rightIcon: item.isRental
                ? Icons.local_shipping_outlined
                : Icons.directions_car_outlined,
            rightText: item.isRental
                ? '${_formatCurrency(unitLogisticsCost)} / adet'
                : 'Ozmal transfer',
          ),
          if (item.isMultiItem) ...[
            SizedBox(height: 6.h),
            _buildCompactMetaRow(
              leftIcon: Icons.payments_outlined,
              leftText: _formatCurrency(totalCost),
              rightIcon: Icons.list_alt_outlined,
              rightText: '${item.itemCount} kalem',
            ),
          ],
          SizedBox(height: 6.h),
          _buildMetaLine(Icons.event_outlined, completedText),
        ],
      ),
    );
  }

  double _calculateProgress(
    TransferMapItemModel transfer, {
    DateTime? now,
  }) {
    final total = transfer.finishAt.difference(transfer.startedAt).inSeconds;
    if (total <= 0) return 1;
    final elapsed = (now ?? DateTime.now())
        .difference(transfer.startedAt)
        .inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  double _estimateRouteDistanceKm(
    TransferMapCityModel from,
    TransferMapCityModel to,
  ) {
    const kmPerLat = 111.0;
    final avgLatRadians = ((from.x + to.x) / 2) * 0.0174533;
    final kmPerLon = 111.0 * math.cos(avgLatRadians);
    final dx = (to.y - from.y) * kmPerLon;
    final dy = (to.x - from.x) * kmPerLat;
    return math.sqrt(dx * dx + dy * dy);
  }

  String _formatRemaining(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatDateTime(DateTime value) {
    final safe = value.toLocal();
    final day = safe.day.toString().padLeft(2, '0');
    final month = safe.month.toString().padLeft(2, '0');
    final hour = safe.hour.toString().padLeft(2, '0');
    final minute = safe.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Tamamlandi';
      case 'cancelled':
        return 'Iptal';
      default:
        return status;
    }
  }

  String _formatCurrency(double value) {
    return '${value.toStringAsFixed(1)} TL';
  }

  String _buildQualityBrandSummary({
    required int qualityLevel,
    required bool hasBrand,
  }) {
    final brandLabel = hasBrand ? 'Markali' : 'Brandsiz';
    return 'Q$qualityLevel | $brandLabel';
  }

  Widget _buildInlineMetaChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

}

class _TransferLiveMeta extends ConsumerWidget {
  final TransferMapItemModel transfer;
  final Color accentColor;
  final String Function(Duration duration) formatRemaining;
  final String Function(DateTime value) formatDateTime;

  const _TransferLiveMeta({
    required this.transfer,
    required this.accentColor,
    required this.formatRemaining,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final remaining = transfer.finishAt.difference(now);

    return Row(
      children: [
        Icon(Icons.schedule, color: accentColor, size: 16.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Kalan Sure: ${formatRemaining(remaining)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          'Varis ${formatDateTime(transfer.finishAt)}',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }

}

class _TransferProgressBar extends ConsumerWidget {
  final TransferMapItemModel transfer;
  final Color accentColor;
  final double Function(TransferMapItemModel transfer, {DateTime? now})
  calculateProgress;

  const _TransferProgressBar({
    required this.transfer,
    required this.accentColor,
    required this.calculateProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final progress = calculateProgress(transfer, now: now);

    return LinearProgressIndicator(
      value: progress,
      backgroundColor: Colors.black.withValues(alpha: 0.3),
      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
      minHeight: 6.h,
    );
  }
}

class _TransferMapMovingMarker extends StatelessWidget {
  final TransferMapItemModel transfer;
  final String? selectedTransferId;
  final Offset start;
  final Offset end;
  final double progress;
  final VoidCallback onTap;

  const _TransferMapMovingMarker({
    required this.transfer,
    required this.selectedTransferId,
    required this.start,
    required this.end,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final position = Offset.lerp(start, end, progress)!;
    final isSelected = transfer.id == selectedTransferId;
    final color = isSelected
        ? AppColors.blue
        : transfer.isRental
        ? Colors.orange
        : AppColors.gold;

    return Positioned(
      left: position.dx - 15.w,
      top: position.dy - 15.w,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            transfer.isRental ? Icons.local_shipping : Icons.directions_car,
            color: transfer.isRental ? Colors.orange : AppColors.gold,
            size: 15.sp,
          ),
        ),
      ),
    );
  }
}

class _TransferMapPainter extends CustomPainter {
  final List<TransferMapItemModel> transfers;
  final Offset Function(TransferMapCityModel city) projector;
  final String? selectedTransferId;

  _TransferMapPainter({
    required this.transfers,
    required this.projector,
    this.selectedTransferId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dot grid background
    final bgPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    for (double i = 0; i < size.width; i += 20) {
      for (double j = 0; j < size.height; j += 20) {
        canvas.drawCircle(Offset(i, j), 1, bgPaint);
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (final transfer in transfers) {
      final start = projector(transfer.sellerWarehouse.city);
      final end = projector(transfer.buyerWarehouse.city);
      final isSelected = transfer.id == selectedTransferId;
      linePaint
        ..color = isSelected
            ? AppColors.blue.withValues(alpha: 0.85)
            : transfer.isRental
            ? Colors.orange.withValues(alpha: 0.6)
            : AppColors.gold.withValues(alpha: 0.6)
        ..strokeWidth = isSelected ? 4 : 2.5;

      _drawDashedLine(canvas, start, end, linePaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    var distance = (p2 - p1).distance;
    var direction = (p2 - p1) / distance;

    var start = p1;
    while (distance >= 0) {
      var next = start + direction * dashWidth;
      if (distance < dashWidth) {
        next = p1 + direction * (p2 - p1).distance;
      }
      canvas.drawLine(start, next, paint);
      start = next + direction * dashSpace;
      distance -= dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _TransferMapPainter oldDelegate) {
    if (selectedTransferId != oldDelegate.selectedTransferId) {
      return true;
    }
    if (transfers.length != oldDelegate.transfers.length) {
      return true;
    }
    for (var i = 0; i < transfers.length; i++) {
      final current = transfers[i];
      final previous = oldDelegate.transfers[i];
      if (current.id != previous.id ||
          current.isRental != previous.isRental ||
          current.sellerWarehouse.city.id != previous.sellerWarehouse.city.id ||
          current.buyerWarehouse.city.id != previous.buyerWarehouse.city.id) {
        return true;
      }
    }
    return false;
  }
}

class _OverviewItem {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _OverviewItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}


