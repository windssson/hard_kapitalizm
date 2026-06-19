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
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
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

  String? get _currentBrandName =>
      ref.read(playerBrandCompanyProvider).value?.brandName;

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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Urun Gonder',
                  Icons.local_shipping_rounded,
                  AppColors.blue,
                  () => _startMineSendFlow(context, ref, detail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
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
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
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
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Yukselt',
                  Icons.upgrade_rounded,
                  canUpgrade ? AppColors.green : AppColors.textMuted,
                  canUpgrade
                      ? () => _showMineUpgradeSheet(
                            context,
                            ref,
                            detail,
                            activeUpgrade,
                          )
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
              SizedBox(width: 8.w),
              Expanded(
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
    final isBranded =
        detail.mine.brandId != SelectableProductionProductModel.defaultBrandId;

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
              // Left side: Large Icon Container
              Container(
                width: 70.w,
                height: 70.w,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: BrandedProductImage(
                  fileName: product.urunIconu,
                  fit: BoxFit.contain,
                  brandName: isBranded ? _currentBrandName : null,
                  showFrame: false,
                ),
              ),
              SizedBox(width: 12.w),
              // Right side: Title & Stats Row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            product.urunAdi,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        if (isBranded) ...[
                          _buildTag('MARKALI', AppColors.gold),
                          SizedBox(width: 6.w),
                        ],
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
                            padding: EdgeInsets.all(5.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Icon(
                              Icons.more_vert,
                              color: AppColors.textMuted,
                              size: 16.sp,
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
                    SizedBox(height: 8.h),
                    _buildMineStatsRow(detail, outputInventory, activeBoost),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _buildOutputSummaryRow(context, ref, detail, outputInventory),
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

  Widget _buildMineStatsRow(
    MineDetailModel detail,
    MineProductionInventoryModel? outputInventory,
    BuildingBoostModel? activeBoost,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kalite',
                style: TextStyle(color: AppColors.textMuted, fontSize: 8.sp),
              ),
              SizedBox(height: 2.h),
              _buildQualityStars(detail.mine.qualityLevel),
            ],
          ),
          Container(width: 1.w, height: 18.h, color: Colors.white10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Birim Maliyet',
                style: TextStyle(color: AppColors.textMuted, fontSize: 8.sp),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: AppColors.gold,
                    size: 11.sp,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    '${(outputInventory?.cost ?? 0).toStringAsFixed(2)} TL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(width: 1.w, height: 18.h, color: Colors.white10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Üretim / Saat',
                style: TextStyle(color: AppColors.textMuted, fontSize: 8.sp),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, color: AppColors.green, size: 11.sp),
                  SizedBox(width: 3.w),
                  Text(
                    _estimateProductionPerHour(detail, activeBoost),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSummaryRow(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    MineProductionInventoryModel? inventory,
  ) {
    final quantity = inventory?.quantity ?? 0;
    final isBranded =
        (inventory?.brandId ?? detail.mine.brandId) !=
        SelectableProductionProductModel.defaultBrandId;
    final progress = _safeProgress(
      quantity.toDouble(),
      detail.mine.outputCapacity.toDouble(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: AppColors.green,
              size: 14.sp,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                'Cevher stogu $quantity/${detail.mine.outputCapacity}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isBranded) ...[
              SizedBox(width: 6.w),
              _buildInlineMetaChip('Markali', AppColors.gold),
            ],
          ],
        ),
        SizedBox(height: 6.h),
        Container(
          width: double.infinity,
          height: 7.h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineMetaChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
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
                        if (!context.mounted) return;
                        AppSnackbar.show(
                          context,
                          title: 'Basarili',
                          message: 'Maden boostu baslatildi.',
                          type: SnackbarType.success,
                        );
                      } else {
                        if (!context.mounted) return;
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
                        'Sure: $durationMinutes dk',
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
                               if (!context.mounted) return;
                               AppSnackbar.show(
                                 context,
                                 title: 'Basarili',
                                 message: 'Maden yukseltmesi baslatildi.',
                                 type: SnackbarType.success,
                               );
                             } else {
                               if (!context.mounted) return;
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

    if (result['success'] == true) {
      await _refreshMineEcosystem();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Maden yukseltmesi tamamlandi.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
      return;
    }

    if (!mounted) return;
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
        badgeText:
            'Maks Kalite: ${selectableProduct.maxQualityLevel}'
            '${selectableProduct.hasPreferredBrand ? ' ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ Marka Hazir' : ''}',
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
      if (!context.mounted) return;
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
      if (!context.mounted) return;
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

  Future<void> _startMineSendFlow(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
  ) async {
    final sendableInventories =
        detail.outputInventories.where((item) => item.quantity > 0).toList();
    if (sendableInventories.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Depoya gonderilebilecek stok bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    List<Map<String, dynamic>> warehouses;
    try {
      warehouses = await ref.read(mineActionProvider).getPlayerWarehousesRaw();
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

    final options = <WarehouseSelectionOption>[];
    for (final warehouse in warehouses) {
      final acceptedProductIds = _parseMineAcceptedProductIds(
        (warehouse['warehouse_type'] as Map?)?['accepted_product_ids'],
      );
      final eligibleInventories = sendableInventories
          .where((inventory) => acceptedProductIds.contains(inventory.productId))
          .toList();
      if (eligibleInventories.isEmpty) continue;

      final warehouseOption = ProductionLogisticsWarehouseOption.fromJson(
        warehouse,
        productionCityId: detail.mine.cityId,
      );
      options.add(
        WarehouseSelectionOption(
          id: warehouseOption.id,
          title: warehouseOption.name,
          subtitle: warehouseOption.cityName,
          badgeText:
              warehouseOption.isSameCity ? 'Anlik Transfer' : 'Lojistik Transfer',
          infoText: '${eligibleInventories.length} uygun stok secilebilir',
          isHighlightBadge: warehouseOption.isSameCity,
          onTap: () {
            Navigator.pop(context);
            _showMineOutboundSelectionSheet(
              context: context,
              ref: ref,
              detail: detail,
              targetWarehouse: warehouseOption,
              inventories: eligibleInventories,
            );
          },
        ),
      );
    }

    if (!context.mounted) return;
    if (options.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu stoklari kabul eden aktif depon yok.',
        type: SnackbarType.info,
      );
      return;
    }

    options.sort((a, b) {
      if (a.isHighlightBadge != b.isHighlightBadge) {
        return a.isHighlightBadge ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });
    await WarehouseSelectionSheet.show(
      context: context,
      title: 'Hedef Depo Sec',
      options: options,
    );
  }

  Future<void> _showMineOutboundSelectionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required MineDetailModel detail,
    required ProductionLogisticsWarehouseOption targetWarehouse,
    required List<MineProductionInventoryModel> inventories,
  }) async {
    final selectedQuantities = <String, int>{};
    final sortedInventories = [...inventories]
      ..sort((a, b) => (a.product?.urunAdi ?? a.productId).compareTo(
            b.product?.urunAdi ?? b.productId,
          ));

    Future<void> openQuantityEditor(
      BuildContext sheetContext,
      StateSetter modalSetState,
      MineProductionInventoryModel item,
    ) async {
      final controller = TextEditingController(
        text: ((selectedQuantities[item.id] ?? item.quantity).clamp(
          0,
          item.quantity,
        )).toString(),
      );
      final result = await showDialog<int>(
        context: sheetContext,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            item.product?.urunAdi ?? item.productId,
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kalite ${item.qualityLevel} | Stok: ${item.quantity}',
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
                  labelText: 'Miktar (Maks: ${item.quantity})',
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
                    value: (item.quantity / 4)
                        .floor()
                        .clamp(1, item.quantity)
                        .toString(),
                  ),
                  NumericKeyboardShortcut(
                    label: 'Yari',
                    value: (item.quantity / 2)
                        .floor()
                        .clamp(1, item.quantity)
                        .toString(),
                  ),
                  NumericKeyboardShortcut(
                    label: 'Tamami',
                    value: item.quantity.toString(),
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
              onPressed: () {
                final quantity = int.tryParse(controller.text) ?? 0;
                if (quantity <= 0 || quantity > item.quantity) {
                  AppSnackbar.show(
                    sheetContext,
                    title: 'Hata',
                    message: 'Gecersiz miktar!',
                    type: SnackbarType.error,
                  );
                  return;
                }
                Navigator.pop(dialogContext, quantity);
              },
              child: const Text('Kaydet', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );

      if (result == null) return;
      modalSetState(() {
        selectedQuantities[item.id] = result;
      });
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, modalSetState) {
          final selectedItems = sortedInventories
              .where((item) => (selectedQuantities[item.id] ?? 0) > 0)
              .map(
                (item) => _SelectedMineProductionTransferItem(
                  inventory: item,
                  quantity: selectedQuantities[item.id] ?? 0,
                ),
              )
              .toList();
          final totalQuantity = selectedItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );

          return SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Depoya Gonderilecek Stoklari Sec',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${targetWarehouse.name} | ${targetWarehouse.cityName}',
                    style: TextStyle(color: AppColors.goldLight, fontSize: 12.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${selectedItems.length} stok | $totalQuantity adet secildi',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sortedInventories.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 10.h),
                      itemBuilder: (_, index) {
                        final item = sortedInventories[index];
                        final selectedQuantity = selectedQuantities[item.id] ?? 0;
                        final isSelected = selectedQuantity > 0;
                        return Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color:
                                  (isSelected
                                          ? AppColors.green
                                          : AppColors.borderGoldLight)
                                      .withValues(
                                        alpha: isSelected ? 0.35 : 0.15,
                                      ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product?.urunAdi ?? item.productId,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Kalite ${item.qualityLevel} | Stok ${item.quantity}',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              OutlinedButton(
                                onPressed: () => openQuantityEditor(
                                  sheetContext,
                                  modalSetState,
                                  item,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isSelected
                                      ? AppColors.green
                                      : AppColors.goldLight,
                                ),
                                child: Text(
                                  isSelected ? 'Adet: $selectedQuantity' : 'Ekle',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: selectedItems.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              if (targetWarehouse.isSameCity) {
                                final result = await ref
                                    .read(mineActionProvider)
                                    .startMultiProductionToWarehouseTransfer(
                                      sourceOwnerKind: 'mine',
                                      sourceOwnerId: widget.mineId,
                                      buyerWarehouseId: targetWarehouse.id,
                                      items: selectedItems
                                          .map(
                                            (item) => {
                                              'production_inventory_id':
                                                  item.inventory.id,
                                              'quantity': item.quantity,
                                            },
                                          )
                                          .toList(),
                                      syncProviders: false,
                                    );
                                if (!context.mounted) return;
                                if (result.success) {
                                  await _refreshMineEcosystem(
                                    warehouseId: targetWarehouse.id,
                                    includeTransfers: true,
                                    includePlayer: false,
                                  );
                                  if (!context.mounted) return;
                                  AppSnackbar.show(
                                    context,
                                    title: 'Basarili',
                                    message: 'Secilen stoklar depoya gonderildi.',
                                    type: SnackbarType.success,
                                  );
                                  return;
                                }
                                AppSnackbar.show(
                                  context,
                                  title: 'Hata',
                                  message: result.message.isNotEmpty
                                      ? result.message
                                      : 'Transfer basarisiz oldu.',
                                  type: SnackbarType.error,
                                );
                                return;
                              }

                              await _startMineMultiLogisticsOutputTransfer(
                                context: context,
                                ref: ref,
                                detail: detail,
                                targetWarehouse: targetWarehouse,
                                items: selectedItems,
                              );
                            },
                      icon: const Icon(Icons.local_shipping_rounded),
                      label: const Text('Transferi Baslat'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startMineMultiLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required MineDetailModel detail,
    required ProductionLogisticsWarehouseOption targetWarehouse,
    required List<_SelectedMineProductionTransferItem> items,
  }) async {
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    final totalQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalVolume = items.fold<double>(
      0,
      (sum, item) =>
          sum + ((item.inventory.product?.birimHacim ?? 0) * item.quantity),
    );
    try {
      vehicleResult = await ref
          .read(mineActionProvider)
          .getProductionRouteVehicleOptions(
            sourceCityId: detail.mine.cityId,
            targetCityId: targetWarehouse.cityId,
            totalVolume: totalVolume,
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
      subtitle: '$totalQuantity adet urun icin uygun araci secin',
      options: vehicleResult.options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(mineActionProvider)
            .startMultiProductionToWarehouseTransfer(
              sourceOwnerKind: 'mine',
              sourceOwnerId: widget.mineId,
              buyerWarehouseId: targetWarehouse.id,
              items: items
                  .map(
                    (item) => {
                      'production_inventory_id': item.inventory.id,
                      'quantity': item.quantity,
                    },
                  )
                  .toList(),
              vehicleId: vehicleId,
              syncProviders: false,
            );
        if (!context.mounted) return;
        if (result.success) {
          await _refreshMineEcosystem(
            warehouseId: targetWarehouse.id,
            includeTransfers: true,
            includePlayer: false,
          );
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: 'Maden urunleri icin arac yola cikti.',
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
    required Future<void> Function(String vehicleId) onSelected,
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
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
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

}

class _SelectedMineProductionTransferItem {
  final MineProductionInventoryModel inventory;
  final int quantity;

  const _SelectedMineProductionTransferItem({
    required this.inventory,
    required this.quantity,
  });
}

Set<String> _parseMineAcceptedProductIds(dynamic rawValue) {
  if (rawValue == null) return const <String>{};
  return rawValue
      .toString()
      .replaceAll('[', '')
      .replaceAll(']', '')
      .replaceAll('{', '')
      .replaceAll('}', '')
      .replaceAll('"', '')
      .replaceAll("'", '')
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
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

