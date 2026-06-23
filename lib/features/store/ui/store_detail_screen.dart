import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/auth/models/experience_gain_model.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
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

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen>
    with WidgetsBindingObserver {
  static const String _defaultBrandId = '00000000-0000-0000-0000-000000000000';
  String? _lastShownSalesResultKey;
  Timer? _salesRefreshTimer;
  bool _isAutoRefreshingStoreSales = false;
  static const Map<int, int> _storeBoostStarCosts = {
    6: 3,
    12: 6,
    24: 12,
  };

  @override
  void initState() {
    super.initState();
    _lastShownSalesResultKey = null;
    WidgetsBinding.instance.addObserver(this);
    _salesRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshSalesIfWorthChecking(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSalesIfWorthChecking(force: true);
    });
  }

  @override
  void dispose() {
    _salesRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSalesIfWorthChecking(force: true);
    }
  }

  bool _storeHasSaleCandidates(StoreModel store) {
    if (!store.isActive) return false;
    return store.slots.any(
      (slot) =>
          slot.isActive &&
          slot.productId != null &&
          slot.qualityLevel > 0 &&
          slot.quantity > 0 &&
          (slot.price ?? 0) > 0,
    );
  }

  Future<void> _refreshSalesIfWorthChecking({bool force = false}) async {
    if (!mounted || _isAutoRefreshingStoreSales) return;

    final page = ref.read(storeDetailPageProvider(widget.storeId)).value;
    if (page == null) return;
    if (!force && !_storeHasSaleCandidates(page.store)) return;

    _isAutoRefreshingStoreSales = true;
    try {
      await _refreshStorePageAndSync(widget.storeId);
    } catch (_) {
      // Background sale checks should not interrupt gameplay with errors.
    } finally {
      _isAutoRefreshingStoreSales = false;
    }
  }

  void _onNavSelected(int index) {
    if (index == -1) return;
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

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeDetailPageProvider(widget.storeId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(storeHistoryDirtyProvider(page.store.id).notifier).state =
          page.changed.historyDirty;
      ref.read(storePerformanceDirtyProvider(page.store.id).notifier).state =
          page.changed.performanceDirty;
    });

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

      // Automatic store sales change the player's cash balance, but the
      // backend response does not always flag player changes explicitly.
      ref.invalidate(playerProvider);
      
      // Clear the sale result from the provider so it doesn't pop up again when returning to this screen
      ref.read(storeDetailPageProvider(page.store.id).notifier).clearSaleResult();


      if (result.success != true && (result.message ?? '').trim().isNotEmpty) {
        AppSnackbar.show(
          context,
          title: 'Satis Hesaplanamadi',
          message: result.message!,
          type: SnackbarType.error,
        );
        return;
      }

      await _showStoreSalesSummaryDialog(context, result, page.store.slots);

      if (!mounted) return;
      final exp = result.experience;
      if (exp != null && exp.leveledUp) {
        await _showLevelUpDialog(context, exp);
      }
    });
  }

  Future<void> _showStoreSalesSummaryDialog(
    BuildContext context,
    StoreSaleResultModel result,
    List<StoreSlotModel> slots,
  ) {
    final profitColor = result.totalProfit >= 0 ? AppColors.green : AppColors.red;
    final currentBrandName = ref.read(playerBrandCompanyProvider).value?.brandName;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: AppDecorations.premiumCard(profitColor, 20.r),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: profitColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: profitColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        result.totalProfit >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: profitColor,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satis Ozeti',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Gecen Sure: ${_formatElapsedSalesDuration(result.elapsedMinutes)}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSalesSummaryMetric(
                              'Adet',
                              result.totalSoldQuantity.toString(),
                              AppColors.gold,
                            ),
                          ),
                          Expanded(
                            child: _buildSalesSummaryMetric(
                              'Ciro',
                              '${result.totalRevenue.toStringAsFixed(1)} TL',
                              AppColors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildSalesSummaryMetric(
                              'Kar',
                              '${result.totalProfit.toStringAsFixed(1)} TL',
                              profitColor,
                            ),
                          ),
                        ],
                      ),
                      if ((result.experience?.amount ?? 0) > 0) ...[
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 12.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.blue.withValues(alpha: 0.15),
                                Colors.blue.withValues(alpha: 0.03),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_rounded, color: AppColors.blue, size: 14.sp),
                              SizedBox(width: 6.w),
                              Text(
                                '+${result.experience!.amount} XP Kazandin!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                if (result.items.isNotEmpty) ...[
                  Text(
                    'Urunler',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 250.h),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: result.items.length,
                      separatorBuilder: (_, index) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final item = result.items[index];
                        final slot = slots.firstWhere(
                          (s) => s.slotIndex == item.slotIndex || s.productId == item.productId,
                          orElse: () => StoreSlotModel(
                            id: '',
                            storeId: '',
                            slotIndex: item.slotIndex,
                            brandId: _defaultBrandId,
                            quantity: 0,
                            pendingQuantity: 0,
                            qualityLevel: item.qualityLevel,
                            capacity: 0,
                            boostMultiplier: 1.0,
                            isActive: false,
                            isEmpty: true,
                            usedCapacityRatio: 0.0,
                          ),
                        );
                        final productIcon = slot.productIcon ?? slot.product?.urunIconu ?? 'default.webp';

                        return Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36.w,
                                height: 36.w,
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: BrandedProductImage(
                                  fileName: productIcon,
                                  brandId: slot.brandId,
                                  brandName: slot.brandId != _defaultBrandId
                                      ? currentBrandName
                                      : null,
                                  productId: item.productId,
                                  fit: BoxFit.contain,
                                  showFrame: false,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Row(
                                      children: [
                                        for (int i = 0; i < 5; i++)
                                          Icon(
                                            i < item.qualityLevel
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: i < item.qualityLevel
                                                ? AppColors.gold
                                                : Colors.white10,
                                            size: 10.sp,
                                          ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          '| Slot ${item.slotIndex}',
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 9.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${item.soldQuantity} Adet',
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${item.profit >= 0 ? '+' : ''}${item.profit.toStringAsFixed(1)} TL',
                                    style: TextStyle(
                                      color: item.profit >= 0 ? AppColors.green : AppColors.red,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                SizedBox(height: 16.h),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: profitColor.withValues(alpha: 0.16),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: profitColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 11.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Tamam',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLevelUpDialog(
    BuildContext context,
    ExperienceGainModel experience,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Seviye Atladi!',
          style: TextStyle(
            color: AppColors.gold,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tebrikler, sirket seviyen yukseldi.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 12.h),
            _buildSalesSummaryRow(
              'Eski Seviye',
              experience.oldLevel.toString(),
            ),
            _buildSalesSummaryRow(
              'Yeni Seviye',
              experience.newLevel.toString(),
              valueColor: AppColors.gold,
            ),
            _buildSalesSummaryRow(
              'Kazanilan XP',
              '+${experience.amount}',
              valueColor: AppColors.blue,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Harika'),
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

  Widget _buildSalesSummaryMetric(
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.sp,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 13.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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

  Widget _buildStoreWarehouseCard(
    BuildContext context,
    StoreModel store,
    StoreWarehouseSummaryModel warehouse,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: () => context.push('/store/${store.id}/warehouse'),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.cardBgLight.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.blue,
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Magaza Deposu',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          warehouse.name,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 20.sp,
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoMetricCard(
                      'Kapasite',
                      '${warehouse.usedCapacity.toStringAsFixed(1)} / ${warehouse.capacity.toStringAsFixed(1)}',
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildInfoMetricCard(
                      'Urun Cesidi',
                      warehouse.slots.length.toString(),
                    ),
                  ),
                ],
              ),
              if (warehouse.slots.isNotEmpty) ...[
                SizedBox(height: 12.h),
                SizedBox(
                  height: 42.w,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: warehouse.slots.length,
                    separatorBuilder: (context, index) => SizedBox(width: 8.w),
                    itemBuilder: (context, index) {
                      final slot = warehouse.slots[index];
                      return Container(
                        width: 42.w,
                        height: 42.w,
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: AppColors.blue.withValues(alpha: 0.18),
                          ),
                        ),
                        child: BrandedProductImage(
                          fileName: slot.productIcon ?? 'default.webp',
                          brandId: slot.brandId,
                          brandName: _warehouseSlotBrandName(slot),
                          productId: slot.productId,
                          fit: BoxFit.contain,
                          showFrame: false,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoMetricCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    WidgetRef ref,
    StoreDetailPageModel page,
  ) {
    final store = page.store;
    final storeWarehouse = page.storeWarehouse;
    final activeBoost = page.activeBoost;
    final activeUpgrade = page.activeUpgrade;

    return Column(
      children: [
        SecondaryTopBar(title: 'Magaza Yonetimi'),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.gold,
            backgroundColor: AppColors.background,
            onRefresh: () => _refreshStorePageAndSync(
              store.id,
              refreshPlayer: true,
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                  StoreDetailHeader(
                    store: store,
                    onToggleActiveTap: () => _toggleStoreActive(context, ref, store),
                    onReportTap: () => context.push('/store/${store.id}/report'),
                    onHistoryTap: () => context.push('/store/${store.id}/history'),
                    onSellTap: () => _showSellStoreDialog(context, ref, store),
                  ),
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
                if (storeWarehouse != null) ...[
                  SizedBox(height: 16.h),
                  _buildStoreWarehouseCard(context, store, storeWarehouse),
                ],
                SizedBox(height: 24.h),
                Text('Magaza Raflari', style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 12.h),
                _buildSlotList(context, ref, store),
                SizedBox(height: 32.h),
              ],
              ),
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

  Future<void> _toggleStoreActive(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final nextActive = !store.isActive;
    final result = await ref.read(storeActionProvider).setStoreActive(
          storeId: store.id,
          isActive: nextActive,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref
          .read(storeDetailPageProvider(store.id).notifier)
          .patchStoreActive(nextActive);
      ref.read(storesListProvider.notifier).patchStoreActive(
            storeId: store.id,
            isActive: nextActive,
          );
      ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
      _showSuccess(
        context,
        nextActive ? 'Magaza aktif edildi.' : 'Magaza pasife alindi.',
      );
      return;
    }

    _showError(
      context,
      result['message'] ?? 'Magaza durumu guncellenemedi.',
    );
  }

  Future<void> _showSellStoreDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {
    final quote = await ref.read(storeActionProvider).sellStore(
          storeId: store.id,
          confirm: false,
        );

    if (!context.mounted) return;

    if (quote['success'] != true) {
      _showError(
        context,
        quote['message'] ?? 'Magaza satis teklifi alinamadi.',
      );
      return;
    }

    final constructionRefund =
        (quote['construction_refund'] as num?)?.toDouble() ?? 0;
    final stockRefund = (quote['stock_refund'] as num?)?.toDouble() ?? 0;
    final totalRefund = (quote['total_refund'] as num?)?.toDouble() ?? 0;

    final shouldSell = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Magazayi Sat',
          style: TextStyle(
            color: AppColors.red,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${store.name} kalici olarak silinecek. Bu islem geri alinamaz.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
                height: 1.35,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildSalesSummaryRow(
                    'Kurulus Iadesi',
                    constructionRefund.toStringAsFixed(1),
                    valueColor: AppColors.gold,
                  ),
                  _buildSalesSummaryRow(
                    'Stok Maliyet Iadesi',
                    stockRefund.toStringAsFixed(1),
                    valueColor: AppColors.gold,
                  ),
                  Divider(color: AppColors.border, height: 12.h),
                  _buildSalesSummaryRow(
                    'Toplam Odeme',
                    totalRefund.toStringAsFixed(1),
                    valueColor: AppColors.green,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Aktif transfer varsa satis engellenir. Satis sonrasi magazanin slotlari ve stoklari silinir.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.sp,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Magazayi Sat',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldSell != true || !context.mounted) return;

    final result = await ref.read(storeActionProvider).sellStore(
          storeId: store.id,
          confirm: true,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref.read(storesListProvider.notifier).removeStore(store.id);
      ref.invalidate(playerProvider);
      _showSuccess(
        context,
        'Magaza satildi. ${((result['total_refund'] as num?)?.toDouble() ?? totalRefund).toStringAsFixed(1)} TL eklendi.',
      );
      context.go('/store');
      return;
    }

    _showError(
      context,
      result['message'] ?? 'Magaza satilamadi.',
    );
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

  String? _slotBrandName(StoreSlotModel slot) {
    if (slot.brandId == _defaultBrandId) return null;
    return ref.watch(playerBrandCompanyProvider).value?.brandName;
  }

  String? _warehouseSlotBrandName(StoreWarehouseSlotSummaryModel slot) {
    if (slot.brandId == _defaultBrandId) return null;
    return ref.watch(playerBrandCompanyProvider).value?.brandName;
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
                        if (!context.mounted) return;
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
      if (!mounted) return;
      _showSuccess(context, 'Magaza yukseltmesi tamamlandi!');
      await showExperienceFeedbackFromResult(context, result);
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
                          if (!context.mounted) return;
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
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
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
                        child: BrandedProductImage(
                          fileName: slot.productIcon ?? 'default',
                          brandId: slot.brandId,
                          brandName: _slotBrandName(slot),
                          productId: slot.productId,
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    (slot.productName ?? '') +
                                        (slot.brandId != _defaultBrandId
                                            ? ' (${ref.watch(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})'
                                            : ''),
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
                            color: AppColors.cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            onSelected: (val) {
                              if (val == 'send' && canSendStock) {
                                _startStoreWarehouseOutboundFlow(context, ref, store, slot);
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
                                child: Row(children: [Icon(Icons.local_shipping, color: AppColors.blue, size: 18.sp), SizedBox(width: 8.w), Text('Magaza Deposuna Gonder', style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp))]),
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
                            child: Icon(Icons.more_vert, color: AppColors.textPrimary, size: 22.sp),
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

  bool _shouldLockStoreSlotQualityV2(StoreSlotModel slot) {
    return (slot.quantity > 0 || slot.pendingQuantity > 0) &&
        slot.qualityLevel > 0;
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
          '${(slot.productName ?? 'Bu urun') + (slot.brandId != _defaultBrandId ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})' : '')} secimini kaldirmak istiyor musun? Fiyat ve bekleyen kesirli satis verisi de sifirlanir.',
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
    double referencePrice,
  ) {
    if (referencePrice <= 0) return 1.0;

    final ratio = price / referencePrice;
    if (ratio <= 1) {
      return (1 + ((1 - ratio) * 0.75)).clamp(0.05, 1.75).toDouble();
    }

    return (1 - ((ratio - 1) * 0.95)).clamp(0.05, 1.75).toDouble();
  }

  double _storeQualityPriceMultiplier(int qualityLevel) {
    switch (qualityLevel.clamp(1, 5)) {
      case 2:
        return 1.10;
      case 3:
        return 1.22;
      case 4:
        return 1.35;
      case 5:
        return 1.50;
      default:
        return 1.00;
    }
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
      text: (slot.price ?? 0).toStringAsFixed(1).replaceAll('.', ','),
    );
    final cost = slot.cost ?? 0;
    final product = slot.product;
    final qualityPriceMultiplier =
        _storeQualityPriceMultiplier(slot.qualityLevel);
    final basePrice = (product?.bazSatisFiyati ?? 0) * qualityPriceMultiplier;
    final averagePrice = product?.ortalamaFiyat ?? 0;
    final baseHourlyDemand = product?.satisAdedi ?? 0;
    double previewPrice = slot.price ?? 0;

    String shortcutValue(double value) =>
        value.toStringAsFixed(1).replaceAll('.', ',');

    final shortcuts = <NumericKeyboardShortcut>[
      if ((slot.price ?? 0) > 0)
        NumericKeyboardShortcut(
          label: 'Mevcut',
          value: shortcutValue(slot.price!),
        ),
      if (cost > 0)
        NumericKeyboardShortcut(label: 'Maliyet', value: shortcutValue(cost)),
      if (cost > 0)
        NumericKeyboardShortcut(
          label: 'Maliyet +%25',
          value: shortcutValue(cost * 1.25),
        ),
      if (basePrice > 0)
        NumericKeyboardShortcut(
          label: 'Piyasa',
          value: shortcutValue(basePrice),
        ),
      if (basePrice > 0)
        NumericKeyboardShortcut(
          label: 'Piyasa +%25',
          value: shortcutValue(basePrice * 1.25),
        ),
      if (averagePrice > 0)
        NumericKeyboardShortcut(
          label: 'Pazar Ort.',
          value: shortcutValue(averagePrice),
        ),
    ];

    Future<void> savePrice(BuildContext sheetContext) async {
      final parsedPrice = double.tryParse(
        controller.text.replaceAll(',', '.'),
      );

      if (parsedPrice == null || parsedPrice <= 0) {
        _showWarning(context, 'Gecerli bir fiyat girin.');
        return;
      }

      final result = await ref
          .read(storeActionProvider)
          .setStoreSlotPrice(slotId: slot.id, price: parsedPrice);

      if (!context.mounted || !sheetContext.mounted) return;

      if (result['success'] == true) {
        Navigator.of(sheetContext).pop();
        ref.read(storeDetailPageProvider(store.id).notifier).patchSlotPrice(
              slotId: slot.id,
              price: parsedPrice,
            );
        ref.read(storesListProvider.notifier).patchSlotPrice(
              storeId: store.id,
              slotId: slot.id,
              price: parsedPrice,
            );
        ref.read(storePerformanceDirtyProvider(store.id).notifier).state = true;
        _showSuccess(context, 'Satis fiyati kaydedildi.');
        return;
      }

      _showError(context, result['message'] ?? 'Fiyat kaydedilemedi.');
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          final profitColor = cost <= 0
              ? AppColors.gold
              : marginAmount >= 0
              ? AppColors.green
              : AppColors.red;
          final screenHeight = MediaQuery.of(sheetContext).size.height;

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24.r),
                ),
                border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.22),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Satis Fiyati',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              (slot.productName ?? 'Urun') +
                                  (slot.brandId != _defaultBrandId
                                      ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})'
                                      : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(
                          Icons.close,
                          color: AppColors.textMuted,
                          size: 20.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    controller: controller,
                    readOnly: true,
                    keyboardType: TextInputType.none,
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
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: profitColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: profitColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSalesSummaryRow(
                          'Kar Orani',
                          marginRatio == null
                              ? cost == 0
                                    ? 'Maliyet 0'
                                    : '-'
                              : '%${marginRatio.toStringAsFixed(1)}',
                          valueColor: marginRatio == null
                              ? AppColors.gold
                              : profitColor,
                        ),
                        _buildSalesSummaryRow(
                          'Kar',
                          marginAmount.toStringAsFixed(1),
                          valueColor: profitColor,
                        ),
                        _buildSalesSummaryRow(
                          'Talep',
                          baseHourlyDemand > 0
                              ? '${_describeDemandEffect(demandMultiplier)} / ${estimatedHourlyDemand.toStringAsFixed(1)} saat'
                              : _describeDemandEffect(demandMultiplier),
                          valueColor: demandColor,
                        ),
                        if (basePrice > 0)
                          _buildSalesSummaryRow(
                            'Piyasa Fiyatina Gore',
                            _formatSignedPercent(vsBasePercent),
                            valueColor: vsBasePercent <= 0
                                ? AppColors.green
                                : AppColors.red,
                          ),
                        SizedBox(height: 4.h),
                        Text(
                          averagePrice > 0
                              ? 'Piyasa ortalamasi: ${averagePrice.toStringAsFixed(1)}'
                              : basePrice > 0
                              ? 'Kalite ${slot.qualityLevel} piyasa fiyati: ${basePrice.toStringAsFixed(1)} (x${qualityPriceMultiplier.toStringAsFixed(2)})'
                              : 'Fiyat arttikca talep azalir, dustukce talep artar.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  NumericKeyboard(
                    controller: controller,
                    allowDecimal: true,
                    buttonHeight: 44.h,
                    shortcuts: shortcuts,
                    onChanged: (value) {
                      setState(() {
                        previewPrice =
                            double.tryParse(value.replaceAll(',', '.')) ?? 0;
                      });
                    },
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Iptal'),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                          ),
                          onPressed: () => savePrice(dialogContext),
                          child: const Text(
                            'Kaydet',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ],
                ),
              ),
            ),
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

    const defaultBrandId = '00000000-0000-0000-0000-000000000000';
    final existingSignatures = store.slots
        .where((storeSlot) => storeSlot.id != slot.id)
        .where(
          (storeSlot) =>
              (storeSlot.productId ?? '').isNotEmpty &&
              storeSlot.qualityLevel > 0,
        )
        .map(
          (storeSlot) =>
              '${storeSlot.productId}|${storeSlot.qualityLevel}|${storeSlot.brandId.isEmpty ? defaultBrandId : storeSlot.brandId}',
        )
        .toSet();

    final List<dynamic> products = (result['products'] ?? []).where((product) {
      final productId = product['product_id']?.toString() ?? '';
      final qualityLevel = (product['quality_level'] as num?)?.toInt() ?? 1;
      final brandId =
          product['brand_id']?.toString().isNotEmpty == true
              ? product['brand_id'].toString()
              : defaultBrandId;
      final signature = '$productId|$qualityLevel|$brandId';
      return !existingSignatures.contains(signature);
    }).toList();

    if (products.isEmpty) {
      if (context.mounted) {
        _showInfo(
          context,
          'Magaza deposunda secilebilir yeni urun-kalite-brand kombinasyonu bulunamadi.',
        );
      }
      return;
    }

    final options = products.map((product) {
      final qualityLevel = (product['quality_level'] as num?)?.toInt() ?? 1;
      final quantity = (product['quantity'] as num?)?.toInt() ?? 0;
      return ProductSelectionOption(
        id: product['warehouse_slot_id']?.toString() ?? '',
        title: (product['name'] ?? 'Bilinmeyen Urun').toString(),
        subtitle: 'Kalite $qualityLevel | Stok: $quantity',
        iconPath: (product['icon'] ?? 'default').toString(),
        badgeText: 'Magaza Deposu',
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
          sourceWarehouseSlotId: product['warehouse_slot_id']?.toString(),
        );

    if (parentContext.mounted) {
      if (result['success'] == true) {
        final productId = product['product_id']?.toString() ?? '';
        final qualityLevel = (product['quality_level'] as num?)?.toInt() ?? 1;
        final brandId =
            product['brand_id']?.toString() ??
            '00000000-0000-0000-0000-000000000000';
        ref.read(storeDetailPageProvider(store.id).notifier).patchSlotProduct(
          slotId: slot.id,
          productId: productId,
          qualityLevel: qualityLevel,
          brandId: brandId,
          productName: _productNameFromMap(product),
          productIcon: _productIconFromMap(product),
        );
        ref.read(storesListProvider.notifier).patchSlotProduct(
          storeId: store.id,
          slotId: slot.id,
          productId: productId,
          qualityLevel: qualityLevel,
          brandId: brandId,
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
    final page = ref.read(storeDetailPageProvider(store.id)).value;
    final storeWarehouse = page?.storeWarehouse;
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) {
      _showError(context, 'Once gecerli bir urun secin.');
      return;
    }

    if (storeWarehouse == null) {
      _showError(context, 'Bu magazaya bagli depo bulunamadi.');
      return;
    }

    final shouldLockQuality = _shouldLockStoreSlotQualityV2(slot);
    final slotBrandId =
        slot.brandId.isEmpty
            ? '00000000-0000-0000-0000-000000000000'
            : slot.brandId;
    final matchingSlots = storeWarehouse.slots.where((warehouseSlot) {
      if (warehouseSlot.productId != productId) return false;
      if (warehouseSlot.quantity <= 0) return false;
      if (shouldLockQuality && warehouseSlot.qualityLevel != slot.qualityLevel) {
        return false;
      }
      final warehouseBrandId =
          warehouseSlot.brandId.isEmpty
              ? '00000000-0000-0000-0000-000000000000'
              : warehouseSlot.brandId;
      if (warehouseBrandId != slotBrandId) {
        return false;
      }
      return true;
    }).toList();

    if (matchingSlots.isEmpty) {
      _showInfo(
        context,
        shouldLockQuality
            ? 'Magaza deposunda bu urunun secili urun-kalite-brand standardina uygun stogu yok.'
            : 'Magaza deposunda bu urune ait uygun stok bulunamadi.',
      );
      return;
    }

    final options = matchingSlots.map((warehouseSlot) {
      return WarehouseSelectionOption(
        id: warehouseSlot.id,
        title: storeWarehouse.name,
        subtitle:
            '${warehouseSlot.productName}${warehouseSlot.brandId != _defaultBrandId ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})' : ''} | Kalite ${warehouseSlot.qualityLevel}',
        badgeText: 'Magaza Deposu',
        infoText: '${warehouseSlot.quantity} Adet',
        isHighlightBadge: true,
        onTap: () {
          Navigator.pop(context);
          _showStoreWarehouseTransferQuantityDialog(
            context,
            ref,
            store,
            slot,
            warehouseSlot,
          );
        },
      );
    }).toList();

    WarehouseSelectionSheet.show(
      context: context,
      title: 'Magaza Deposu Stogu',
      options: options,
    );
  }

  void _showStoreWarehouseTransferQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    StoreWarehouseSlotSummaryModel warehouseSlot,
  ) {
    final controller = TextEditingController(text: '1');
    final maxCanTake = slot.capacity - slot.quantity - slot.pendingQuantity;
    final limit = warehouseSlot.quantity < maxCanTake
        ? warehouseSlot.quantity
        : maxCanTake.toInt();

    if (limit <= 0) {
      _showWarning(context, 'Slot kapasitesi dolu veya depoda stok yok.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          void updateQuantity(String value) {
            final parsed = int.tryParse(value) ?? 1;
            final safe = limit <= 0 ? 0 : parsed.clamp(1, limit);
            final safeText = safe.toString();

            if (controller.text != safeText) {
              controller.value = TextEditingValue(
                text: safeText,
                selection: TextSelection.collapsed(offset: safeText.length),
              );
            }
          }

          return Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.h,
                16.w,
                MediaQuery.of(context).viewInsets.bottom + 16.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Magaza Deposundan Cek',
                            style: AppTextStyles.h1.copyWith(fontSize: 20.sp),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: Icon(
                            Icons.close,
                            color: AppColors.textMuted,
                            size: 20.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '${warehouseSlot.productName}${warehouseSlot.brandId != _defaultBrandId ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})' : ''} | Kalite ${warehouseSlot.qualityLevel}',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: controller,
                      readOnly: true,
                      showCursor: true,
                      enableInteractiveSelection: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Miktar',
                        labelStyle: const TextStyle(color: AppColors.textMuted),
                        helperText:
                            '1 - $limit adet arasi (Depo: ${warehouseSlot.quantity}, Slot: $maxCanTake)',
                        helperStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.sp,
                        ),
                        filled: true,
                        fillColor: AppColors.cardBg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: AppColors.gold),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    NumericKeyboard(
                      controller: controller,
                      onChanged: updateQuantity,
                      shortcuts: [
                        NumericKeyboardShortcut(
                          label: '1/4',
                          value: limit <= 0 ? '0' : (limit ~/ 4).clamp(1, limit).toString(),
                        ),
                        NumericKeyboardShortcut(
                          label: 'Yarisi',
                          value: limit <= 0 ? '0' : (limit ~/ 2).clamp(1, limit).toString(),
                        ),
                        NumericKeyboardShortcut(
                          label: 'Tamami',
                          value: limit.toString(),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        onPressed: () {
                          final qty = int.tryParse(controller.text) ?? 0;
                          if (qty <= 0 || qty > limit) {
                            _showWarning(context, 'Gecersiz miktar!');
                            return;
                          }
                          Navigator.pop(dialogContext);
                          _startStoreWarehouseTransfer(
                            context,
                            ref,
                            store,
                            slot,
                            warehouseSlot,
                            qty,
                          );
                        },
                        child: Text(
                          'TRANSFER ET',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startStoreWarehouseTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    StoreWarehouseSlotSummaryModel warehouseSlot,
    int quantity,
  ) async {
    final productId = slot.productId;
    final needsSlotSetup =
        !_shouldLockStoreSlotQualityV2(slot) &&
        productId != null &&
        productId.isNotEmpty &&
        (slot.productId == null || slot.qualityLevel != warehouseSlot.qualityLevel);

    if (needsSlotSetup) {
      final setupResult = await ref.read(storeActionProvider).setStoreSlotProduct(
            slotId: slot.id,
            sourceWarehouseSlotId: warehouseSlot.id,
          );

      if (setupResult['success'] != true) {
        if (!context.mounted) return;
        _showError(context, 'Hata: ${setupResult['message']}');
        return;
      }
    }

    final result = await ref.read(storeActionProvider).transferStoreWarehouseStockToSlot(
          storeSlotId: slot.id,
          warehouseSlotId: warehouseSlot.id,
          quantity: quantity,
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
      _showSuccess(context, 'Stok magazaya tasindi.');
      return;
    }

    _showError(context, result['message'] ?? 'Transfer basarisiz.');
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

  Future<void> _startStoreWarehouseOutboundFlow(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
  ) async {
    final page = ref.read(storeDetailPageProvider(store.id)).value;
    final storeWarehouse = page?.storeWarehouse;

    if (slot.quantity <= 0) {
      _showError(context, 'Gonderilecek stok bulunmuyor.');
      return;
    }

    if (storeWarehouse == null) {
      _showError(context, 'Bu magazaya bagli depo bulunamadi.');
      return;
    }

    _showStoreWarehouseReturnQuantityDialog(
      context,
      ref,
      store,
      slot,
      storeWarehouse,
    );
  }

  void _showStoreWarehouseReturnQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    StoreWarehouseSummaryModel storeWarehouse,
  ) {
    final controller = TextEditingController(text: '1');
    final limit = slot.quantity;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
          title: Text(
            'Magaza Deposuna Gonder',
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
                        (slot.productName ?? 'Urun') +
                            (slot.brandId != _defaultBrandId
                                ? ' (${ref.read(playerBrandCompanyProvider).value?.brandName ?? 'Markali'})'
                                : ''),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${store.name} -> ${storeWarehouse.name}',
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
                          _buildStatusPill('Anlik Ic Transfer', AppColors.green),
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
                      () => _applyStoreWarehouseReturnQuantity(
                        controller,
                        (limit / 4).ceil(),
                        limit,
                        setState,
                      ),
                    ),
                    _buildQuickQuantityButton(
                      'Yari',
                      () => _applyStoreWarehouseReturnQuantity(
                        controller,
                        (limit / 2).ceil(),
                        limit,
                        setState,
                      ),
                    ),
                    _buildQuickQuantityButton(
                      'Tamami',
                      () => _applyStoreWarehouseReturnQuantity(
                        controller,
                        limit,
                        limit,
                        setState,
                      ),
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
                _startStoreWarehouseReturnTransfer(
                  context,
                  ref,
                  store,
                  slot,
                  qty,
                );
              },
              child: const Text(
                'Transfer Et',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
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

  void _applyStoreWarehouseReturnQuantity(
    TextEditingController controller,
    int value,
    int limit,
    void Function(void Function()) setState,
  ) {
    final clamped = value.clamp(1, limit);
    setState(() {
      controller.text = clamped.toString();
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    });
  }

  Future<void> _startStoreWarehouseReturnTransfer(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    int quantity,
  ) async {
    final result = await ref.read(storeActionProvider).returnStoreSlotStockToStoreWarehouse(
          storeSlotId: slot.id,
          quantity: quantity,
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
      _showSuccess(context, 'Stok magaza deposuna gonderildi.');
      return;
    }

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

