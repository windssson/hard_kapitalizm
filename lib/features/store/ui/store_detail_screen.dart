import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';
import 'package:hard_kapitalizm/features/store/models/store_sale_result_model.dart';

class StoreDetailScreen extends ConsumerStatefulWidget {
  final String storeId;

  const StoreDetailScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen> {
  bool _salesCheckDone = false;

  @override
  void initState() {
    super.initState();
    _refreshOnEntry();
  }

  void _refreshOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _salesCheckDone = false;
      ref.invalidate(storeDetailProvider(widget.storeId));
      ref.read(storeDetailProvider(widget.storeId).future);
    });
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
    final storeAsync = ref.watch(storeDetailProvider(widget.storeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onItemSelected: _onNavSelected,
      ),
      body: SafeArea(
        child: storeAsync.when(
          data: (store) {
            _scheduleStoreSalesCheck(store);
            return _buildMainContent(context, ref, store);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
          error: (e, s) => _buildErrorState(ref, e),
        ),
      ),
    );
  }

  void _scheduleStoreSalesCheck(StoreModel store) {
    if (_salesCheckDone) return;
    _salesCheckDone = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final result = await ref
          .read(storeActionProvider)
          .processStoreSalesOnEntry(store.id);

      if (!mounted) return;

      if (result.success != true) {
        _salesCheckDone = false;
        return;
      }

      if (result.processed) {
        ref.invalidate(storeDetailProvider(store.id));
        ref.invalidate(playerStreamProvider);
      }

      if (!result.processed || !result.hasVisibleSales) {
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
            color: Colors.white,
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
                  '${result.totalRevenue.toStringAsFixed(1)}',
                  valueColor: AppColors.green,
                ),
                _buildSalesSummaryRow(
                  'Toplam Kar',
                  '${result.totalProfit.toStringAsFixed(1)}',
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
                      color: Colors.white.withValues(alpha: 0.04),
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
                            color: Colors.white,
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
              color: valueColor ?? Colors.white,
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
    StoreModel store,
  ) {
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
                _buildImmersiveHeader(store),
                SizedBox(height: 16.h),
                _buildQuickActions(context, ref, store),
                SizedBox(height: 16.h),
                _buildMetricsGrid(store),
                SizedBox(height: 24.h),
                Text('Magaza Raflari', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)),
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

  Widget _buildImmersiveHeader(StoreModel store) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black54,
            AppColors.navBg.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 2.w),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CachedAssetImage(fileName: store.storeType.icon, fit: BoxFit.contain),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: store.isActive ? Colors.greenAccent : Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                            color: store.isActive ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.redAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.textMuted, size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(store.cityName ?? 'Bilinmiyor', style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp, fontWeight: FontWeight.w500)),
                    SizedBox(width: 16.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('Seviye ${store.level}', style: TextStyle(color: AppColors.gold, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, StoreModel store) {
    final canOpenNewSlot = store.currentSlotCount < store.maxSlotCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildQuickActionButton(
          icon: Icons.insights,
          label: 'Durum',
          color: Colors.blueAccent,
          onTap: () => _showUpgradeInfoSheet(context, store),
        ),
        _buildQuickActionButton(
          icon: Icons.bar_chart,
          label: 'Rapor',
          color: Colors.purpleAccent,
          onTap: () => context.push('/store/${store.id}/report'),
        ),
        _buildQuickActionButton(
          icon: Icons.add_box,
          label: 'Slot Ac',
          color: AppColors.gold,
          onTap: canOpenNewSlot ? () => _handleOpenSlot(context, ref, store) : null,
        ),
        _buildQuickActionButton(
          icon: Icons.history,
          label: 'Gecmis',
          color: AppColors.textPrimary,
          onTap: () => context.push('/store/${store.id}/history'),
        ),
      ],
    );
  }

    Future<void> _handleOpenSlot(
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
  ) async {

    final result =
        await ref.read(storeActionProvider).addStoreSlot(store.id);

    if (context.mounted) {
      if (result['success'] == true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final _ = ref.refresh(storeDetailProvider(store.id));
        _showSuccess(context, 'Yeni slot basariyla acildi!');
      } else {
        _showError(context, result['message'] ?? 'Slot acilirken bir hata olustu.');
      }
    }
  }

  Widget _buildQuickActionButton(
{required IconData icon, required String label, required Color color, VoidCallback? onTap}) {
    final isDisabled = onTap == null;
    final displayColor = isDisabled ? Colors.grey : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: 80.w,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: displayColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: displayColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: displayColor, size: 24.sp),
            SizedBox(height: 6.h),
            Text(label, style: TextStyle(color: isDisabled ? Colors.grey : Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(StoreModel store) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompactMetricCol(
            title: 'Doluluk',
            value: '%${(store.summary.usedCapacityRatio * 100).toInt()}',
            icon: Icons.pie_chart,
            color: Colors.orangeAccent,
          ),
          _buildCompactMetricCol(
            title: 'Stok',
            value: '${store.summary.totalQuantity}/${store.summary.totalCapacity}',
            icon: Icons.inventory_2,
            color: Colors.blueAccent,
          ),
          _buildCompactMetricCol(
            title: 'Kar',
            value: '+₺${_formatValue(store.summary.totalStockSaleValue ?? 0)}',
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
        Text(value, style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold), maxLines: 1),
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
                      color: Colors.black26,
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
                        Text('Bos Slot', style: TextStyle(color: Colors.white70, fontSize: 15.sp, fontWeight: FontWeight.bold)),
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
                          color: Colors.black26,
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
                                  child: Text(slot.productName ?? '', style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                  color: barIndex < slot.qualityLevel ? qColor : Colors.white24,
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
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                                      color: Colors.white.withValues(alpha: 0.2),
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
                                child: Row(children: [Icon(Icons.local_shipping, color: AppColors.blue, size: 18.sp), SizedBox(width: 8.w), Text('Depoya Gonder', style: TextStyle(color: Colors.white, fontSize: 12.sp))]),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(children: [Icon(slot.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, color: slot.isActive ? Colors.redAccent : Colors.greenAccent, size: 18.sp), SizedBox(width: 8.w), Text(slot.isActive ? 'Pasif Yap' : 'Aktif Et', style: TextStyle(color: Colors.white, fontSize: 12.sp))]),
                              ),
                              PopupMenuItem(
                                value: 'change',
                                enabled: canEditProduct,
                                child: Row(children: [Icon(Icons.swap_horiz, color: AppColors.gold, size: 18.sp), SizedBox(width: 8.w), Text('Urunu Degistir', style: TextStyle(color: Colors.white, fontSize: 12.sp))]),
                              ),
                              PopupMenuItem(
                                value: 'clear',
                                enabled: canEditProduct,
                                child: Row(children: [Icon(Icons.cleaning_services, color: AppColors.red, size: 18.sp), SizedBox(width: 8.w), Text('Slotu Temizle', style: TextStyle(color: Colors.white, fontSize: 12.sp))]),
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
                          color: Colors.white,
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
                        color: Colors.white24,
                        label: 'Bos',
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMiniStatus(bool isActive) {
    return Container(
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        color: isActive ? AppColors.green : AppColors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isActive ? AppColors.green : AppColors.red).withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
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
      ref.invalidate(storeDetailProvider(store.id));
      ref.invalidate(storesListProvider);
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
            color: Colors.white,
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
              foregroundColor: Colors.white,
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
      ref.invalidate(storeDetailProvider(store.id));
      ref.invalidate(storesListProvider);
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
    double previewPrice = slot.price ?? 0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sheetContext, setState) {
          final marginAmount = previewPrice - cost;
          final marginRatio = cost > 0 ? (marginAmount / cost) * 100 : null;

          return AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(
              'Satis Fiyati',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
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
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Birim satis fiyati',
                    labelStyle: TextStyle(color: AppColors.gold),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.gold),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      previewPrice =
                          double.tryParse(value.replaceAll(',', '.')) ??
                          0;
                    });
                  },
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
                    ref.invalidate(storeDetailProvider(store.id));
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
  ) {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory, color: AppColors.gold),
                      SizedBox(width: 12.w),
                      Text(
                        'Urun Secimi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                // Product List
                Flexible(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: ref
                        .read(storeActionProvider)
                        .getAvailableProductsForStore(store.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(color: AppColors.gold),
                          ),
                        );
                      }

                      if (snapshot.hasError ||
                          snapshot.data?['success'] != true) {
                        return Padding(
                          padding: EdgeInsets.all(20.w),
                          child: Text(
                            'Urunler yuklenirken hata olustu: ${snapshot.data?['message'] ?? 'Bilinmeyen hata'}',
                            style: const TextStyle(color: AppColors.red),
                          ),
                        );
                      }

                      final List<dynamic> products =
                          snapshot.data?['products'] ?? [];

                      if (products.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.all(40.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppColors.textMuted, size: 48.sp),
                              SizedBox(height: 16.h),
                              Text(
                                'Bu magaza icin uygun veya eklenmemis urun bulunamadi.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.all(16.w),
                        itemCount: products.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _buildProductSelectionItem(
                            parentContext,
                            dialogContext,
                            ref,
                            store,
                            slot,
                            product,
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductSelectionItem(
    BuildContext parentContext,
    BuildContext dialogContext,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> product,
  ) {
    return GestureDetector(
      onTap: () => _handleProductSelection(
        parentContext,
        dialogContext,
        ref,
        store,
        slot,
        product,
      ),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              child: CachedAssetImage(
                fileName: product['icon'] ?? 'default',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Bilinmeyen Urun',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Baz Fiyat: ${product['base_price']} TL',
                    style: TextStyle(
                      color: AppColors.gold.withValues(alpha: 0.7),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle, color: AppColors.gold, size: 24.sp),
          ],
        ),
      ),
    );
  }

  Future<void> _handleProductSelection(
    BuildContext parentContext,
    BuildContext dialogContext,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    Map<String, dynamic> product,
  ) async {
    // Dialog'u kapat
    Navigator.pop(dialogContext);

    // Islemi yap
    final result = await ref.read(storeActionProvider).setStoreSlotProduct(
          slotId: slot.id,
          productId: product['id'],
        );

    if (parentContext.mounted) {
      if (result['success'] == true) {
        // Veritabaninin guncellenmesi icin cok kisa bir sure bekle
        await Future.delayed(const Duration(milliseconds: 500));
        final _ = ref.refresh(storeDetailProvider(store.id));
        _showSuccess(parentContext, '${product['name']} basariyla eklendi!');
      } else {
        _showError(parentContext, result['message'] ?? 'Urun eklenirken hata olustu.');
      }
    }
  }

  Widget _buildFinancialFooter(StoreModel store) {
    final stockCost = _calculateStoreStockCost(store);
    final stockSaleValue = _calculateStoreStockSaleValue(store);
    final pendingSale = _calculatePendingSaleValue(store);
    final estimatedProfit = stockSaleValue - stockCost;
    final averageMargin = stockCost > 0 ? (estimatedProfit / stockCost) * 100 : 0.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finansal Ozet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildFooterStat(
                  Icons.inventory_2,
                  'Stok Maliyeti',
                  _formatValue(stockCost),
                  AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: _buildFooterStat(
                  Icons.sell,
                  'Liste Degeri',
                  _formatValue(stockSaleValue),
                  AppColors.gold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildFooterStat(
                  Icons.trending_up,
                  'Tahmini Kar',
                  _formatSignedValue(estimatedProfit),
                  estimatedProfit >= 0 ? AppColors.green : AppColors.red,
                ),
              ),
              Expanded(
                child: _buildFooterStat(
                  Icons.av_timer,
                  'Bekleyen Satis',
                  pendingSale.toStringAsFixed(1),
                  AppColors.blue,
                ),
              ),
              Expanded(
                child: _buildFooterStat(
                  Icons.percent,
                  'Ort. Marj',
                  '${averageMargin.toStringAsFixed(1)}%',
                  averageMargin >= 0 ? AppColors.green : AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpgradeInfoSheet(BuildContext context, StoreModel store) {
    final slotUsage = store.maxSlotCount > 0
        ? (store.currentSlotCount / store.maxSlotCount) * 100
        : 0.0;
    final storageUsage = (store.summary.usedCapacityRatio * 100).clamp(0.0, 100.0);

    showModalBottomSheet(
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
              'Magaza Seviyesi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '${store.name} su an seviye ${store.level}. Bu panel slot ve stok kapasitesini hizlica takip etmen icin hazirlandi.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            _buildSalesSummaryRow(
              'Kullanilan Slot',
              '${store.currentSlotCount}/${store.maxSlotCount}',
            ),
            _buildSalesSummaryRow(
              'Slot Doluluk',
              '%${slotUsage.toStringAsFixed(0)}',
            ),
            _buildSalesSummaryRow(
              'Stok Doluluk',
              '%${storageUsage.toStringAsFixed(0)}',
            ),
            _buildSalesSummaryRow(
              'Bos Kapasite',
              store.summary.availableCapacity.toString(),
              valueColor: AppColors.gold,
            ),
            SizedBox(height: 14.h),
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



  Widget _buildLevelBadge(int level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldDark, AppColors.gold],
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        'Lv. $level',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeaderInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: AppColors.gold,
            size: 14.sp,
          ), // Just for icon consistency
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value, {
    bool showProgress = false,
    double progress = 0,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.gold, size: 12.sp),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showProgress) ...[
            SizedBox(height: 3.h),
            _buildMiniProgress(progress),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 30.h,
      color: AppColors.border.withValues(alpha: 0.3),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.cardBg.withValues(alpha: 0.55)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isDisabled
                ? AppColors.border.withValues(alpha: 0.2)
                : color.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isDisabled ? AppColors.textMuted : color,
              size: 16.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? AppColors.textMuted : Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildMiniProgress(double progress, [String? text]) {
    return Container(
      width: 90.w,
      height: 14.h,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Fill
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.goldDark, AppColors.gold.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ),
          ),
          if (text != null)
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 2),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterStat(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16.sp),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
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
            style: const TextStyle(color: Colors.white),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => ref.refresh(storeDetailProvider(widget.storeId)),
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

  String _formatSignedValue(double amount) {
    final prefix = amount >= 0 ? '+' : '-';
    return '$prefix${_formatValue(amount.abs())}';
  }

  double _calculateStoreStockCost(StoreModel store) {
    final summaryCost = store.summary.totalStockCostValue;
    if (summaryCost != null && summaryCost > 0) {
      return summaryCost;
    }

    return store.slots.fold<double>(
      0,
      (total, slot) => total + ((slot.cost ?? 0) * slot.quantity),
    );
  }

  double _calculateStoreStockSaleValue(StoreModel store) {
    final summarySaleValue = store.summary.totalStockSaleValue;
    if (summarySaleValue != null && summarySaleValue > 0) {
      return summarySaleValue;
    }

    return store.slots.fold<double>(
      0,
      (total, slot) => total + ((slot.price ?? 0) * slot.quantity),
    );
  }

  double _calculatePendingSaleValue(StoreModel store) {
    final summaryPending = store.summary.pendingSaleTotal;
    if (summaryPending != null && summaryPending > 0) {
      return summaryPending;
    }

    return store.slots.fold<double>(
      0,
      (total, slot) => total + (slot.pendingSale ?? 0),
    );
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
                  color: Colors.white,
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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

  Widget _buildActionBtn(String label, IconData icon, Color color, {VoidCallback? onTap}) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isDisabled 
              ? Colors.white.withValues(alpha: 0.03) 
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isDisabled 
                ? Colors.white.withValues(alpha: 0.05) 
                : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isDisabled ? AppColors.textMuted : color, size: 14.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? AppColors.textMuted : color,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
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
          color: Colors.white.withValues(alpha: 0.04),
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
                      color: Colors.white,
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

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => _buildWarehouseSelectionSheetV2(
        context,
        sheetContext,
        ref,
        store,
        slot,
        warehouses,
      ),
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

  Widget _buildWarehouseSelectionSheetV2(
    BuildContext parentContext,
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    List<dynamic> warehouses,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kaynak Depo Secin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${slot.productName} gonderecek depoyu secin',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.builder(
              itemCount: warehouses.length,
              itemBuilder: (context, index) {
                final warehouse = warehouses[index];
                final warehouseSlots =
                    warehouse['warehouse_slots'] as List<dynamic>? ?? const [];
                return Column(
                  children: warehouseSlots.map<Widget>((productSlot) {
                    final availableQty =
                        (productSlot['quantity'] as num?)?.toInt() ?? 0;
                    final qualityLevel =
                        (productSlot['quality_level'] as num?)?.toInt() ?? 1;
                    final sourceCityId =
                        (warehouse['city_id'] ??
                                warehouse['city']?['id'] ??
                                '')
                            .toString();
                    final cityName =
                        (warehouse['city']?['name'] ?? 'Bilinmeyen Sehir')
                            .toString();

                    return Card(
                      color: Colors.white.withValues(alpha: 0.05),
                      margin: EdgeInsets.only(bottom: 10.h),
                      child: ListTile(
                        leading: Icon(Icons.warehouse, color: AppColors.gold),
                        title: Text(
                          (warehouse['name'] ?? 'Depo').toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '$cityName | Kalite: $qualityLevel | Mevcut: $availableQty adet',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showQuantityTransferDialogV2(
                            parentContext,
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
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
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
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Miktar (Maks: $limit)',
                labelStyle: const TextStyle(color: AppColors.gold),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
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

    List<MarketTransferVehicleOptionModel> options = const [];
    try {
      options = await ref.read(storeActionProvider).getStoreTransferVehicleOptions(
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

    if (options.isEmpty) {
      if (context.mounted) {
        _showError(context, 'Bu transfer icin uygun arac bulunamadi.');
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
                color: Colors.white,
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
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
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
                        color: Colors.white.withValues(alpha: 0.04),
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
                                    color: Colors.white,
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
      await Future.delayed(const Duration(milliseconds: 300));
      ref.invalidate(storeDetailProvider(store.id));
      final isInstant = result['mode']?.toString() == 'instant';
      _showSuccess(
        context,
        isInstant
            ? 'Ayni sehir transferi tamamlandi.'
            : 'Lojistik transfer baslatildi. Arac yola cikti.',
      );
      return;
    }

    _showError(context, 'Hata: ${result['message']}');
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

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => _buildOutboundWarehouseSheet(
        context,
        sheetContext,
        ref,
        store,
        slot,
        warehouses,
      ),
    );
  }

  Widget _buildOutboundWarehouseSheet(
    BuildContext parentContext,
    BuildContext context,
    WidgetRef ref,
    StoreModel store,
    StoreSlotModel slot,
    List<Map<String, dynamic>> warehouses,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hedef Depo Secin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${slot.productName ?? 'Urun'} gondereceginiz depoyu secin',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.separated(
              itemCount: warehouses.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                final warehouse = warehouses[index];
                final cityName =
                    (warehouse['city']?['name'] ?? 'Bilinmeyen Sehir')
                        .toString();

                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: Icon(Icons.warehouse, color: AppColors.gold),
                    title: Text(
                      (warehouse['name'] ?? 'Depo').toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      cityName,
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.7),
                      ),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      Navigator.pop(context);
                      _showOutboundQuantityDialog(
                        parentContext,
                        ref,
                        store,
                        slot,
                        warehouse,
                        cityName,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
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

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Miktar Girin',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${slot.productName} -> ${(warehouse['name'] ?? 'Depo').toString()}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Miktar (Maks: $limit)',
                labelStyle: const TextStyle(color: AppColors.gold),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
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

    List<MarketTransferVehicleOptionModel> options = const [];
    try {
      options = await ref.read(storeActionProvider).getStoreToWarehouseVehicleOptions(
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

    if (options.isEmpty) {
      if (context.mounted) {
        _showError(context, 'Bu transfer icin uygun arac bulunamadi.');
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
                color: Colors.white,
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
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
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
                        color: Colors.white.withValues(alpha: 0.04),
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
                                    color: Colors.white,
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
      await Future.delayed(const Duration(milliseconds: 300));
      ref.invalidate(storeDetailProvider(store.id));
      final isInstant = result['mode']?.toString() == 'instant';
      _showSuccess(
        context,
        isInstant
            ? 'Ayni sehir gonderimi tamamlandi.'
            : 'Lojistik transfer baslatildi. Arac yola cikti.',
      );
      return;
    }

    _showError(context, 'Hata: ${result['message']}');
  }
}

