import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_detail_page_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';
import 'package:hard_kapitalizm/features/store/ui/widgets/store_detail_header.dart';
import 'package:hard_kapitalizm/features/store/ui/widgets/store_quick_actions.dart';

class StoreDetailScreen extends ConsumerStatefulWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen> {
  String? _lastShownSalesResultKey;
  static const Map<int, int> _storeBoostStarCosts = {
    6: 3,
    12: 6,
    24: 12,
  };

  @override
  void initState() {
    super.initState();
    _lastShownSalesResultKey = null;
  }



  void _onNavSelected(int index) {
    if (index == 1) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 2:
        context.go('/transfer-map');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeDetailPageProvider(widget.storeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: storeAsync.when(
          data: (page) {
            _scheduleSalesSummaryDialog(page);
            return _buildMainContent(context, ref, page);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, s) => _buildErrorState(ref, e),
        ),
      ),
    );
  }

  void _scheduleSalesSummaryDialog(StoreDetailPageModel page) {
    ref.read(storeHistoryDirtyProvider(page.store.id).notifier).state =
        page.changed.historyDirty;
    ref.read(storePerformanceDirtyProvider(page.store.id).notifier).state =
        page.changed.performanceDirty;

    final result = page.saleResult;
    if (result == null || !result.processed || !result.hasVisibleSales) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final resultKey =
          '${page.store.id}_${result.processedAt?.toIso8601String() ?? 'no_time'}_${result.totalSoldQuantity}_${result.totalRevenue}';
      if (_lastShownSalesResultKey == resultKey) {
        return;
      }
      _lastShownSalesResultKey = resultKey;

      if (result.success != true && (result.message ?? '').trim().isNotEmpty) {
        AppSnackbar.show(
          context,
          title: 'Satis Hesaplanamadi',
          message: result.message!,
          type: SnackbarType.error,
        );
        return;
      }

      await _showStoreSalesSummaryDialog(context, result);
    });
  }

  Future<void> _showStoreSalesSummaryDialog(
    BuildContext context,
    StoreSaleResultModel result,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Satis Ozeti',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 420.h, maxWidth: 340.w),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSalesSummaryRow(
                  'Gecen Sure',
                  _formatElapsedSalesDuration(result.elapsedMinutes),
                ),
                _buildSalesSummaryRow(
                  'Satilan Adet',
                  result.totalSoldQuantity.toString(),
                ),
                _buildSalesSummaryRow(
                  'Toplam Ciro',
                  result.totalRevenue.toStringAsFixed(1),
                  valueColor: AppColors.green,
                ),
                _buildSalesSummaryRow(
                  'Toplam Kar',
                  result.totalProfit.toStringAsFixed(1),
                  valueColor: AppColors.gold,
                ),
                SizedBox(height: 14.h),
                Text(
                  'Urun Bazli Sonuc',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),
                ...result.items.map(
                  (item) => Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Slot ${item.slotIndex} | Kalite ${item.qualityLevel}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Satilan: ${item.soldQuantity} | Tutar: ${item.revenue.toStringAsFixed(1)} | Kar: ${item.profit.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSummaryRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsedSalesDuration(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainMinutes = minutes % 60;
      if (remainMinutes == 0) return '${hours}s';
      return '${hours}s ${remainMinutes}dk';
    }
    return '${minutes}dk';
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    StoreDetailPageModel page,
  ) {
    final store = page.store;
    final activeBoost = page.activeBoost;
    final activeUpgrade = page.activeUpgrade;

    return Column(
      children: [
        SecondaryTopBar(title: 'Magaza Yonetimi'),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                StoreDetailHeader(store: store),
                SizedBox(height: 16.h),
                StoreQuickActions(
                  canOpenNewSlot: store.currentSlotCount < store.maxSlotCount,
                  onUpgradeTap: () => _showStoreUpgradeSheet(context, ref, store, activeUpgrade),
                  onBoostTap: () => _showStoreBoostSheet(context, ref, store, activeBoost),
                  onReportTap: () => context.push('/store/${store.id}/report'),
                  onOpenSlotTap: () => _handleOpenSlot(context, ref, store),
                  onHistoryTap: () => context.push('/store/${store.id}/history'),
                ),
                if (activeBoost != null) ...[
                  SizedBox(height: 16.h),
                  _ActiveBoostCard(boost: activeBoost),
                ],
                if (activeUpgrade != null) ...[
                  SizedBox(height: 16.h),
                  _ActiveUpgradeCard(
                    upgrade: activeUpgrade,
                    onFinishWithGold: () => _finishStoreUpgradeWithGold(activeUpgrade),
                    calculateStarCost: _calculateUpgradeStarCost,
                    formatCountdown: _formatCountdown,
                  ),
                ],
                SizedBox(height: 16.h),
                _buildMetricsGrid(store),
                SizedBox(height: 24.h),
                Text('Magaza Raflari', style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                _buildSlotList(context, ref, store),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleOpenSlot(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final result = await ref.read(storeActionProvider).addStoreSlot(store.id);

    if (context.mounted) {
      if (result['success'] == true) {
        await _refreshStorePageAndSync(
          store.id,
          performanceDirty: true,
        );
        if (!context.mounted) return;
        _showSuccess(context, 'Yeni slot basariyla acildi!');
      } else {
        if (!context.mounted) return;
        _showError(context, result['message'] ?? 'Slot acilirken bir hata olustu.');
      }
    }
  }

  Future<StoreDetailPageModel> _refreshStorePageAndSync(
    String storeId, {
    bool refreshPlayer = false,
    bool historyDirty = false,
    bool performanceDirty = false,
  }) async {
    final page = await ref.read(
      storeDetailPageProvider(storeId).notifier,
    ).refresh();
    ref.read(storesListProvider.notifier).replaceStore(page.store);

    if (refreshPlayer || page.changed.player != null) {
      ref.invalidate(playerProvider);
    }

    if (historyDirty || page.changed.historyDirty) {
      ref.read(storeHistoryDirtyProvider(storeId).notifier).state = true;
    }

    if (performanceDirty || page.changed.performanceDirty) {
      ref.read(storePerformanceDirtyProvider(storeId).notifier).state = true;
    }

    return page;
  }

  String? _productNameFromMap(Map<String, dynamic> product) {
    return (product['name'] ?? product['urun_adi'])?.toString();
  }

  String? _productIconFromMap(Map<String, dynamic> product) {
    return (product['icon'] ?? product['urun_iconu'])?.toString();
  }
  String _formatCountdown(Duration remaining) {
    if (remaining.inSeconds <= 0) return 'Tamamlaniyor';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    }
    return '${remaining.inMinutes}dk';
  }

  Future<void> _showStoreBoostSheet(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    BuildingBoostModel? activeBoost,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Magaza Boostu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              activeBoost != null
                  ? 'Bu magazada zaten aktif bir boost var. Sure dolana kadar tum slotlar x${activeBoost.multiplier.toStringAsFixed(1)} hizla calisir.'
                  : 'Boost basladiginda tum store slotlarinin boost katsayisi 2 olur. Su an gecici varsayimla yildiz maliyeti saat / 2 kuralindan geliyor.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            if (activeBoost == null)
              ..._storeBoostStarCosts.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await ref
                          .read(storeActionProvider)
                          .startStoreBoost(
                            storeId: store.id,
                            durationHours: entry.key,
                            starCost: entry.value,
                          );

                      if (!context.mounted) return;

                      if (result['success'] == true) {
                        await _refreshStorePageAndSync(
                          store.id,
                          refreshPlayer: true,
                        );
                        _showSuccess(context, 'Magaza boostu baslatildi.');
                      } else {
                        _showError(
                          context,
                          result['message'] ??
                              'Magaza boostu baslatilamadi.',
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.goldDark.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: AppColors.goldDark.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(
                              Icons.flash_on_rounded,
                              color: AppColors.goldDark,
                              size: 18.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key} Saat',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tum slotlar x2 satis hizi kazanir',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${entry.value} ★',
                            style: TextStyle(
                              color: AppColors.goldLight,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Tamam'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _calculateUpgradeStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
  }

  Future<void> _finishStoreUpgradeWithGold(BuildingUpgradeModel upgrade) async {
    final starCost = _calculateUpgradeStarCost(upgrade.finishAt);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: const BorderSide(color: AppColors.borderGold),
        ),
        title: Text(
          'Yukseltmeyi Bitir',
          style: TextStyle(
            color: AppColors.goldLight,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$starCost yildiz kullanarak yukseltmeyi aninda tamamlamak istiyor musunuz?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Iptal',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Tamamla',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final result = await ref
        .read(storeActionProvider)
        .finishStoreUpgradeWithGold(upgrade.id);

    if (!mounted) return;

    if (result['success'] == true) {
      await _refreshStorePageAndSync(
        widget.storeId,
        refreshPlayer: true,
      );
      _showSuccess(context, 'Magaza yukseltmesi tamamlandi!');
    } else {
      _showError(
        context,
        result['message'] ?? 'Yildiz ile bitirme islemi basarisiz.',
      );
    }
  }

  Future<void> _showStoreUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    final targetLevel = store.level + 1;
    final durationMinutes = store.storeType.constructionTimeMinutes * targetLevel;
    final upgradeCost = (store.storeType.cost * targetLevel).toDouble();
    final slotCapacityIncrease = store.slotCapacity;
    const maxSlotIncrease = 2;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Magaza Yukseltme',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            if (activeUpgrade != null)
              Text(
                '${store.name} icin bir yukseltme zaten devam ediyor. Tamamlaninca seviye ${activeUpgrade.targetLevel} olacak, tum slot kapasiteleri +${activeUpgrade.slotCapacityIncrease} artacak ve max slot sayisi +${activeUpgrade.maxSlotIncrease} yukselecek.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  height: 1.45,
                ),
              )
            else
              Text(
                '${store.name} seviyesi ${store.level} -> $targetLevel olacak. Yukseltme tamamlaninca tum store slot kapasiteleri +$slotCapacityIncrease artar ve max slot sayisi +$maxSlotIncrease olur.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  height: 1.45,
                ),
              ),
            SizedBox(height: 16.h),
            _buildSalesSummaryRow('Mevcut Seviye', store.level.toString()),
            _buildSalesSummaryRow(
              'Hedef Seviye',
              (activeUpgrade?.targetLevel ?? targetLevel).toString(),
            ),
            _buildSalesSummaryRow(
              'Yukseltme Suresi',
              '${activeUpgrade?.durationMinutes ?? durationMinutes} dk',
            ),
            _buildSalesSummaryRow(
              'Yukseltme Maliyeti',
              'TL ${_formatValue(activeUpgrade?.upgradeCost ?? upgradeCost)}',
              valueColor: AppColors.red,
            ),
            _buildSalesSummaryRow(
              'Slot Kapasitesi',
              '${activeUpgrade?.previousSlotCapacity ?? store.slotCapacity} -> ${activeUpgrade?.nextSlotCapacity ?? (store.slotCapacity + slotCapacityIncrease)}',
              valueColor: AppColors.gold,
            ),
            _buildSalesSummaryRow(
              'Max Slot',
              '${activeUpgrade?.previousMaxSlotCount ?? store.maxSlotCount} -> ${activeUpgrade?.nextMaxSlotCount ?? (store.maxSlotCount + maxSlotIncrease)}',
              valueColor: AppColors.green,
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: activeUpgrade != null
                    ? () => Navigator.pop(sheetContext)
                    : () async {
                        Navigator.pop(sheetContext);
                        final result = await ref
                            .read(storeActionProvider)
                            .startStoreUpgrade(store.id);

                        if (!context.mounted) return;

                        if (result['success'] == true) {
                          await _refreshStorePageAndSync(
                            store.id,
                            refreshPlayer: true,
                          );
                          _showSuccess(
                            context,
                            'Magaza yukseltmesi baslatildi.',
                          );
                        } else {
                          _showError(
                            context,
                            result['message'] ??
                                'Magaza yukseltmesi baslatilamadi.',
                          );
                        }
                      },
                child: Text(activeUpgrade != null ? 'Tamam' : 'Yukseltmeyi Baslat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(StoreModel store) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompactMetricCol(
            title: 'Doluluk',
            value: '%${(store.summary.usedCapacityRatio * 100).toInt()}',
            icon: Icons.pie_chart,
            color: AppColors.goldDark,
          ),
          _buildCompactMetricCol(
            title: 'Stok',
            value: '${store.summary.totalQuantity}/${store.summary.totalCapacity}',
            icon: Icons.inventory_2,
            color: Colors.blueAccent,
          ),
          _buildCompactMetricCol(
            title: 'Kar',
            value: '+TL ${_formatValue(store.summary.totalStockSaleValue ?? 0)}',
            icon: Icons.trending_up,
            color: AppColors.green,
          ),
          _buildCompactMetricCol(
            title: 'Slot',
            value: '${store.slots.length}/${store.maxSlotCount}',
            icon: Icons.grid_view,
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricCol({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(height: 6.h),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.bold), maxLines: 1),
        SizedBox(height: 2.h),
        Text(title, style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp), maxLines: 1),
      ],
    );
  }

  Widget _buildSlotList(BuildContext context, WidgetRef ref, StoreModel store) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: store.slots.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return _buildProductSlotCard(
          context,
          ref,
          store,
          index + 1,
          store.slots[index],
        );
      },
    );
  }

  Widget _buildProductSlotCard(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    int index,
    StoreSlotModel slot,
  ) {
    final canAddStock = _canAddStockToSlot(slot);
    final canSendStock = _canSendStockFromSlot(slot);
    final canEditProduct = _canEditSlotProduct(slot);
    final qColor = slot.qualityLevel <= 1
        ? AppColors.red
        : slot.qualityLevel <= 2
            ? Colors.orange
            : slot.qualityLevel <= 3
                ? Colors.yellow
                : slot.qualityLevel <= 4
                    ? Colors.lightGreen
                    : AppColors.green;

    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: slot.isActive 
              ? AppColors.gold.withValues(alpha: 0.3) 
              : AppColors.border.withValues(alpha: 0.2),
          width: 1.2.w,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: slot.isEmpty
            ? Row(
                children: [
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.add_shopping_cart, color: AppColors.gold.withValues(alpha: 0.4), size: 24.sp),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bos Slot', style: TextStyle(color: AppColors.textSecondary, fontSize: 15.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: canEditProduct
                        ? () => _showProductSelectionDialog(context, ref, store, slot)
                        : () => _showStoreSlotLockedMessage(context, 'Yolda urun varken slot urunu degistirilemez.'),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('Urun Sec', style: TextStyle(color: AppColors.gold, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80.w,
                        height: 80.w,
                        padding: EdgeInsets.all(0),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
                        ),
                        child: CachedAssetImage(fileName: slot.productIcon ?? 'default', fit: BoxFit.contain),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(slot.productName ?? '', style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                SizedBox(width: 8.w),
                                Row(
                                  children: [
                                    Container(
                                      width: 8.w,
                                      height: 8.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: slot.isActive ? AppColors.green : AppColors.red,
                                        boxShadow: [
                                          BoxShadow(color: (slot.isActive ? AppColors.green : AppColors.red).withValues(alpha: 0.5), blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(slot.isActive ? 'Aktif' : 'Pasif', style: TextStyle(color: slot.isActive ? AppColors.green : AppColors.red, fontSize: 10.sp)),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: List.generate(5, (barIndex) {
                                return Icon(
                                  Icons.star_rounded,
                                  color: barIndex < slot.qualityLevel ? qColor : AppColors.textMuted,
                                  size: 12.sp,
                                );
                              }),
                            ),
                            SizedBox(height: 8.h),
                            GestureDetector(
                              onTap: () => _showPriceEditDialog(context, ref, store, slot),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('₺${slot.price?.toStringAsFixed(1) ?? '0'}', style: TextStyle(color: AppColors.gold, fontSize: 13.sp, fontWeight: FontWeight.w900)),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.edit, color: AppColors.textMuted, size: 12.sp),
                                    SizedBox(width: 8.w),
                                    Container(
                                      width: 1.w,
                                      height: 12.h,
                                      color: AppColors.textPrimary.withValues(alpha: 0.2),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      _formatStoreSlotMargin(slot), 
                                      style: TextStyle(color: _storeSlotMarginColor(slot), fontSize: 11.sp, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            child: Icon(Icons.more_vert, color: AppColors.textPrimary, size: 22.sp),
                            color: AppColors.cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            onSelected: (val) {
                              if (val == 'send' && canSendStock) {
                                _startStoreOutboundFlow(context, ref, store, slot);
                              } else if (val == 'toggle') {
                                _toggleStoreSlotActive(context, ref, store, slot);
                              } else if (val == 'clear' && canEditProduct) {
                                _confirmClearStoreSlot(context, ref, store, slot);
                              } else if (val == 'change' && canEditProduct) {
                                _showProductSelectionDialog(context, ref, store, slot);
                              } else if (!canEditProduct && (val == 'change' || val == 'clear')) {
                                _showStoreSlotLockedMessage(context, 'Yolda stok varken urun degistirilemez.');
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'send',
                                enabled: canSendStock,
                                child: Row(children: [Icon(Icons.local_shipping, color: AppColors.blue, size: 18.sp), SizedBox(width: 8.w), Text('Depoya Gonder', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp))]),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(children: [Icon(slot.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, color: slot.isActive ? AppColors.red : AppColors.green, size: 18.sp), SizedBox(width: 8.w), Text(slot.isActive ? 'Pasif Yap' : 'Aktif Et', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp))]),
                              ),
                              PopupMenuItem(
                                value: 'change',
                                enabled: canEditProduct,
                                child: Row(children: [Icon(Icons.swap_horiz, color: AppColors.gold, size: 18.sp), SizedBox(width: 8.w), Text('Urunu Degistir', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp))]),
                              ),
                              PopupMenuItem(
                                value: 'clear',
                                enabled: canEditProduct,
                                child: Row(children: [Icon(Icons.cleaning_services, color: AppColors.red, size: 18.sp), SizedBox(width: 8.w), Text('Slotu Temizle', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp))]),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          InkWell(
                            onTap: canAddStock ? () => _startStoreTransferFlow(context, ref, store, slot) : null,
                            borderRadius: BorderRadius.circular(8.r),
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: canAddStock ? AppColors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: canAddStock ? AppColors.green.withValues(alpha: 0.5) : Colors.transparent),
                              ),
                              child: Icon(Icons.add, color: canAddStock ? AppColors.green : Colors.grey, size: 20.sp),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Text('STOK DURUMU', style: TextStyle(color: AppColors.textSecondary, fontSize: 9.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const Spacer(),
                      Text(
                        '${slot.quantity} stok | ${slot.pendingQuantity} rezerve | ${slot.capacity - slot.quantity - slot.pendingQuantity} bos',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  _buildMiniProgressStacked(
                    slot.capacity > 0
                        ? (slot.quantity / slot.capacity).clamp(0.0, 1.0)
                        : 0,
                    reservedProgress: slot.capacity > 0
                        ? (slot.pendingQuantity / slot.capacity).clamp(0.0, 1.0)
                        : 0,
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      _buildCapacityLegend(
                        color: AppColors.gold,
                        label: 'Stok',
                      ),
                      SizedBox(width: 12.w),
                      _buildCapacityLegend(
                        color: AppColors.blue.withValues(alpha: 0.8),
                        label: 'Rezerve',
                      ),
                      SizedBox(width: 12.w),
                      _buildCapacityLegend(
                        color: AppColors.textMuted,
                        label: 'Bos',
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }



  bool _canEditSlotProduct(StoreSlotModel slot) {
    return slot.quantity <= 0 && slot.pendingQuantity <= 0;
  }

  bool _canAddStockToSlot(StoreSlotModel slot) {
    if (slot.productId == null || slot.productId!.isEmpty) return false;
    final remainingCapacity =
        slot.capacity - slot.quantity - slot.pendingQuantity;
    return remainingCapacity > 0;
  }

  bool _canSendStockFromSlot(StoreSlotModel slot) {
    return slot.quantity > 0;
  }

  void _showSuccess(BuildContext context, String message) {
    AppSnackbar.show(
      context,
      message: message,
      type: SnackbarType.success,
    );
  }

  void _showError(BuildContext context, String message) {
    AppSnackbar.show(
      context,
      message: message,
      type: SnackbarType.error,
    );
  }

  void _showInfo(BuildContext context, String message) {
    AppSnackbar.show(
      context,
      message: message,
      type: SnackbarType.info,
    );
  }

  void _showWarning(BuildContext context, String message) {
    AppSnackbar.show(
      context,
      message: message,
      type: SnackbarType.warning,
    );
  }

  void _showStoreSlotLockedMessage(BuildContext context, String message) {
    _showWarning(context, message);
  }

  Future<void> _toggleStoreSlotActive(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final result = await ref.read(storeActionProvider).setStoreSlotActive(
          slotId: slot.id,
          isActive: !slot.isActive,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref.read(storeDetailPageProvider(store.id).notifier).patchSlotActive(
        slotId: slot.id,
        isActive: !slot.isActive,
      );
      ref.read(storesListProvider.notifier).patchSlotActive(
        storeId: store.id,
        slotId: slot.id,
        isActive: !slot.isActive,
      );
      ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
      _showSuccess(
        context,
        slot.isActive ? 'Slot pasif yapildi.' : 'Slot aktif edildi.',
      );
      return;
    }

    _showError(context, result['message'] ?? 'Slot durumu guncellenemedi.');
  }

  Future<void> _confirmClearStoreSlot(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Slot Temizle',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '${slot.productName ?? 'Bu urun'} secimini kaldirmak istiyor musun? Fiyat ve bekleyen kesirli satis verisi de sifirlanir.',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.sp,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (shouldClear != true || !context.mounted) return;

    final result = await ref.read(storeActionProvider).clearStoreSlotProduct(
          slot.id,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref.read(storeDetailPageProvider(store.id).notifier).patchSlotCleared(
        slotId: slot.id,
      );
      ref.read(storesListProvider.notifier).patchSlotCleared(
        storeId: store.id,
        slotId: slot.id,
      );
      ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
      _showSuccess(context, 'Slot urun secimi temizlendi.');
      return;
    }

    _showError(context, result['message'] ?? 'Slot temizlenemedi.');
  }

  String _formatStoreSlotMargin(StoreSlotModel slot) {
    final price = slot.price ?? 0;
    final cost = slot.cost ?? 0;
    if (cost <= 0) return 'Maliyet';

    final marginRatio = ((price - cost) / cost) * 100;
    final sign = marginRatio >= 0 ? '+' : '';
    return '$sign${marginRatio.toStringAsFixed(0)}%';
  }

  Color _storeSlotMarginColor(StoreSlotModel slot) {
    final price = slot.price ?? 0;
    final cost = slot.cost ?? 0;
    if (cost <= 0) return AppColors.textMuted;
    return price >= cost ? AppColors.green : AppColors.red;
  }

  double _calculateStorePriceDemandMultiplier(
    double price,
    double basePrice,
  ) {
    if (basePrice <= 0) return 1.0;

    final ratio = price / basePrice;
    if (ratio <= 1) {
      return (1 + ((1 - ratio) * 0.75)).clamp(0.05, 1.75).toDouble();
    }

    return (1 - ((ratio - 1) * 0.95)).clamp(0.05, 1.75).toDouble();
  }

  String _formatSignedPercent(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  String _describeDemandEffect(double multiplier) {
    if (multiplier >= 1.35) return 'Cok yuksek talep';
    if (multiplier >= 1.1) return 'Yuksek talep';
    if (multiplier >= 0.9) return 'Dengeli talep';
    if (multiplier >= 0.6) return 'Dusuk talep';
    return 'Cok dusuk talep';
  }

  Color _demandEffectColor(double multiplier) {
    if (multiplier >= 1.1) return AppColors.green;
    if (multiplier >= 0.9) return AppColors.gold;
    return AppColors.red;
  }

  void _showPriceEditDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    final controller = TextEditingController(
      text: (slot.price ?? 0).toStringAsFixed(1),
    );
    final cost = slot.cost ?? 0;
    final product = slot.product;
    final basePrice = product?.bazSatisFiyati ?? 0;
    final averagePrice = product?.ortalamaFiyat ?? 0;
    final minPrice = product?.enDusukFiyat ?? 0;
    final maxPrice = product?.enYuksekFiyat ?? 0;
    final baseHourlyDemand = product?.satisAdedi ?? 0;
    double previewPrice = slot.price ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sheetContext, setState) {
          final marginAmount = previewPrice - cost;
          final marginRatio = cost > 0 ? (marginAmount / cost) * 100 : null;
          final vsBasePercent = basePrice > 0
              ? ((previewPrice - basePrice) / basePrice) * 100
              : 0.0;
          final demandMultiplier = _calculateStorePriceDemandMultiplier(
            previewPrice,
            basePrice,
          );
          final estimatedHourlyDemand =
              (baseHourlyDemand * demandMultiplier).toDouble();
          final demandColor = _demandEffectColor(demandMultiplier);

          return AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(
              'Satis Fiyati',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.productName ?? 'Urun',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Birim satis fiyati',
                      labelStyle: TextStyle(color: AppColors.gold),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.textMuted),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.gold),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        previewPrice =
                            double.tryParse(value.replaceAll(',', '.')) ?? 0;
                      });
                    },
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: demandColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: demandColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSalesSummaryRow(
                          'Baz Fiyat',
                          basePrice > 0 ? basePrice.toStringAsFixed(1) : '-',
                          valueColor: AppColors.gold,
                        ),
                        _buildSalesSummaryRow(
                          'Baz Fiyata Gore',
                          basePrice > 0
                              ? _formatSignedPercent(vsBasePercent)
                              : '-',
                          valueColor: vsBasePercent <= 0
                              ? AppColors.green
                              : AppColors.red,
                        ),
                        _buildSalesSummaryRow(
                          'Tahmini Talep',
                          'x${demandMultiplier.toStringAsFixed(2)}',
                          valueColor: demandColor,
                        ),
                        if (baseHourlyDemand > 0)
                          _buildSalesSummaryRow(
                            'Tahmini Satis',
                            '${estimatedHourlyDemand.toStringAsFixed(1)} / saat',
                            valueColor: demandColor,
                          ),
                        SizedBox(height: 4.h),
                        Text(
                          _describeDemandEffect(demandMultiplier),
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (averagePrice > 0 || minPrice > 0 || maxPrice > 0)
                    Text(
                      averagePrice > 0
                          ? 'Pazar ort.: ${averagePrice.toStringAsFixed(1)}'
                          : 'Pazar araligi: ${minPrice.toStringAsFixed(1)} - ${maxPrice.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  if (averagePrice > 0 && (minPrice > 0 || maxPrice > 0))
                    Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        'Aralik: ${minPrice.toStringAsFixed(1)} - ${maxPrice.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  SizedBox(height: 12.h),
                  _buildSalesSummaryRow(
                    'Maliyet',
                    cost.toStringAsFixed(1),
                    valueColor: AppColors.textPrimary,
                  ),
                  _buildSalesSummaryRow(
                    'Kar Tutari',
                    marginAmount.toStringAsFixed(1),
                    valueColor: marginAmount >= 0
                        ? AppColors.green
                        : AppColors.red,
                  ),
                  _buildSalesSummaryRow(
                    'Kar Orani',
                    marginRatio == null
                        ? cost == 0
                              ? 'Maliyet 0'
                              : '-'
                        : '%${marginRatio.toStringAsFixed(1)}',
                    valueColor: marginRatio == null
                        ? AppColors.gold
                        : marginRatio >= 0
                        ? AppColors.green
                        : AppColors.red,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                ),
                onPressed: () async {
                  final parsedPrice = double.tryParse(
                    controller.text.replaceAll(',', '.'),
                  );

                  if (parsedPrice == null || parsedPrice <= 0) {
                    _showWarning(context, 'Gecerli bir fiyat girin.');
                    return;
                  }

                  final result = await ref
                      .read(storeActionProvider)
                      .setStoreSlotPrice(
                        slotId: slot.id,
                        price: parsedPrice,
                      );

                  if (!context.mounted || !dialogContext.mounted) return;

                  if (result['success'] == true) {
                    Navigator.of(dialogContext).pop();
                    ref.read(storeDetailPageProvider(store.id).notifier)
                        .patchSlotPrice(
                          slotId: slot.id,
                          price: parsedPrice,
                        );
                    ref.read(storesListProvider.notifier).patchSlotPrice(
                      storeId: store.id,
                      slotId: slot.id,
                      price: parsedPrice,
                    );
                    ref.read(storePerformanceDirtyProvider(store.id).notifier)
                        .state = true;
                    _showSuccess(context, 'Satis fiyati kaydedildi.');
                    return;
                  }

                  _showError(
                    context,
                    result['message'] ?? 'Fiyat kaydedilemedi.',
                  );
                },
                child: const Text(
                  'Kaydet',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProductSelectionDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final parentContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    Map<String, dynamic> result = const {};
    try {
      result = await ref
          .read(storeActionProvider)
          .getAvailableProductsForStore(store.id);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showError(context, 'Urunler yuklenirken hata olustu: $e');
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (result['success'] != true) {
      if (context.mounted) {
        _showError(context, result['message'] ?? 'Urunler yuklenemedi.');
      }
      return;
    }

    final List<dynamic> products = result['products'] ?? [];
    if (products.isEmpty) {
      if (context.mounted) {
        _showInfo(context, 'Bu magaza icin uygun veya eklenmemis urun bulunamadi.');
      }
      return;
    }

    final options = products.map((product) {
      return ProductSelectionOption(
        id: product['id']?.toString() ?? '',
        title: (product['name'] ?? 'Bilinmeyen Urun').toString(),
        subtitle: 'Baz Fiyat: ${product['base_price']} TL',
        iconPath: (product['icon'] ?? 'default').toString(),
        onTap: () async {
          Navigator.pop(context);
          await _handleProductSelection(
            parentContext,
            ref,
            store,
            slot,
            product,
          );
        },
      );
    }).toList();

    if (!context.mounted) return;
    await ProductSelectionSheet.show(
      context: context,
      title: 'Ürün Seçimi',
      options: options,
    );
  }

  Future<void> _handleProductSelection(
    BuildContext parentContext,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> product,
  ) async {
    final result = await ref.read(storeActionProvider).setStoreSlotProduct(
          slotId: slot.id,
          productId: product['id'],
        );

    if (parentContext.mounted) {
      if (result['success'] == true) {
        final productId = product['id']?.toString() ?? '';
        ref.read(storeDetailPageProvider(store.id).notifier).patchSlotProduct(
          slotId: slot.id,
          productId: productId,
          qualityLevel: 1,
          productName: _productNameFromMap(product),
          productIcon: _productIconFromMap(product),
        );
        ref.read(storesListProvider.notifier).patchSlotProduct(
          storeId: store.id,
          slotId: slot.id,
          productId: productId,
          qualityLevel: 1,
          productName: _productNameFromMap(product),
          productIcon: _productIconFromMap(product),
        );
        if (!parentContext.mounted) return;
        ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
        _showSuccess(parentContext, '${product['name']} basariyla eklendi!');
      } else {
        if (!parentContext.mounted) return;
        _showError(parentContext, result['message'] ?? 'Urun eklenirken hata olustu.');
      }
    }
  }





  Widget _buildErrorState(WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.red, size: 48),
          SizedBox(height: 16.h),
          Text(
            'Bir hata olustu: $error',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              ref.read(storeDetailPageProvider(widget.storeId).notifier).refresh();
            },
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic amount) {
    if (amount == null) return '0';
    double val = double.parse(amount.toString());
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(1);
  }


  void _startStoreTransferFlow(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) {
      _showError(context, 'Once gecerli bir urun secin.');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kaynak Secin',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '${slot.productName ?? 'Urun'} icin tedarik kaynagini secin',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
              ),
              SizedBox(height: 16.h),
              _buildSourceChoiceTileV2(
                icon: Icons.warehouse_outlined,
                title: 'Depolarimdan',
                subtitle: 'Kendi depolarinizdan lojistik transfer baslatin',
                color: AppColors.gold,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openWarehouseSourceFlowV2(context, ref, store, slot);
                },
              ),
              SizedBox(height: 10.h),
              _buildSourceChoiceTileV2(
                icon: Icons.public,
                title: 'Pazardan',
                subtitle: 'Bu urunu global pazardan satin alin',
                color: AppColors.blue,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openMarketSourceFlowV2(context, store, slot);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniProgressStacked(
    double progress, {
    double reservedProgress = 0,
  }) {
    final stockRatio = progress.clamp(0.0, 1.0);
    final totalRatio = (stockRatio + reservedProgress).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      height: 10.h,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.05)),
      ),
      child: Stack(
        children: [
          if (totalRatio > 0)
            FractionallySizedBox(
              widthFactor: totalRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
          if (stockRatio > 0)
            FractionallySizedBox(
              widthFactor: stockRatio,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.goldDark,
                      AppColors.gold,
                      AppColors.goldLight,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCapacityLegend({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }




  Widget _buildSourceChoiceTileV2({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  bool _shouldLockStoreSlotQualityV2(StoreSlotModel slot) {
    return (slot.quantity > 0 || slot.pendingQuantity > 0) &&
        slot.qualityLevel > 0;
  }

  Future<void> _openWarehouseSourceFlowV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    final result = await ref.read(storeActionProvider).getEligibleWarehousesForStock(
          productId: productId,
          qualityLevel:
              _shouldLockStoreSlotQualityV2(slot) ? slot.qualityLevel : null,
        );

    if (context.mounted) Navigator.pop(context);

    if (result['success'] != true) {
      if (context.mounted) {
        _showError(context, result['message'] ?? 'Depolar yuklenemedi.');
      }
      return;
    }

    final warehouses = result['warehouses'] as List<dynamic>? ?? const [];
    if (warehouses.isEmpty) {
      if (context.mounted) {
        _showInfo(context, 'Bu urunu iceren uygun deponuz bulunamadi.');
      }
      return;
    }

    final options = <WarehouseSelectionOption>[];
    for (final warehouse in warehouses) {
      final warehouseSlots = warehouse['warehouse_slots'] as List<dynamic>? ?? const [];
      for (final productSlot in warehouseSlots) {
        final availableQty = (productSlot['quantity'] as num?)?.toInt() ?? 0;
        final qualityLevel = (productSlot['quality_level'] as num?)?.toInt() ?? 1;
        final sourceCityId = (warehouse['city_id'] ?? warehouse['city']?['id'] ?? '').toString();
        final cityName = (warehouse['city']?['name'] ?? 'Bilinmeyen Sehir').toString();
        final sameCity = (store.cityId ?? '').isNotEmpty && store.cityId == sourceCityId;

        options.add(
          WarehouseSelectionOption(
            id: productSlot['id'].toString(),
            title: (warehouse['name'] ?? 'Depo').toString(),
            subtitle: '$cityName | Kalite: $qualityLevel',
            badgeText: sameCity ? 'Aynı Şehir' : 'Şehirler Arası',
            infoText: '$availableQty Adet',
            isHighlightBadge: sameCity,
            onTap: () {
              Navigator.pop(context);
              _showQuantityTransferDialogV2(
                context,
                ref,
                store,
                slot,
                productSlot['id'].toString(),
                availableQty,
                qualityLevel,
                sourceCityId,
              );
            },
          ),
        );
      }
    }

    if (!context.mounted) return;
    await WarehouseSelectionSheet.show(
      context: context,
      title: 'Kaynak Depo Seçin',
      options: options,
    );
  }

  void _openMarketSourceFlowV2(
    BuildContext context,
    StoreModel store,
    StoreSlotModel slot,
  ) {
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) return;

    context.push(
      Uri(
        path: '/market/$productId',
        queryParameters: {
          'targetType': 'store',
          'storeId': store.id,
          'storeSlotId': slot.id,
          'cityId': store.cityId ?? '',
          'playerId': '',
        },
      ).toString(),
    );
  }



  void _showQuantityTransferDialogV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseSlotId,
    int availableQty,
    int selectedQualityLevel,
    String sourceCityId,
  ) {
    final controller = TextEditingController(text: '1');
    final maxCanTake = slot.capacity - slot.quantity - slot.pendingQuantity;
    final limit = availableQty < maxCanTake ? availableQty : maxCanTake.toInt();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Miktar Girin',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${slot.productName} Transferi',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Miktar (Maks: $limit)',
                labelStyle: const TextStyle(color: AppColors.gold),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textMuted),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty <= 0 || qty > limit) {
                _showWarning(context, 'Gecersiz miktar!');
                return;
              }
              Navigator.pop(dialogContext);
              _showVehicleSelectionSheetV2(
                context,
                ref,
                store,
                slot,
                warehouseSlotId,
                qty,
                selectedQualityLevel,
                sourceCityId,
              );
            },
            child: const Text(
              'Devam Et',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVehicleSelectionSheetV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseSlotId,
    int quantity,
    int selectedQualityLevel,
    String sourceCityId,
  ) async {
    final isSameCity =
        (store.cityId ?? '').isNotEmpty &&
        store.cityId == sourceCityId;

    if (isSameCity) {
      _startWarehouseTransferV2(
        context,
        ref,
        store,
        slot,
        warehouseSlotId,
        quantity,
        selectedQualityLevel,
        null,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
          .read(storeActionProvider)
          .getStoreTransferVehicleOptions(
            storeSlotId: slot.id,
            warehouseSlotId: warehouseSlotId,
            quantity: quantity,
          );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showError(context, 'Araclar alinamadi: $e');
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (vehicleResult.options.isEmpty) {
      if (context.mounted) {
        _showError(
          context,
          vehicleResult.unavailableReason ??
              'Bu transfer icin uygun arac bulunamadi.',
        );
      }
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arac Secin',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '$quantity adet urun icin uygun araci secin',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: vehicleResult.options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = vehicleResult.options[index];
                  final color =
                      option.canSelect ? AppColors.green : AppColors.red;
                  return InkWell(
                    onTap: option.canSelect
                        ? () {
                            Navigator.pop(sheetContext);
                            _startWarehouseTransferV2(
                              context,
                              ref,
                              store,
                              slot,
                              warehouseSlotId,
                              quantity,
                              selectedQualityLevel,
                              option.vehicleId,
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: color),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  option.vehicleName,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                option.isRental ? 'Kiralik' : 'Ozmal',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Kapasite: ${option.capacity} | Mesafe: ${option.distanceKm.toStringAsFixed(0)} km | Sure: ${_formatTransferDurationV2(option.estimatedDurationSeconds)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Yakit: ${option.fuelNeeded.toStringAsFixed(0)} | Kondisyon: ${option.conditionNeeded.toStringAsFixed(0)} | Kira: ${option.rentalCost.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          if (!option.canSelect &&
                              option.disabledReason != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              option.disabledReason!,
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTransferDurationV2(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }

  Future<void> _startWarehouseTransferV2(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseSlotId,
    int quantity,
    int selectedQualityLevel,
    String? vehicleId,
  ) async {
    final productId = slot.productId;
    final needsSlotSetup =
        !_shouldLockStoreSlotQualityV2(slot) &&
        productId != null &&
        productId.isNotEmpty &&
        (slot.productId == null || slot.qualityLevel != selectedQualityLevel);

    if (needsSlotSetup) {
      final setupResult = await ref.read(storeActionProvider).setStoreSlotProduct(
            slotId: slot.id,
            productId: productId,
            qualityLevel: selectedQualityLevel,
          );

      if (setupResult['success'] != true) {
        if (!context.mounted) return;
        _showError(context, 'Hata: ${setupResult['message']}');
        return;
      }
    }

    final result = await ref.read(storeActionProvider).startWarehouseToStoreTransfer(
          storeSlotId: slot.id,
          warehouseSlotId: warehouseSlotId,
          quantity: quantity,
          vehicleId: vehicleId,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await _refreshStorePageAndSync(
        store.id,
        refreshPlayer: true,
        historyDirty: true,
        performanceDirty: true,
      );
      if (!context.mounted) return;
      final isInstant = result['mode']?.toString() == 'instant';
      _showSuccess(
        context,
        isInstant
            ? 'Ayni sehir transferi tamamlandi.'
            : 'Lojistik transfer baslatildi. Arac yola cikti.',
      );
    } else {
      if (!context.mounted) return;
      _showError(context, result['message'] ?? 'Transfer basarisiz.');
    }
  }

  Future<void> _startStoreOutboundFlow(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    if ((slot.quantity) <= 0) {
      _showError(context, 'Gonderilecek stok bulunmuyor.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    List<Map<String, dynamic>> warehouses = const [];
    try {
      warehouses = await ref.read(storeActionProvider).getPlayerWarehouses();
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showError(context, 'Depolar alinamadi: $e');
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (warehouses.isEmpty) {
      if (context.mounted) {
        _showError(context, 'Uygun hedef deponuz bulunamadi.');
      }
      return;
    }

    final sortedWarehouses = List<Map<String, dynamic>>.from(warehouses)
      ..sort((a, b) {
        final aSameCity =
            (a['city_id']?.toString() ?? '') == (store.cityId ?? '');
        final bSameCity =
            (b['city_id']?.toString() ?? '') == (store.cityId ?? '');
        if (aSameCity == bSameCity) {
          return (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          );
        }
        return aSameCity ? -1 : 1;
      });

    final options = sortedWarehouses.map((warehouse) {
      final cityName = (warehouse['city']?['name'] ?? 'Bilinmeyen Sehir').toString();
      final isSameCity = (warehouse['city_id']?.toString() ?? '') == (store.cityId ?? '');

      return WarehouseSelectionOption(
        id: warehouse['id'].toString(),
        title: (warehouse['name'] ?? 'Depo').toString(),
        subtitle: cityName,
        badgeText: isSameCity ? 'Aynı Şehir' : 'Şehirler Arası',
        infoText: isSameCity ? 'Anlık' : 'Lojistik',
        isHighlightBadge: isSameCity,
        onTap: () {
          Navigator.pop(context);
          _showOutboundQuantityDialog(
            context,
            ref,
            store,
            slot,
            warehouse,
            cityName,
          );
        },
      );
    }).toList();

    if (!context.mounted) return;
    await WarehouseSelectionSheet.show(
      context: context,
      title: 'Hedef Depo Seçin',
      options: options,
    );
  }

  void _showOutboundQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> warehouse,
    String warehouseCityName,
  ) {
    final controller = TextEditingController(text: '1');
    final limit = slot.quantity;
    final isSameCity =
        ((store.cityId ?? '').isNotEmpty &&
            store.cityId == (warehouse['city_id']?.toString() ?? '')) ||
        ((store.cityName ?? '').trim().toLowerCase() ==
            warehouseCityName.trim().toLowerCase());

    void applyQuantity(int value, void Function(void Function()) setState) {
      final clamped = value.clamp(1, limit);
      setState(() {
        controller.text = clamped.toString();
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
          title: Text(
            'Miktar Girin',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18.sp),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.productName ?? 'Urun',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${store.name} -> ${(warehouse['name'] ?? 'Depo').toString()}',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: [
                          _buildStatusPill(
                            isSameCity ? 'Ayni sehir' : 'Sehirler arasi',
                            isSameCity ? AppColors.green : AppColors.blue,
                          ),
                          _buildStatusPill('Maksimum $limit', AppColors.gold),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Miktar',
                    helperText: 'Depoya gonderilecek urun adedi',
                    labelStyle: const TextStyle(color: AppColors.gold),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.textMuted),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildQuickQuantityButton(
                      '1/4',
                      () => applyQuantity((limit / 4).ceil(), setState),
                    ),
                    _buildQuickQuantityButton(
                      'Yari',
                      () => applyQuantity((limit / 2).ceil(), setState),
                    ),
                    _buildQuickQuantityButton(
                      'Tamami',
                      () => applyQuantity(limit, setState),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () {
                final qty = int.tryParse(controller.text) ?? 0;
                if (qty <= 0 || qty > limit) {
                  _showWarning(context, 'Gecersiz miktar!');
                  return;
                }
                Navigator.pop(dialogContext);
                _maybeStartStoreOutboundTransfer(
                  context,
                  ref,
                  store,
                  slot,
                  warehouse,
                  warehouseCityName,
                  qty,
                );
              },
              child: const Text(
                'Devam Et',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildStatusPill(String label, Color accentColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildQuickQuantityButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppColors.borderGold.withValues(alpha: 0.3)),
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Future<void> _maybeStartStoreOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> warehouse,
    String warehouseCityName,
    int quantity,
  ) async {
    final sameCity =
        ((store.cityId ?? '').isNotEmpty &&
            store.cityId == (warehouse['city_id']?.toString() ?? '')) ||
        (store.cityId == null &&
            (store.cityName ?? '').trim().toLowerCase() ==
                warehouseCityName.trim().toLowerCase());

    if (sameCity) {
      await _startStoreOutboundTransfer(
        context,
        ref,
        store,
        slot,
        warehouse['id'].toString(),
        quantity,
        null,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );

    TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
          .read(storeActionProvider)
          .getStoreToWarehouseVehicleOptions(
            storeSlotId: slot.id,
            warehouseId: warehouse['id'].toString(),
            quantity: quantity,
          );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showError(context, 'Araclar alinamadi: $e');
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (vehicleResult.options.isEmpty) {
      if (context.mounted) {
        _showError(
          context,
          vehicleResult.unavailableReason ??
              'Bu transfer icin uygun arac bulunamadi.',
        );
      }
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arac Secin',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '$quantity adet urun icin uygun araci secin',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: vehicleResult.options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = vehicleResult.options[index];
                  final color =
                      option.canSelect ? AppColors.green : AppColors.red;
                  return InkWell(
                    onTap: option.canSelect
                        ? () {
                            Navigator.pop(sheetContext);
                            _startStoreOutboundTransfer(
                              context,
                              ref,
                              store,
                              slot,
                              warehouse['id'].toString(),
                              quantity,
                              option.vehicleId,
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: color.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_shipping, color: color),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  option.vehicleName,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                option.isRental ? 'Kiralik' : 'Ozmal',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Kapasite: ${option.capacity} | Mesafe: ${option.distanceKm.toStringAsFixed(0)} km | Sure: ${_formatTransferDurationV2(option.estimatedDurationSeconds)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Yakit: ${option.fuelNeeded.toStringAsFixed(0)} | Kondisyon: ${option.conditionNeeded.toStringAsFixed(0)} | Kira: ${option.rentalCost.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          if (!option.canSelect &&
                              option.disabledReason != null) ...[
                            SizedBox(height: 6.h),
                            Text(
                              option.disabledReason!,
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startStoreOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    String warehouseId,
    int quantity,
    String? vehicleId,
  ) async {
    final result = await ref.read(storeActionProvider).startStoreToWarehouseTransfer(
          storeSlotId: slot.id,
          warehouseId: warehouseId,
          quantity: quantity,
          vehicleId: vehicleId,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      await _refreshStorePageAndSync(
        store.id,
        refreshPlayer: true,
        historyDirty: true,
        performanceDirty: true,
      );
      if (!context.mounted) return;
      final isInstant = result['mode']?.toString() == 'instant';
      _showSuccess(
        context,
        isInstant
            ? 'Ayni sehir gonderimi tamamlandi.'
            : 'Lojistik transfer baslatildi. Arac yola cikti.',
      );
      return;
    }

    if (!context.mounted) return;
    _showError(context, 'Hata: ${result['message']}');
  }
}

class _ActiveBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveBoostCard({required this.boost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalSeconds = boost.finishAt.difference(boost.startedAt).inSeconds;
    final elapsedSeconds = now.difference(boost.startedAt).inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = boost.finishAt.difference(now);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.goldDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.goldDark.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: AppColors.goldDark,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boost Aktif',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${boost.durationHours} saat | Katsayi x${boost.multiplier.toStringAsFixed(1)} | ${boost.starCost} yildiz',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCountdownLabel(remaining),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.goldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveUpgradeCard({
    required this.upgrade,
    required this.onFinishWithGold,
    required this.calculateStarCost,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalSeconds = upgrade.finishAt.difference(upgrade.startedAt).inSeconds;
    final elapsedSeconds = now.difference(upgrade.startedAt).inSeconds;
    final progress = totalSeconds > 0
        ? (elapsedSeconds / totalSeconds).clamp(0.0, 1.0)
        : 1.0;
    final remaining = upgrade.finishAt.difference(now);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.upgrade_rounded,
                  color: AppColors.green,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yukseltme Devam Ediyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Seviye ${upgrade.currentLevel} -> ${upgrade.targetLevel} | Slot kapasitesi +${upgrade.slotCapacityIncrease} | Max slot +${upgrade.maxSlotIncrease}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCountdown(remaining),
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
                foregroundColor: AppColors.goldLight,
              ),
              onPressed: onFinishWithGold,
              icon: const Icon(Icons.star_rounded),
              label: Text('${calculateStarCost(upgrade.finishAt)} yildiz ile bitir'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCountdownLabel(Duration remaining) {
  if (remaining.inSeconds <= 0) return 'Tamamlaniyor';
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours > 0) {
    return '${hours}s ${minutes}dk';
  }
  return '${remaining.inMinutes}dk';
}

