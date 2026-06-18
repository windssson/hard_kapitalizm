import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_detail_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';

class MineDetailScreen extends ConsumerStatefulWidget {
  final String mineId;

  const MineDetailScreen({super.key, required this.mineId});

  @override
  ConsumerState<MineDetailScreen> createState() => _MineDetailScreenState();
}

class _MineDetailScreenState extends ConsumerState<MineDetailScreen> {
  static const Map<int, int> _mineBoostStarCosts = {
    6: 3,
    12: 6,
    24: 12,
  };

  void _refreshMineDetail() {
    ref.invalidate(mineDetailProvider(widget.mineId));
    ref.invalidate(activeMineBoostProvider(widget.mineId));
    ref.invalidate(activeMineUpgradeProvider(widget.mineId));
    ref.read(mineDetailProvider(widget.mineId).future);
    ref.read(activeMineBoostProvider(widget.mineId).future);
    ref.read(activeMineUpgradeProvider(widget.mineId).future);
  }

  Future<void> _refreshMineEcosystem({
    String? warehouseId,
    bool includeTransfers = false,
    bool includeWarehouseList = false,
    bool includePlayer = true,
  }) async {
    _refreshMineDetail();
    ref.invalidate(mineListProvider);
    if (includePlayer) {
      ref.invalidate(playerProvider);
    }

    if (includeWarehouseList || (warehouseId != null && warehouseId.isNotEmpty)) {
      ref.invalidate(warehouseListProvider);
    }

    if (warehouseId != null && warehouseId.isNotEmpty) {
      ref.invalidate(warehouseDetailProvider(warehouseId));
    }

    if (includeTransfers) {
      ref.invalidate(buyerTransferMapProvider);
      ref.invalidate(buyerTransferHistoryProvider);
    }

    await ref.read(mineDetailProvider(widget.mineId).future);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(mineDetailProvider(widget.mineId));
    final activeBoost = ref.watch(activeMineBoostProvider(widget.mineId)).value;
    final activeUpgrade = ref.watch(activeMineUpgradeProvider(widget.mineId)).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Maden Yonetimi'),
            Expanded(
              child: detailAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      style: TextStyle(color: AppColors.red, fontSize: 13.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (detail) => RefreshIndicator(
                  onRefresh: () async {
                    _refreshMineDetail();
                    await ref.read(mineDetailProvider(widget.mineId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(5.w, 8.h, 5.w, 24.h),
                    children: [
                      _buildHero(detail),
                      SizedBox(height: 10.h),
                      _buildQuickActions(
                        context,
                        ref,
                        detail,
                        activeBoost,
                        activeUpgrade,
                      ),
                      if (activeBoost != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveMineBoostCard(boost: activeBoost),
                      ],
                      if (activeUpgrade != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveMineUpgradeCard(
                          upgrade: activeUpgrade,
                          onFinishWithGold: () =>
                              _finishMineUpgradeWithGold(activeUpgrade),
                          calculateStarCost: _calculateUpgradeStarCost,
                          formatCountdown: _formatCountdown,
                        ),
                      ],
                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Uretim Hatti',
                        'Madende secili kaynagi, stok durumunu ve depoya sevkleri buradan yonetebilirsin.',
                        icon: Icons.hardware_rounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      _buildProductionCard(
                        context,
                        ref,
                        detail,
                        activeBoost,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(MineDetailModel detail) {
    final outputQty = detail.totalOutputQuantity;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68.w,
                    height: 68.w,
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CachedAssetImage(
                      fileName: detail.mineType.icon,
                      fit: BoxFit.contain,
                      errorWidget: Icon(
                        Icons.diamond_rounded,
                        color: AppColors.gold,
                        size: 30.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.mine.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                detail.mineType.name,
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: AppColors.gold,
                                    size: 14.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      detail.cityName,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 74.w),
                          child: _buildHeroChipColumn(detail),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  'Cevher stogu',
                  '$outputQty/${detail.mine.outputCapacity}',
                  AppColors.green,
                  ratio: _safeProgress(
                    outputQty.toDouble(),
                    detail.mine.outputCapacity.toDouble(),
                  ),
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(
    String label,
    String value,
    Color color, {
    required double ratio,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14.sp),
              SizedBox(width: 7.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          ),
          SizedBox(height: 7.h),
          Container(
            height: 5.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChipColumn(MineDetailModel detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [_buildTag('Lv ${detail.mine.level}', AppColors.gold)],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    final hasProduct = detail.product != null;
    final canBoost = hasProduct && detail.mine.isActive;
    final canUpgrade = detail.mine.isActive;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Wrap(
        spacing: 10.w,
        runSpacing: 10.h,
        children: [
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              detail.mine.isActive ? 'Durdur' : 'Baslat',
              detail.mine.isActive
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              detail.mine.isActive ? AppColors.red : AppColors.green,
              hasProduct
                  ? () => _toggleMineActive(context, ref, detail)
                  : () {
                      AppSnackbar.show(
                        context,
                        title: 'Bilgi',
                        message:
                            'Uretimi baslatmadan once madene bir kaynak atamalisin.',
                        type: SnackbarType.info,
                      );
                    },
            ),
          ),
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              'Boost',
              Icons.flash_on_rounded,
              canBoost ? AppColors.goldDark : AppColors.textMuted,
              canBoost
                  ? () => _showMineBoostSheet(context, ref, detail, activeBoost)
                  : () {
                      AppSnackbar.show(
                        context,
                        title: 'Bilgi',
                        message: hasProduct
                            ? 'Boost baslatmak icin madenin aktif olmasi gerekir.'
                            : 'Boost baslatmadan once madene bir kaynak atamalisin.',
                        type: SnackbarType.info,
                      );
                    },
            ),
          ),
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              'Yukselt',
              Icons.upgrade_rounded,
              canUpgrade ? AppColors.green : AppColors.textMuted,
              canUpgrade
                  ? () =>
                      _showMineUpgradeSheet(context, ref, detail, activeUpgrade)
                  : () {
                      AppSnackbar.show(
                        context,
                        title: 'Bilgi',
                        message:
                            'Yukseltme baslatmak icin madenin aktif olmasi gerekir.',
                        type: SnackbarType.info,
                      );
                    },
            ),
          ),
          SizedBox(
            width: 100.w,
            child: _buildActionButton(
              'Rapor',
              Icons.query_stats_rounded,
              AppColors.blue,
              () => context.push(
                '/production-report/mine/${detail.mine.id}?name=${Uri.encodeComponent(detail.mine.name)}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15.sp),
            SizedBox(height: 3.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(icon, color: color, size: 16.sp),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.sp,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
          ),
          if (action != null) ...[
            SizedBox(height: 12.h),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildProductionCard(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    BuildingBoostModel? activeBoost,
  ) {
    if (detail.product == null) {
      return _buildEmptyCard(
        'Madende henuz secili bir kaynak yok. Once kaynak secerek uretimi baslat.',
        action: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _showProductDialog(context, ref, detail),
            icon: const Icon(Icons.category_outlined),
            label: const Text('Kaynak Sec'),
          ),
        ),
      );
    }

    final product = detail.product!;
    final outputInventory = detail.outputInventories.isNotEmpty
        ? detail.outputInventories.first
        : null;
    final quantity = detail.totalOutputQuantity;
    final progress = _safeProgress(
      quantity.toDouble(),
      detail.mine.outputCapacity.toDouble(),
    );

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(
        detail.mine.isActive ? AppColors.gold : null,
        18.r,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58.w,
                height: 58.w,
                padding: EdgeInsets.all(9.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: CachedAssetImage(
                  fileName: product.urunIconu,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.urunAdi,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              _buildQualityStars(detail.mine.qualityLevel),
                              SizedBox(height: 4.h),
                              Text(
                                'Maliyet: ${(outputInventory?.cost ?? 0).toStringAsFixed(2)} TL',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTag(
                              detail.mine.isActive ? 'AKTIF' : 'PASIF',
                              detail.mine.isActive
                                  ? AppColors.green
                                  : AppColors.red,
                            ),
                            SizedBox(width: 6.w),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              offset: const Offset(0, 40),
                              color: AppColors.cardBgLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                side: BorderSide(
                                  color: AppColors.border.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Container(
                                padding: EdgeInsets.all(6.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Icon(
                                  Icons.more_vert,
                                  color: AppColors.textMuted,
                                  size: 18.sp,
                                ),
                              ),
                              onSelected: (value) {
                                if (value == 'product') {
                                  _showProductDialog(context, ref, detail);
                                } else if (value == 'toggle') {
                                  _toggleMineActive(context, ref, detail);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'product',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.category,
                                        color: AppColors.gold,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'Kaynak Degistir',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        detail.mine.isActive
                                            ? Icons.stop_circle
                                            : Icons.play_circle,
                                        color: detail.mine.isActive
                                            ? AppColors.red
                                            : AppColors.green,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        detail.mine.isActive
                                            ? 'Uretimi Durdur'
                                            : 'Uretime Basla',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cevher stogu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: outputInventory != null && quantity > 0
                          ? () => _startInventoryToWarehouseFlow(
                                context,
                                ref,
                                detail,
                                outputInventory,
                              )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.blue.withValues(alpha: 0.16),
                        foregroundColor: AppColors.blue,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.r),
                          side: BorderSide(
                            color: AppColors.blue.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                      icon: Icon(Icons.move_up_rounded, size: 14.sp),
                      label: Text(
                        'Urunu Depoya Gonder',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  '$quantity / ${detail.mine.outputCapacity}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999.r),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6.h,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Icon(Icons.schedule, color: AppColors.textMuted, size: 14.sp),
              SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                  'Tahmini saatlik uretim: ${_estimateProductionPerHour(detail, activeBoost)}',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityStars(int qualityLevel) {
    if (qualityLevel <= 0) {
      return Text(
        'Kalite yok',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: EdgeInsets.only(right: 2.w),
          child: Icon(
            index < qualityLevel ? Icons.star : Icons.star_border,
            color: index < qualityLevel ? AppColors.gold : AppColors.textMuted,
            size: 14.sp,
          ),
        );
      }),
    );
  }

  double _safeProgress(double current, double max) {
    if (max <= 0) return 0;
    return (current / max).clamp(0.0, 1.0);
  }

  String _estimateProductionPerHour(
    MineDetailModel detail,
    BuildingBoostModel? activeBoost,
  ) {
    final product = detail.product;
    if (product == null) return '-';
    final amount = product.uretimAdedi * (activeBoost?.multiplier ?? 1);
    return amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(1);
  }

  int _calculateUpgradeStarCost(DateTime finishAt) {
    final remaining = finishAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 0;
    return (remaining.inMinutes / 10).ceil().clamp(1, 999999);
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

  Future<void> _showMineBoostSheet(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
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
              'Maden Boostu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              activeBoost != null
                  ? 'Bu madende zaten aktif bir boost var. Sure dolana kadar uretim x${activeBoost.multiplier.toStringAsFixed(1)} hizla calisir.'
                  : 'Boost basladiginda madenin uretim hizi sure boyunca 2 katina cikar.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            if (activeBoost == null)
              ..._mineBoostStarCosts.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await ref
                          .read(mineActionProvider)
                          .startMineBoost(
                            mineId: detail.mine.id,
                            durationHours: entry.key,
                            starCost: entry.value,
                            syncProviders: false,
                          );
                      if (!context.mounted) return;
                      if (result['success'] == true) {
                        await _refreshMineEcosystem();
                        AppSnackbar.show(
                          context,
                          title: 'Basarili',
                          message: 'Maden boostu baslatildi.',
                          type: SnackbarType.success,
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message:
                              result['message'] ?? 'Maden boostu baslatilamadi.',
                          type: SnackbarType.error,
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
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Katsayi x2.0',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: AppColors.gold,
                                size: 16.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${entry.value}',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              _buildEmptyCard(
                'Aktif boost bitene kadar yeni boost baslatilamaz.',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMineUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) {
        final nextLevel = detail.mine.level + 1;
        final nextOutputCapacity = detail.mine.outputCapacity * 2;
        final durationMinutes = detail.mineType.constructionTimeMinutes * nextLevel;
        final upgradeCost = detail.mineType.cost * nextLevel;

        return Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maden Yukseltmesi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                activeUpgrade != null
                    ? 'Bu madende zaten devam eden bir yukseltme var.'
                    : 'Her seviye artisinda cikti kapasitesi 2 katina cikar.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 16.h),
              if (activeUpgrade == null)
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seviye ${detail.mine.level} -> $nextLevel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'Cikti kapasitesi: ${detail.mine.outputCapacity} -> $nextOutputCapacity',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Sure: ${durationMinutes} dk',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Maliyet: $upgradeCost TL',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetContext);
                            final result = await ref
                                .read(mineActionProvider)
                                .startMineUpgrade(
                                  detail.mine.id,
                                  syncProviders: false,
                                );
                            if (!context.mounted) return;
                            if (result['success'] == true) {
                              await _refreshMineEcosystem();
                              AppSnackbar.show(
                                context,
                                title: 'Basarili',
                                message: 'Maden yukseltmesi baslatildi.',
                                type: SnackbarType.success,
                              );
                            } else {
                              AppSnackbar.show(
                                context,
                                title: 'Hata',
                                message:
                                    result['message'] ??
                                    'Maden yukseltmesi baslatilamadi.',
                                type: SnackbarType.error,
                              );
                            }
                          },
                          icon: const Icon(Icons.upgrade_rounded),
                          label: const Text('Yukseltmeyi Baslat'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildEmptyCard(
                  'Aktif yukseltme tamamlanmadan yeni bir yukseltme baslatilamaz.',
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishMineUpgradeWithGold(
    BuildingUpgradeModel upgrade,
  ) async {
    final result = await ref
        .read(mineActionProvider)
        .finishMineUpgradeWithGold(upgrade.id, syncProviders: false);

    if (!mounted) return;

    if (result['success'] == true) {
      await _refreshMineEcosystem();
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Maden yukseltmesi tamamlandi.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yukseltme tamamlanamadi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
  ) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref.read(mineActionProvider).getSelectableProducts(
            typeId: detail.mineType.id,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString(),
        type: SnackbarType.error,
      );
      return;
    }

    if (!context.mounted) return;
    final options = products.map((selectableProduct) {
      final product = selectableProduct.product;
      return ProductSelectionOption(
        id: product.id,
        title: product.urunAdi,
        subtitle: 'Saatlik uretim: ${product.uretimAdedi}',
        badgeText: 'Maks Kalite: ${selectableProduct.maxQualityLevel}',
        iconPath: product.urunIconu,
        onTap: () async {
          Navigator.pop(context);
          await _selectMineProduct(
            context,
            ref,
            detail,
            selectableProduct,
          );
        },
      );
    }).toList();

    await ProductSelectionSheet.show(
      context: context,
      title: 'Kaynak Sec',
      options: options,
    );
  }

  Future<void> _selectMineProduct(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    SelectableProductionProductModel selectableProduct,
  ) async {
    final product = selectableProduct.product;
    final result = await ref.read(mineActionProvider).setMineProduct(
          mineId: detail.mine.id,
          productId: product.id,
          syncProviders: false,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await _refreshMineEcosystem(includePlayer: false);
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Kaynak basariyla secildi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Kaynak secilemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _toggleMineActive(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
  ) async {
    final result = await ref.read(mineActionProvider).setMineActive(
          mineId: detail.mine.id,
          isActive: !detail.mine.isActive,
          syncProviders: false,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await _refreshMineEcosystem();
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: detail.mine.isActive
            ? 'Maden pasif moda alindi.'
            : 'Maden aktif edildi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Maden durumu guncellenemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _startInventoryToWarehouseFlow(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    MineProductionInventoryModel inventory,
  ) async {
    List<ProductionLogisticsWarehouseOption> warehouses;
    try {
      warehouses = await ref
          .read(mineActionProvider)
          .getWarehousesForProductionLogistics(
            productionCityId: detail.mine.cityId,
            productId: inventory.productId,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackbarType.error,
      );
      return;
    }

    if (!context.mounted) return;
    if (warehouses.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu urunu kabul eden aktif depon yok.',
        type: SnackbarType.info,
      );
      return;
    }

    final options = warehouses.map((warehouse) {
      final warehouseId = warehouse.id;
      final sameCity = warehouse.isSameCity;
      return WarehouseSelectionOption(
        id: warehouseId,
        title: warehouse.name,
        subtitle: warehouse.cityName,
        badgeText: sameCity ? 'Anlık Transfer' : 'Lojistik Transfer',
        infoText: 'Gonderilecek: ${inventory.quantity} adet | Urun',
        isHighlightBadge: sameCity,
        onTap: () {
          Navigator.pop(context);
          _showQuantityDialog(
            context: context,
            maxQuantity: inventory.quantity,
            title: 'Miktar Girin',
            subtitle:
                '${inventory.product?.urunAdi ?? inventory.productId} depoya aktarılacak',
            onConfirm: (quantity) async {
              if (sameCity) {
                final result = await ref
                    .read(mineActionProvider)
                    .transferProductionInventoryToWarehouse(
                      productionInventoryId: inventory.id,
                      warehouseId: warehouseId,
                      quantity: quantity,
                      syncProviders: false,
                    );
                if (!context.mounted) return;
                if (result['success'] == true) {
                  await _refreshMineEcosystem(
                    warehouseId: warehouseId,
                    includePlayer: false,
                  );
                  AppSnackbar.show(
                    context,
                    title: 'Başarılı',
                    message: 'Transfer tamamlandı.',
                    type: SnackbarType.success,
                  );
                  return;
                }
                AppSnackbar.show(
                  context,
                  title: 'Hata',
                  message:
                      result['message'] ?? 'Transfer başarısız oldu.',
                  type: SnackbarType.error,
                );
                return;
              }

              await _startMineLogisticsOutputTransfer(
                context: context,
                ref: ref,
                detail: detail,
                inventory: inventory,
                warehouseId: warehouseId,
                quantity: quantity,
              );
            },
          );
        },
      );
    }).toList();

    if (!context.mounted) return;
    options.sort((a, b) {
      if (a.isHighlightBadge != b.isHighlightBadge) {
        return a.isHighlightBadge ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });
    await WarehouseSelectionSheet.show(
      context: context,
      title: 'Hedef Depo Seç',
      options: options,
    );
  }

  Future<void> _startMineLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required MineDetailModel detail,
    required MineProductionInventoryModel inventory,
    required String warehouseId,
    required int quantity,
  }) async {
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
          .read(mineActionProvider)
          .getProductionOutputTransferVehicleOptions(
            productionInventoryId: inventory.id,
            buyerWarehouseId: warehouseId,
            quantity: quantity,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: e.toString().replaceFirst('Exception: ', ''),
        type: SnackbarType.error,
      );
      return;
    }

    if (!context.mounted) return;
    if (vehicleResult.options.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message:
            vehicleResult.unavailableReason ??
            'Bu transfer icin uygun arac bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: 'Maden Lojistigi',
      subtitle: '$quantity adet urun icin uygun araci secin',
      options: vehicleResult.options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(mineActionProvider)
            .startProductionToWarehouseTransfer(
              productionInventoryId: inventory.id,
              buyerWarehouseId: warehouseId,
              quantity: quantity,
              vehicleId: vehicleId,
              syncProviders: false,
            );
        if (!context.mounted) return;
        if (result.success) {
          await _refreshMineEcosystem(
            warehouseId: warehouseId,
            includeTransfers: true,
          );
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: 'Maden urunu transferi icin arac yola cikti.',
            type: SnackbarType.success,
          );
          return;
        }
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: result.message.isNotEmpty
              ? result.message
              : 'Lojistik transferi baslatilamadi.',
          type: SnackbarType.error,
        );
      },
    );
  }

  void _showProductionVehicleOptionsSheet({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<ProductionLogisticsVehicleOption> options,
    required Future<void> Function(String? vehicleId) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
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
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = options[index];
                  return TransferVehicleOptionCard(
                    vehicleName: option.vehicleName,
                    isRental: option.isRental,
                    capacity: option.capacity,
                    distanceKm: option.distanceKm,
                    durationLabel: _formatTransferDuration(
                      option.estimatedDurationSeconds,
                    ),
                    transportCost: option.totalPrice,
                    rentalCost: option.rentalCost,
                    fuelCost: option.fuelCost,
                    fuelNeeded: option.fuelNeeded,
                    conditionNeeded: option.conditionNeeded,
                    canSelect: option.canSelect,
                    isSelected: false,
                    disabledReason: option.disabledReason,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await onSelected(option.vehicleId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTransferDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }

  Future<void> _showQuantityDialog({
    required BuildContext context,
    required int maxQuantity,
    required String title,
    required String subtitle,
    required Future<void> Function(int quantity) onConfirm,
  }) async {
    final controller = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          title,
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              readOnly: true,
              showCursor: true,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Miktar (Maks: $maxQuantity)',
                labelStyle: const TextStyle(color: AppColors.gold),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            NumericKeyboard(
              controller: controller,
              shortcuts: [
                NumericKeyboardShortcut(
                  label: '1/4',
                  value: (maxQuantity / 4).floor().toString(),
                ),
                NumericKeyboardShortcut(
                  label: 'Yari',
                  value: (maxQuantity / 2).floor().toString(),
                ),
                NumericKeyboardShortcut(
                  label: 'Tamami',
                  value: maxQuantity.toString(),
                ),
              ],
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
            onPressed: () async {
              final quantity = int.tryParse(controller.text) ?? 0;
              if (quantity <= 0 || quantity > maxQuantity) {
                AppSnackbar.show(
                  context,
                  title: 'Hata',
                  message: 'Gecersiz miktar!',
                  type: SnackbarType.error,
                );
                return;
              }
              Navigator.pop(dialogContext);
              await onConfirm(quantity);
            },
            child: const Text(
              'Onayla',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveMineBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveMineBoostCard({required this.boost});

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

class _ActiveMineUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveMineUpgradeCard({
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
                      'Maden Yukseltmesi Devam Ediyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Seviye ${upgrade.currentLevel} -> ${upgrade.targetLevel} | Cikti ${upgrade.previousOutputCapacity} -> ${upgrade.nextOutputCapacity}',
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
              label: Text(
                '${calculateStarCost(upgrade.finishAt)} yildiz ile bitir',
              ),
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
