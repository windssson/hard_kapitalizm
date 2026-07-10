import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_history_item_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/transfer_map_item_model.dart';
import 'package:hard_kapitalizm/core/widgets/gold_finish_button.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';

class TransferMapScreen extends ConsumerStatefulWidget {
  const TransferMapScreen({super.key});

  @override
  ConsumerState<TransferMapScreen> createState() => _TransferMapScreenState();
}

class _TransferMapScreenState extends ConsumerState<TransferMapScreen> {
  final int _selectedIndex = 2;
  int _selectedTab = 0;
  String? _selectedTransferId;
  String? _expandedHistoryId;
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final Map<String, GlobalKey> _transferCardKeys = {};

  @override
  void dispose() {
    _activeScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
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


  String _transferTitle({
    required bool isMultiItem,
    required String productName,
    required int itemCount,
  }) {
    if (!isMultiItem) return productName;
    return 'Coklu Sevkiyat ($itemCount kalem)';
  }

  String _transferQuantitySummary({
    required int quantity,
    required bool isMultiItem,
    required int itemCount,
  }) {
    if (!isMultiItem) return '$quantity adet';
    return '$quantity adet | $itemCount kalem';
  }

  String _transferRouteSummary({
    required String sourceName,
    required String sourceKind,
    required String targetName,
    required String targetKind,
  }) {
    return '$sourceKind: $sourceName -> $targetKind: $targetName';
  }

  Widget _buildTransferAvatar({
    required bool isMultiItem,
    required String productIcon,
    required String? brandName,
    required int itemCount,
    required Color accentColor,
    String? brandId,
    String? productId,
  }) {
    return Container(
      width: 48.w,
      height: 48.w,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: isMultiItem
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    AppIcons.inventory2Outlined,
                    color: accentColor,
                    size: AppIconSizes.mediumLarge,
                  ),
                ),
                Positioned(
                  right: -4.w,
                  top: -4.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 5.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '$itemCount',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textOnAccent,
                        fontSize: AppTypography.caption,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : BrandedProductImage(
              fileName: productIcon,
              brandId: brandId,
              brandName: brandName,
              productId: productId,
              fit: BoxFit.contain,
              showFrame: false,
            ),
    );
  }

  Future<void> _showTransferInfo(TransferMapItemModel transfer) async {
    final accentColor = transfer.isRental ? AppColors.warning : AppColors.gold;
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
                                ? AppIcons.localShipping
                                : AppIcons.directionsCar,
                            color: accentColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _transferTitle(
                                  isMultiItem: transfer.isMultiItem,
                                  productName: transfer.product.name,
                                  itemCount: transfer.itemCount,
                                ),
                                style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.headline),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Transfer Detaylari',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: AppTypography.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            AppIcons.closeRounded,
                            color: AppColors.textMuted,
                            size: AppIconSizes.medium,
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
                                color: AppFx.panelWash(0.2),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: AppFx.softOverlay(0.05),
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildDialogInfoRow(
                                    AppIcons.myLocation,
                                    'Cikis (${transfer.sellerKindLabel})',
                                    '${transfer.sellerWarehouse.name} | ${transfer.sellerWarehouse.city.name}',
                                  ),
                                  Divider(
                                    color: AppFx.softOverlay(0.1),
                                    height: 22.h,
                                  ),
                                  _buildDialogInfoRow(
                                    AppIcons.locationOn,
                                    'Varis (${transfer.buyerKindLabel})',
                                    '${transfer.buyerWarehouse.name} | ${transfer.buyerWarehouse.city.name}',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 14.h),
                            _buildDialogDetailRow(
                              'Miktar',
                              _transferQuantitySummary(
                                quantity: transfer.displayQuantity,
                                isMultiItem: transfer.isMultiItem,
                                itemCount: transfer.itemCount,
                              ),
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
                                    AppIcons.timerOutlined,
                                    color: accentColor,
                                    size: AppIconSizes.compact,
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      'Kalan Sure: ${_formatRemaining(remaining)}',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.body.standardCopyWith(
                                        color: accentColor,
                                        fontSize: AppTypography.title,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (remaining.inSeconds > 0) ...[
                              SizedBox(height: 12.h),
                              GoldFinishButton(
                                starCost: (remaining.inSeconds / 600.0).ceil(),
                                onPressed: () {
                                  final starCost = (remaining.inSeconds / 600.0).ceil();
                                  _confirmFinishWithStars(
                                    context,
                                    ref,
                                    transfer,
                                    starCost,
                                  );
                                },
                              ),
                            ],
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
        title: 'Yetersiz Yıldız',
        message: 'Bu işlemi gerçekleştirmek için yeterli yıldızınız yok. Gerekli: $starCost, Mevcut: ${currentGold.toInt()}',
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
            Icon(AppIcons.starRounded, color: AppColors.gold, size: AppIconSizes.large),
            SizedBox(width: 8.w),
            Text(
              'Hemen Bitir',
              style: AppTextStyles.body.standardCopyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Bu transferi $starCost ⭐ harcayarak anında tamamlamak istiyor musunuz?\n\nMevcut Yıldızınız: ${currentGold.toInt()}',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgeç',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.title,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.textOnAccent,
            ),
            child: Text(
              'Tamamla',
              style: AppTextStyles.body.standardCopyWith(
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
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
      builder: (context) => Center(
        child: AppLoadingIndicator(
          color: AppColors.gold,
        ),
      ),
    );

    try {
      final result = await ref
          .read(warehouseActionProvider)
          .finishLogisticsTransferWithGold(transfer.id);

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
        ref.invalidate(warehouseListProvider);
        _invalidateAffectedTransferTargets(transfer);

        if (context.mounted) {
          AppSnackbar.show(
            context,
            title: 'Başarılı',
            message: 'Transfer yıldız kullanılarak anında tamamlandı!',
            type: SnackbarType.success,
          );
        }
      } else {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message: result['message'] ?? 'Transfer tamamlanırken bir hata oluştu.',
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

  void _invalidateAffectedTransferTargets(TransferMapItemModel transfer) {
    try {
      final buyerId = transfer.buyerEndpoint.id;
      final kind = transfer.buyerEndpoint.kind;
      if (buyerId.isNotEmpty) {
        if (kind == 'warehouse') {
          ref.invalidate(warehouseDetailProvider(buyerId));
        } else if (kind == 'store' || kind == 'store_slot') {
          ref.invalidate(storeDetailPageProvider(buyerId));
        }
      }
    } catch (_) {}
  }
  Widget _buildDialogInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.gold, size: AppIconSizes.compact),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.bodyLarge,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
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
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodyLarge,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.title,
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
    return Scaffold(
      backgroundColor: AppColors.transparent,
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
                        TransferMapItemModel? selectedTransfer;
                        if (transfers.isNotEmpty) {
                          for (final item in transfers) {
                            if (item.id == _selectedTransferId) {
                              selectedTransfer = item;
                              break;
                            }
                          }
                          selectedTransfer ??= transfers.first;
                        }
                        final dueCount = transfers
                            .where(
                              (transfer) =>
                                  !transfer.finishAt.isAfter(DateTime.now()),
                            )
                            .length;

                        return RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(buyerTransferMapProvider);
                            ref.invalidate(buyerTransferHistoryProvider);
                          },
                          child: transfers.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  children: [
                                    SizedBox(height: 120.h),
                                    _buildEmptyState(),
                                  ],
                                )
                              : CustomScrollView(
                                  controller: _activeScrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: [
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
                                            transfers,
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
                                                transfers[index];
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
                                          childCount: transfers.length,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        );
                      },
                      loading: () => Center(
                        child: AppLoadingIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    )
                  : historyAsync.when(
                      data: (history) {
                        final sortedHistory = [...history]..sort((a, b) {
                            final aDate = a.completedAt ?? a.finishAt;
                            final bDate = b.completedAt ?? b.finishAt;
                            return bDate.compareTo(aDate);
                          });

                        return RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(buyerTransferHistoryProvider);
                          },
                          child: sortedHistory.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                children: [
                                  SizedBox(height: 120.h),
                                  _buildHistoryEmptyState(),
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
                                itemCount: sortedHistory.length,
                                itemBuilder: (context, index) =>
                                    _buildHistoryCard(sortedHistory[index]),
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: 12.h),
                              ),
                        );
                      },
                      loading: () => Center(
                        child: AppLoadingIndicator(color: AppColors.gold),
                      ),
                      error: (error, stack) => Center(
                        child: Text(
                          'Hata: ${error.toString()}',
                          style: AppTextStyles.body.standardCopyWith(
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
          Icon(AppIcons.notificationsActive, color: AppColors.gold, size: AppIconSizes.compact),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              '$dueCount transfer teslimata hazir. Otomatik tamamlanacak.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.label,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameCityTransfer(TransferMapItemModel transfer) {
    return transfer.sellerWarehouse.city.id == transfer.buyerWarehouse.city.id;
  }

  void _pruneTransferCardKeys(List<TransferMapItemModel> transfers) {
    final validIds = transfers.map((transfer) => transfer.id).toSet();
    _transferCardKeys.removeWhere((key, _) => !validIds.contains(key));
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
        color: AppFx.panelWash(0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.2),
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
                icon: AppIcons.route,
              ),
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: _buildModeButton(
                index: 1,
                label: 'Gecmis',
                icon: AppIcons.history,
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
          color: isSelected ? null : AppColors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.5)
                : AppColors.transparent,
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
              size: AppIconSizes.compact,
              color: isSelected ? AppColors.gold : AppColors.textMuted,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: AppTypography.body,
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
            color: AppFx.panelWash(0.2),
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
                      AppFx.softOverlay(0.05),
                      AppColors.transparent,
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
                        style: AppTextStyles.h2.standardCopyWith(
                          fontSize: AppTypography.bodyLarge,
                          color: AppColors.gold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${transfers.length} sevkiyat',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.label,
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
                                    AppFx.panelWash(0.5),
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
                                            color: AppColors.textPrimary,
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
                                            style: AppTextStyles.caption.standardCopyWith(
                                              color: AppColors.textPrimary,
                                              fontSize: AppTypography.micro,
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
                                      color: AppFx.panelWash(0.8),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      city.name,
                                      style: AppTextStyles.caption.standardCopyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: AppTypography.micro,
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
    final accentColor = transfer.isRental ? AppColors.warning : AppColors.gold;
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
        final currentTransfers =
            ref.read(buyerTransferMapProvider).value ?? const [];
        _focusTransferCard(currentTransfers, transfer.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? AppColors.blue.withValues(alpha: 0.8)
                : AppColors.borderGold.withValues(alpha: 0.15),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.blue.withValues(alpha: 0.16)
                  : AppFx.panelWash(0.2),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Always Visible)
            Row(
              children: [
                _buildTransferAvatar(
                  isMultiItem: transfer.isMultiItem,
                  productIcon: transfer.product.icon,
                  brandName: transfer.brandName,
                  itemCount: transfer.itemCount,
                  accentColor: accentColor,
                  brandId: transfer.brandId,
                  productId: transfer.product.id,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _transferTitle(
                                isMultiItem: transfer.isMultiItem,
                                productName: transfer.product.name,
                                itemCount: transfer.itemCount,
                              ),
                              style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.title),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          _buildTransferChip(
                            transfer.isRental ? 'Kiralık' : 'Özmal',
                            accentColor,
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${transfer.sellerWarehouse.city.name} ➔ ${transfer.buyerWarehouse.city.name}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8.h),
            
            // Collapsed view progress & remaining time (Compact)
            if (!isSelected) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: _TransferProgressBar(
                        transfer: transfer,
                        accentColor: accentColor,
                        calculateProgress: _calculateProgress,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Consumer(
                    builder: (context, ref, _) {
                      final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
                      final remaining = transfer.finishAt.difference(now);
                      return Text(
                        _formatRemaining(remaining),
                        style: AppTextStyles.body.standardCopyWith(
                          color: accentColor,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],

            // Expanded view details
            if (isSelected) ...[
              Divider(
                color: AppFx.softOverlay(0.08),
                height: 16.h,
              ),
              
              Text(
                _transferRouteSummary(
                  sourceName: transfer.sellerWarehouse.name,
                  sourceKind: transfer.sellerKindLabel,
                  targetName: transfer.buyerWarehouse.name,
                  targetKind: transfer.buyerKindLabel,
                ),
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodySmall,
                ),
                maxLines: 2,
              ),
              SizedBox(height: 8.h),
              
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  _buildInlineMetaChip(
                    '${transfer.sellerKindLabel} ➔ ${transfer.buyerKindLabel}',
                    AppColors.gold,
                  ),
                  if (!transfer.isMultiItem)
                    _buildInlineMetaChip(
                      _buildQualityBrandSummary(
                        qualityLevel: transfer.qualityLevel,
                        hasBrand: transfer.hasBrand,
                      ),
                      AppColors.textPrimary,
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
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: accentColor.withValues(alpha: 0.18)),
                ),
                child: _TransferLiveMeta(
                  transfer: transfer,
                  accentColor: accentColor,
                  formatRemaining: _formatRemaining,
                  formatDateTime: _formatDateTime,
                ),
              ),
              SizedBox(height: 10.h),
              
              _buildCompactMetaRow(
                leftIcon: AppIcons.inventory2Outlined,
                leftText: _transferQuantitySummary(
                  quantity: transfer.displayQuantity,
                  isMultiItem: transfer.isMultiItem,
                  itemCount: transfer.itemCount,
                ),
                rightIcon: AppIcons.paymentsOutlined,
                rightText: _formatCurrency(transfer.totalPrice),
              ),
              SizedBox(height: 6.h),
              _buildCompactMetaRow(
                leftIcon: AppIcons.localShippingOutlined,
                leftText: _formatCurrency(transfer.transportCost + transfer.rentalCost),
                rightIcon: transfer.isRental
                    ? AppIcons.localShippingOutlined
                    : AppIcons.directionsCarOutlined,
                rightText: logisticsLabel,
              ),
              if (transfer.isMultiItem) ...[
                SizedBox(height: 6.h),
                _buildCompactMetaRow(
                  leftIcon: AppIcons.paymentsOutlined,
                  leftText: _formatCurrency(totalCost),
                  rightIcon: AppIcons.listAltOutlined,
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
              SizedBox(height: 6.h),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showTransferInfo(transfer),
                    icon: Icon(AppIcons.openInFull, size: AppIconSizes.small, color: AppColors.gold),
                    label: Text(
                      'Tüm İrsaliye Detayları',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.gold,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
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
        Icon(icon, color: AppColors.textMuted, size: AppIconSizes.xSmall),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySmall,
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
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.2),
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
              color: AppFx.softOverlay(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.routeOutlined,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: AppIconSizes.hero,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Aktif Transfer Yok',
            style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.headline),
          ),
          SizedBox(height: 12.h),
          Text(
            'Marketten satın aldığınız ürünler yola çıktığında veya bir satışa gönderdiğinizde burada canlı olarak takip edebilirsiniz.',
            style: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppFx.panelWash(0.2),
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
              color: AppFx.softOverlay(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.historyOutlined,
              color: AppColors.gold.withValues(alpha: 0.5),
              size: AppIconSizes.hero,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Geçmiş Kayıt Bulunamadı',
            style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.headline),
          ),
          SizedBox(height: 12.h),
          Text(
            'Tamamlanan veya iptal edilen tüm sevkiyatlarınız burada loglanacaktır.',
            style: AppTextStyles.body.standardCopyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TransferHistoryItemModel item) {
    final isExpanded = item.id == _expandedHistoryId;
    final statusColor = item.status == 'completed'
        ? AppColors.green
        : AppColors.warning;
    final completedText = item.completedAt == null
        ? '-'
        : _formatDateTime(item.completedAt!);
    final totalMinutes = item.finishAt.difference(item.startedAt).inMinutes;
    final unitLogisticsCost = item.displayQuantity > 0
        ? item.transportCost / item.displayQuantity
        : 0.0;
    final totalCost = item.totalPrice + item.transportCost;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedHistoryId = isExpanded ? null : item.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isExpanded
                ? statusColor.withValues(alpha: 0.8)
                : AppColors.borderGold.withValues(alpha: 0.1),
            width: isExpanded ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppFx.panelWash(0.15),
              blurRadius: isExpanded ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTransferAvatar(
                  isMultiItem: item.isMultiItem,
                  productIcon: item.product.icon,
                  brandName: item.brandName,
                  itemCount: item.itemCount,
                  accentColor: statusColor,
                  brandId: item.brandId,
                  productId: item.product.id,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _transferTitle(
                                isMultiItem: item.isMultiItem,
                                productName: item.product.name,
                                itemCount: item.itemCount,
                              ),
                              style: AppTextStyles.h2.standardCopyWith(fontSize: AppTypography.title),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          _buildTransferChip(_statusLabel(item.status), statusColor),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${item.sellerWarehouse.city.name} ➔ ${item.buyerWarehouse.city.name}',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 8.h),
            
            // Collapsed view summary
            if (!isExpanded) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Süre: $totalMinutes dk',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Tamamlandı: $completedText',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ],

            // Expanded view details
            if (isExpanded) ...[
              Divider(
                color: AppFx.softOverlay(0.08),
                height: 16.h,
              ),
              
              Text(
                _transferRouteSummary(
                  sourceName: item.sellerWarehouse.name,
                  sourceKind: item.sellerKind,
                  targetName: item.buyerWarehouse.name,
                  targetKind: item.buyerKind,
                ),
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.bodySmall,
                ),
                maxLines: 2,
              ),
              SizedBox(height: 8.h),
              
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: [
                  _buildInlineMetaChip(
                    '${item.sellerKind} ➔ ${item.buyerKind}',
                    AppColors.gold,
                  ),
                  if (!item.isMultiItem)
                    _buildInlineMetaChip(
                      _buildQualityBrandSummary(
                        qualityLevel: item.qualityLevel,
                        hasBrand: item.hasBrand,
                      ),
                      AppColors.textPrimary,
                    ),
                  _buildInlineMetaChip('$totalMinutes dk', statusColor),
                ],
              ),
              SizedBox(height: 12.h),
              
              _buildCompactMetaRow(
                leftIcon: AppIcons.inventory2Outlined,
                leftText: _transferQuantitySummary(
                  quantity: item.displayQuantity,
                  isMultiItem: item.isMultiItem,
                  itemCount: item.itemCount,
                ),
                rightIcon: AppIcons.paymentsOutlined,
                rightText: _formatCurrency(item.totalPrice),
              ),
              SizedBox(height: 6.h),
              _buildCompactMetaRow(
                leftIcon: AppIcons.localShippingOutlined,
                leftText: _formatCurrency(item.transportCost + item.rentalCost),
                rightIcon: item.isRental
                    ? AppIcons.localShippingOutlined
                    : AppIcons.directionsCarOutlined,
                rightText: item.isRental
                    ? '${_formatCurrency(unitLogisticsCost)} / adet'
                    : 'Ozmal transfer',
              ),
              if (item.isMultiItem) ...[
                SizedBox(height: 6.h),
                _buildCompactMetaRow(
                  leftIcon: AppIcons.paymentsOutlined,
                  leftText: _formatCurrency(totalCost),
                  rightIcon: AppIcons.listAltOutlined,
                  rightText: '${item.itemCount} kalem',
                ),
              ],
              SizedBox(height: 8.h),
              _buildMetaLine(AppIcons.eventOutlined, 'Bitiş Tarihi: $completedText'),
            ],
          ],
        ),
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
    return AppMoney.full(value, decimals: 1);
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
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
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
        Icon(AppIcons.schedule, color: accentColor, size: AppIconSizes.compact),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'Kalan Sure: ${formatRemaining(remaining)}',
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          'Varis ${formatDateTime(transfer.finishAt)}',
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
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

    return AppProgressBar(
      value: progress,
      backgroundColor: AppFx.panelWash(0.3),
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
        ? AppColors.warning
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  transfer.isRental ? AppIcons.localShipping : AppIcons.directionsCar,
                  color: transfer.isRental ? AppColors.warning : AppColors.gold,
                  size: AppIconSizes.small,
                ),
              ),
              if (transfer.isMultiItem)
                Positioned(
                  right: -4.w,
                  top: -4.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.h,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      '${transfer.itemCount}',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textOnAccent,
                        fontSize: AppTypography.micro,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
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
            ? AppColors.warning.withValues(alpha: 0.6)
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




