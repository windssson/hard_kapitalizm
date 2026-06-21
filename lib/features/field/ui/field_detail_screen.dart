import 'dart:math';

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
import 'package:hard_kapitalizm/core/utils/app_error_message.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/field/models/field_detail_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';

class FieldDetailScreen extends ConsumerStatefulWidget {
  final String fieldId;

  const FieldDetailScreen({super.key, required this.fieldId});

  @override
  ConsumerState<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends ConsumerState<FieldDetailScreen> {
  static const Map<int, int> _fieldBoostStarCosts = {
    6: 3,
    12: 6,
    24: 12,
  };

  String? get _currentBrandName =>
      ref.read(playerBrandCompanyProvider).value?.brandName;

  void _refreshFieldDetail() {
    ref.invalidate(fieldDetailProvider(widget.fieldId));
    ref.invalidate(activeFieldBoostProvider(widget.fieldId));
    ref.invalidate(activeFieldUpgradeProvider(widget.fieldId));
    ref.read(fieldDetailProvider(widget.fieldId).future);
    ref.read(activeFieldBoostProvider(widget.fieldId).future);
    ref.read(activeFieldUpgradeProvider(widget.fieldId).future);
  }

  Future<void> _refreshFieldEcosystem({
    String? warehouseId,
    bool includeTransfers = false,
    bool includeWarehouseList = false,
    bool includePlayer = true,
  }) async {
    _refreshFieldDetail();
    ref.invalidate(fieldListProvider);
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

    await ref.read(fieldDetailProvider(widget.fieldId).future);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerBrandCompanyProvider);
    final detailAsync = ref.watch(fieldDetailProvider(widget.fieldId));
    final activeBoost = ref.watch(activeFieldBoostProvider(widget.fieldId)).value;
    final activeUpgrade = ref.watch(
      activeFieldUpgradeProvider(widget.fieldId),
    ).value;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Ciftlik Yonetimi'),
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
                    _refreshFieldDetail();
                    await ref.read(fieldDetailProvider(widget.fieldId).future);
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
                        _ActiveFieldBoostCard(boost: activeBoost),
                      ],
                      if (activeUpgrade != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveFieldUpgradeCard(
                          upgrade: activeUpgrade,
                          onFinishWithGold: () =>
                              _finishFieldUpgradeWithGold(activeUpgrade),
                          calculateStarCost: _calculateUpgradeStarCost,
                          formatCountdown: _formatCountdown,
                        ),
                      ],
                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Ciftlikler',
                        'Her ciftlikte ekili urunu, kaliteyi ve uretim akislarini buradan yonetebilirsin.',
                        icon: Icons.tune_rounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      if (detail.slots.isEmpty)
                        _buildEmptyCard(
                          'Bu ciftlikte henuz aktif uretim slotu yok.',
                        )
                      else
                        ...detail.slots.map(
                          (slot) => _buildSlotCard(
                            context,
                            ref,
                            detail,
                            slot,
                            activeBoost,
                          ),
                        ),
                      if (detail.orphanInputInventories.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _buildSectionHeader(
                          'Bagli Olmayan Hammaddeler',
                          'Urun degisikligi sonrasinda elde kalan hammaddeleri burada depoya geri aktarabilirsin.',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.blue,
                        ),
                        SizedBox(height: 10.h),
                        ...detail.orphanInputInventories.map(
                          (inventory) => _buildSlotInventoryCard(
                            context,
                            ref,
                            detail,
                            inventory,
                          ),
                        ),
                      ],
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

  Widget _buildHero(FieldDetailModel detail) {
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
                      fileName: detail.fieldType.icon,
                      fit: BoxFit.contain,
                      errorWidget: Icon(
                        Icons.grass,
                        color: AppColors.green,
                        size: 32.sp,
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
                                detail.field.name,
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
                                detail.fieldType.name,
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
                  'Hammadde',
                  '${_calculateUsedCapacity(detail.inputInventories)}/${detail.field.inputCapacity}',
                  AppColors.blue,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.inputInventories),
                    detail.field.inputCapacity,
                  ),
                  icon: Icons.science_outlined,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildHeroStat(
                  'Uretilen urun',
                  '${_calculateUsedCapacity(detail.outputInventories)}/${detail.field.outputCapacity}',
                  AppColors.green,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.outputInventories),
                    detail.field.outputCapacity,
                  ),
                  icon: Icons.agriculture_outlined,
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
            height: 3.h,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
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

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    final canBoost = detail.slots.isNotEmpty;

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
                  'Urun Al',
                  Icons.download_rounded,
                  AppColors.gold,
                  () => _startFieldReceiveFlow(context, ref, detail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Urun Gonder',
                  Icons.local_shipping_rounded,
                  AppColors.blue,
                  () => _startFieldSendFlow(context, ref, detail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Slot Ac',
                  Icons.add_box_outlined,
                  AppColors.gold,
                  () => _handleAddSlot(context, ref, detail),
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
                      ? () => _showFieldBoostSheet(context, ref, detail, activeBoost)
                      : () {
                          AppSnackbar.show(
                            context,
                            title: 'Bilgi',
                            message: 'Boost baslatmadan once en az bir uretim slotu acmalisin.',
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
                  AppColors.green,
                  () => _showFieldUpgradeSheet(context, ref, detail, activeUpgrade),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Rapor',
                  Icons.query_stats_rounded,
                  AppColors.blue,
                  () => context.push(
                    '/production-report/field/${detail.field.id}?name=${Uri.encodeComponent(detail.field.name)}',
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

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
      ),
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

  Widget _buildSlotCard(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
    BuildingBoostModel? activeBoost,
  ) {
    final slotActiveColor = slot.isActive ? AppColors.green : AppColors.red;
    final isBranded = slot.brandId != SelectableProductionProductModel.defaultBrandId;
    final slotTitle = slot.isEmpty
        ? 'Bos Ciftlik ${slot.slotIndex}'
        : '${slot.product?.urunAdi ?? slot.productId ?? 'Bilinmeyen Urun'}${isBranded ? ' (${_currentBrandName ?? 'Markali'})' : ''}';
    final outputInventory = slot.isEmpty
        ? null
        : _outputInventoryForSlot(detail, slot);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(
        slot.isActive ? AppColors.gold : null,
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
                    color: !slot.isEmpty
                        ? AppColors.green.withValues(alpha: 0.3)
                        : Colors.white10,
                  ),
                ),
                child: slot.isEmpty || slot.product?.urunIconu == null
                    ? Icon(
                        Icons.add_circle_outline,
                        color: AppColors.textMuted,
                        size: 24.sp,
                      )
                    : BrandedProductImage(
                        fileName: slot.product!.urunIconu,
                        fit: BoxFit.contain,
                        brandName: slot.brandId !=
                                SelectableProductionProductModel
                                    .defaultBrandId
                            ? _currentBrandName
                            : null,
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
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            '#${slot.slotIndex}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            slotTitle,
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
                        _buildTag(
                          slot.isActive ? 'AKTIF' : 'PASIF',
                          slotActiveColor,
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
                              _showSlotProductDialog(
                                context,
                                ref,
                                detail,
                                slot,
                              );
                            } else if (value == 'toggle') {
                              _toggleSlotActive(context, ref, detail, slot);
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
                                    slot.isEmpty ? 'Urun Sec' : 'Urun Degistir',
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
                                    slot.isActive
                                        ? Icons.stop_circle
                                        : Icons.play_circle,
                                    color: slot.isActive
                                        ? AppColors.red
                                        : AppColors.green,
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    slot.isActive
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
                    if (slot.isEmpty)
                      Text(
                        'Beklemede. Ürün seçerek üretimi başlat.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10.sp,
                        ),
                      )
                    else
                      _buildSlotStatsRow(slot, outputInventory, activeBoost),
                  ],
                ),
              ),
            ],
          ),
          if (!slot.isEmpty) ...[
            if (outputInventory != null) ...[
              SizedBox(height: 10.h),
              _buildOutputSummaryRow(context, ref, detail, outputInventory),
            ],
            SizedBox(height: 10.h),
            _buildSlotFlowGroup(context, ref, detail, slot),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotStatsRow(
    ProductionSlotModel slot,
    ProductionInventoryModel? outputInventory,
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
              _buildQualityStars(slot.qualityLevel),
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
                    _estimateProductionPerHour(slot, activeBoost).toString(),
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

  Future<void> _showFieldBoostSheet(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
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
              'Ciftlik Boostu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              activeBoost != null
                  ? 'Bu ciftlikte zaten aktif bir boost var. Sure dolana kadar tum slotlar x${activeBoost.multiplier.toStringAsFixed(1)} hizla calisir.'
                  : 'Boost basladiginda tum ciftlik slotlarinin boost katsayisi 2 olur. Uretim hizi sure boyunca artar.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.sp,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            if (activeBoost == null)
              ..._fieldBoostStarCosts.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await ref
                          .read(fieldActionProvider)
                          .startFieldBoost(
                            fieldId: detail.field.id,
                            durationHours: entry.key,
                            starCost: entry.value,
                            syncProviders: false,
                          );
                      if (!context.mounted) return;
                      if (result['success'] == true) {
                        await _refreshFieldEcosystem();
                        if (!context.mounted) return;
                        AppSnackbar.show(
                          context,
                          title: 'Basarili',
                          message: 'Ciftlik boostu baslatildi.',
                          type: SnackbarType.success,
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message:
                              result['message'] ?? 'Ciftlik boostu baslatilamadi.',
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
                                    color: AppColors.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tum slotlar x2 uretim hizi kazanir',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${entry.value} â˜…',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 14.sp,
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
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.goldDark.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  'Aktif boost bitene kadar yeni boost baslatilamaz.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFieldUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    if (activeUpgrade != null) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu ciftlik icin zaten devam eden bir yukseltme var.',
        type: SnackbarType.info,
      );
      return;
    }

    final targetLevel = detail.field.level + 1;
    final upgradeCost = (detail.fieldType.cost * targetLevel).toDouble();
    final durationMinutes =
        (detail.fieldType.constructionTimeMinutes * targetLevel).clamp(
          1,
          999999,
        );
    final nextInputCapacity = detail.field.inputCapacity * 2;
    final nextOutputCapacity = detail.field.outputCapacity * 2;

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
              'Ciftlik Yukseltmesi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seviye ${detail.field.level} -> $targetLevel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Hammadde kapasitesi: ${detail.field.inputCapacity} -> $nextInputCapacity',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Uretilen urun kapasitesi: ${detail.field.outputCapacity} -> $nextOutputCapacity',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Sure: $durationMinutes dk',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Maliyet: TL ${upgradeCost.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final result = await ref
                      .read(fieldActionProvider)
                      .startFieldUpgrade(
                        detail.field.id,
                        syncProviders: false,
                      );
                  if (!context.mounted) return;
                  if (result['success'] == true) {
                    await _refreshFieldEcosystem();
                    if (!context.mounted) return;
                    AppSnackbar.show(
                      context,
                      title: 'Basarili',
                      message: 'Ciftlik yukseltmesi baslatildi.',
                      type: SnackbarType.success,
                    );
                    return;
                  }
                  AppSnackbar.show(
                    context,
                    title: 'Hata',
                    message: result['message'] ?? 'Yukseltme baslatilamadi.',
                    type: SnackbarType.error,
                  );
                },
                icon: const Icon(Icons.upgrade_rounded),
                label: const Text('Yukseltmeyi Baslat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finishFieldUpgradeWithGold(BuildingUpgradeModel upgrade) async {
    final result = await ref
        .read(fieldActionProvider)
        .finishFieldUpgradeWithGold(upgrade.id, syncProviders: false);

    if (!mounted) return;
    if (result['success'] == true) {
      await _refreshFieldEcosystem(includePlayer: false);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Ciftlik yukseltmesi tamamlandi.',
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

  Widget _buildHeroChipColumn(FieldDetailModel detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildTag('Lv ${detail.field.level}', AppColors.gold),
      ],
    );
  }

  Widget _buildSlotFlowGroup(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    final inputInventories = _inputInventoriesForSlot(detail, slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFlowSection(
          title: 'Hammadde',
          color: AppColors.blue,
          child: inputInventories.isEmpty
              ? _buildInlineEmptyState(
                  'Bu slot icin bagli hammadde stogu bulunmuyor.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSharedInputCapacityBar(detail, inputInventories),
                    SizedBox(height: 8.h),
                    ...inputInventories.map(
                      (inventory) => _buildCompactInventoryRow(inventory),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCompactInventoryRow(ProductionInventoryModel inventory) {
    final isBranded = !inventory.isInput &&
        inventory.brandId != SelectableProductionProductModel.defaultBrandId;
    final title = (inventory.product?.urunAdi.isNotEmpty == true
            ? inventory.product!.urunAdi
            : inventory.productId) +
        (isBranded ? ' (${_currentBrandName ?? 'Markali'})' : '');
    final color = AppColors.blue;

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: inventory.product?.urunIconu != null
                ? BrandedProductImage(
                    fileName: inventory.product!.urunIconu,
                    fit: BoxFit.contain,
                    brandName: isBranded ? _currentBrandName : null,
                    showFrame: false,
                  )
                : Icon(Icons.inventory_2, color: color, size: 14.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Text(
                  'Maliyet: ${inventory.cost.toStringAsFixed(2)} TL${inventory.pendingQuantity > 0 ? " | Yolda: ${inventory.pendingQuantity.toStringAsFixed(0)}" : ""}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              '${inventory.quantity}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSection({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMiniFlowHeader(title, color),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }

  Widget _buildMiniFlowHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7.r),
          ),
          child: Icon(
            Icons.science_outlined,
            color: color,
            size: 13.sp,
          ),
        ),
        SizedBox(width: 7.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineEmptyState(String message) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
      child: Text(
        message,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
      ),
    );
  }

  Widget _buildSharedInputCapacityBar(
    FieldDetailModel detail,
    List<ProductionInventoryModel> inventories,
  ) {
    final capacity = detail.field.inputCapacity;
    final totalStock = inventories.fold<int>(
      0,
      (sum, inventory) => sum + inventory.quantity,
    );
    final totalPending = inventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.pendingQuantity,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.blue.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$totalStock stok â€¢ ${totalPending.toStringAsFixed(1)} yolda / $capacity kapasite',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          _buildSegmentedCapacityBar(
            inventories: inventories,
            capacity: capacity,
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              ...inventories.map(
                (inventory) => _buildCapacityLegendChip(
                  inventory.product?.urunAdi.isNotEmpty == true
                      ? inventory.product!.urunAdi
                      : inventory.productId,
                  _inputColorForProduct(inventory.productId),
                ),
              ),
              _buildCapacityLegendChip('Yolda', AppColors.goldDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedCapacityBar({
    required List<ProductionInventoryModel> inventories,
    required int capacity,
  }) {
    if (capacity <= 0) {
      return Container(
        height: 8.h,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999.r),
        ),
      );
    }

    final segments = <({double amount, Color color})>[];
    for (final inventory in inventories) {
      if (inventory.quantity > 0) {
        segments.add((
          amount: inventory.quantity.toDouble(),
          color: _inputColorForProduct(inventory.productId),
        ));
      }
    }

    final totalPending = inventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.pendingQuantity,
    );
    if (totalPending > 0) {
      segments.add((amount: totalPending, color: AppColors.goldDark));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var left = 0.0;

        return Container(
          height: 8.h,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: Stack(
              children: [
                for (final segment in segments)
                  () {
                    final width = ((segment.amount / capacity) * maxWidth)
                        .clamp(0.0, maxWidth - left);
                    final positioned = Positioned(
                      left: left,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: width,
                        color: segment.color,
                      ),
                    );
                    left += width;
                    return positioned;
                  }(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCapacityLegendChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<ProductionInventoryModel> _inputInventoriesForSlot(
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    final product = slot.product;
    if (slot.isEmpty || product == null) return const [];
    final requiredInputQuality = max(1, slot.qualityLevel - 1);

    final inventories = detail.inputInventories
        .where(
          (inventory) =>
              product.inputProductIds.contains(inventory.productId) &&
              inventory.qualityLevel == requiredInputQuality,
        )
        .toList();

    inventories.sort((a, b) => a.productId.compareTo(b.productId));
    return inventories;
  }

  ProductionInventoryModel? _outputInventoryForSlot(
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) {
    if (slot.isEmpty) return null;

    for (final inventory in detail.outputInventories) {
      if (inventory.productId == slot.productId &&
          inventory.qualityLevel == slot.qualityLevel &&
          inventory.brandId == slot.brandId) {
        return inventory;
      }
    }
    return null;
  }

  Widget _buildSlotInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionInventoryModel inventory,
  ) {
    final isBranded = !inventory.isInput &&
        inventory.brandId != SelectableProductionProductModel.defaultBrandId;
    final title = (inventory.product?.urunAdi.isNotEmpty == true
            ? inventory.product!.urunAdi
            : inventory.productId) +
        (isBranded ? ' (${_currentBrandName ?? 'Markali'})' : '');
    final color = inventory.isInput ? AppColors.blue : AppColors.green;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: color.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: inventory.product?.urunIconu != null
                    ? BrandedProductImage(
                        fileName: inventory.product!.urunIconu,
                        fit: BoxFit.contain,
                        brandName:
                            !inventory.isInput &&
                                inventory.brandId !=
                                    SelectableProductionProductModel
                                        .defaultBrandId
                            ? _currentBrandName
                            : null,
                        showFrame: false,
                      )
                    : Icon(Icons.inventory_2, color: color, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        _buildQualityStars(inventory.qualityLevel),
                        if (!inventory.isInput) ...[
                          SizedBox(width: 6.w),
                          _buildInlineMetaChip(
                            inventory.brandId !=
                                    SelectableProductionProductModel
                                        .defaultBrandId
                                ? 'Markali'
                                : 'Brandsiz',
                            inventory.brandId !=
                                    SelectableProductionProductModel
                                        .defaultBrandId
                                ? AppColors.gold
                                : AppColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${inventory.quantity}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Divider(color: Colors.white.withValues(alpha: 0.04), height: 1),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: AppColors.textMuted,
                    size: 12.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Maliyet: ${inventory.cost.toStringAsFixed(2)} TL',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: inventory.pendingQuantity > 0
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: 12.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    inventory.pendingQuantity > 0
                        ? 'Yolda: ${inventory.pendingQuantity.toStringAsFixed(0)}'
                        : 'Yolda yok',
                    style: TextStyle(
                      color: inventory.pendingQuantity > 0
                          ? AppColors.goldLight
                          : AppColors.textMuted,
                      fontSize: 10.sp,
                      fontWeight: inventory.pendingQuantity > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
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
    FieldDetailModel detail,
    ProductionInventoryModel inventory,
  ) {
    final ratio = _inventoryRatio(inventory.quantity, detail.field.outputCapacity);
    final isBranded =
        inventory.brandId != SelectableProductionProductModel.defaultBrandId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.agriculture_outlined,
              color: AppColors.green,
              size: 14.sp,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                'Uretilen urun stogu ${inventory.quantity}/${detail.field.outputCapacity}',
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
            widthFactor: ratio.clamp(0.0, 1.0),
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

  Future<void> _handleAddSlot(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
  ) async {
    final result = await ref
        .read(fieldActionProvider)
        .addProductionSlot(detail.field.id, syncProviders: false);

    if (!context.mounted) return;
    if (result['success'] == true) {
      await _refreshFieldEcosystem(includePlayer: false);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Yeni uretim slotu acildi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Slot acilamadi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _toggleSlotActive(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) async {
    final result = await ref
        .read(fieldActionProvider)
        .setProductionSlotActive(
          slotId: slot.id,
          isActive: !slot.isActive,
          syncProviders: false,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      await _refreshFieldEcosystem(includePlayer: false);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Slot durumu guncellenemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _showSlotProductDialog(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
  ) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref
          .read(fieldActionProvider)
          .getSelectableProducts(ownerKind: 'field', typeId: detail.fieldType.id);
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

    final disabledProductIds = detail.slots
        .where((otherSlot) => otherSlot.id != slot.id)
        .map((otherSlot) => otherSlot.productId ?? '')
        .where((productId) => productId.isNotEmpty)
        .toSet();

    final options = products.map((selectableProduct) {
      final product = selectableProduct.product;
      final isDisabled = disabledProductIds.contains(product.id);
      return ProductSelectionOption(
        id: product.id,
        title: product.urunAdi + (selectableProduct.hasPreferredBrand ? ' (${_currentBrandName ?? 'Markali'})' : ''),
        subtitle: 'Saatlik üretim: ${product.uretimAdedi}',
        badgeText:
            'Maks Kalite: ${selectableProduct.maxQualityLevel}'
            '${selectableProduct.hasPreferredBrand ? ' • Marka Hazir' : ''}',
        iconPath: product.urunIconu,
        isDisabled: isDisabled,
        disabledReason: isDisabled ? 'Bu ürün başka bir slotta kullanılıyor' : null,
        onTap: () async {
          Navigator.pop(context);
          await _selectSlotProduct(
            context,
            ref,
            detail,
            slot,
            selectableProduct,
          );
        },
      );
    }).toList();

    if (!context.mounted) return;
    await ProductSelectionSheet.show(
      context: context,
      title: 'Ürün Seç',
      options: options,
    );
  }

  Future<void> _selectSlotProduct(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
    ProductionSlotModel slot,
    SelectableProductionProductModel selectableProduct,
  ) async {
    final product = selectableProduct.product;
    final qualityLevel = selectableProduct.suggestedOutputQualityLevel;
    final action = ref.read(fieldActionProvider);
    final result = slot.isEmpty
        ? await action.assignProductionSlotProduct(
            slotId: slot.id,
            productId: product.id,
            qualityLevel: qualityLevel,
            syncProviders: false,
          )
        : await action.changeProductionSlotProduct(
            slotId: slot.id,
            productId: product.id,
            qualityLevel: qualityLevel,
            syncProviders: false,
          );

    if (!context.mounted) return;
    final isSuccess = result['success'] == true;
    final resultMessage = result['message']?.toString().trim();
    final hasErrorLikeMessage =
        resultMessage != null &&
        resultMessage.isNotEmpty &&
        (resultMessage.contains('Exception') ||
            resultMessage.contains('Postgrest') ||
            resultMessage.contains('error') ||
            resultMessage.contains('hata'));

    if (isSuccess && !hasErrorLikeMessage) {
      await _refreshFieldEcosystem();
      if (!context.mounted) return;
      final deletedObsoleteCount =
          (result['deleted_obsolete_inventory_count'] as num?)?.toInt() ?? 0;
      final cleanupNote = deletedObsoleteCount > 0
          ? ' Eski bos kayitlardan $deletedObsoleteCount adet temizlendi.'
          : '';
      final isBranded = selectableProduct.hasPreferredBrand;
      final productName = product.urunAdi + (isBranded ? ' (${_currentBrandName ?? 'Markali'})' : '');
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: slot.isEmpty
            ? '$productName kalite $qualityLevel ile eklendi.'
            : '$productName kalite $qualityLevel olarak degistirildi.$cleanupNote',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: sanitizeUserFacingError(
        result['message'] ?? 'Urun secilemedi.',
      ),
      type: SnackbarType.error,
    );
  }

  Future<void> _startFieldReceiveFlow(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
  ) async {
    final targetInventories = detail.inputInventories
        .where((inventory) => inventory.product != null)
        .toList();
    if (targetInventories.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu ciftlikte aktif hammadde girdisi bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    final remainingInputCapacity = _calculateRemainingInputCapacity(
      detail.inputInventories,
      detail.field.inputCapacity,
    );
    if (remainingInputCapacity <= 0) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message:
            'Hammadde kapasitesi dolu. Once mevcut stok veya yoldaki transferler azalmali.',
        type: SnackbarType.info,
      );
      return;
    }

    List<Map<String, dynamic>> warehouses;
    try {
      warehouses = await ref
          .read(fieldActionProvider)
          .getPlayerWarehousesWithSlotsRaw();
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

    final targetByKey = <String, ProductionInventoryModel>{
      for (final inventory in targetInventories)
        _inventoryKey(inventory.productId, inventory.qualityLevel): inventory,
    };
    final warehouseChoices = <_FieldInboundWarehouseChoice>[];

    for (final warehouse in warehouses) {
      final slots = (warehouse['warehouse_slots'] as List<dynamic>? ?? const [])
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();
      final eligibleSlots = <_FieldInboundWarehouseSlotOption>[];
      for (final slot in slots) {
        final quantity = (slot['quantity'] as num?)?.toInt() ?? 0;
        if (quantity <= 0) continue;
        final key = _inventoryKey(
          slot['product_id']?.toString() ?? '',
          (slot['quality_level'] as num?)?.toInt() ?? 0,
        );
        final targetInventory = targetByKey[key];
        if (targetInventory == null) continue;
        eligibleSlots.add(
          _FieldInboundWarehouseSlotOption(
            warehouseSlotId: slot['id']?.toString() ?? '',
            productId: targetInventory.productId,
            productName:
                targetInventory.product?.urunAdi ??
                slot['product_name']?.toString() ??
                targetInventory.productId,
            productIcon:
                targetInventory.product?.urunIconu ??
                (slot['product'] as Map?)?['urun_iconu']?.toString(),
            qualityLevel: targetInventory.qualityLevel,
            availableQuantity: quantity,
            unitVolume: targetInventory.product?.birimHacim ?? 0,
            targetInventory: targetInventory,
          ),
        );
      }

      if (eligibleSlots.isEmpty) continue;
      final warehouseId = warehouse['id']?.toString() ?? '';
      final cityId = warehouse['city_id']?.toString() ?? '';
      final name = (warehouse['name'] ?? 'Depo').toString();
      final cityName = (warehouse['city']?['name'] ?? detail.cityName).toString();
      warehouseChoices.add(
        _FieldInboundWarehouseChoice(
          warehouseId: warehouseId,
          warehouseName: name,
          cityId: cityId,
          cityName: cityName,
          isSameCity: _isSameCity(cityId, detail.field.cityId),
          slots: eligibleSlots,
        ),
      );
    }

    if (!context.mounted) return;
    if (warehouseChoices.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message:
            'Bu ciftligin kullandigi hammaddeler icin uygun depo stogu bulunamadi.',
        type: SnackbarType.info,
      );
      return;
    }

    final options = warehouseChoices
        .map(
          (warehouse) => WarehouseSelectionOption(
            id: warehouse.warehouseId,
            title: warehouse.warehouseName,
            subtitle: warehouse.cityName,
            badgeText: warehouse.isSameCity ? 'Ayni Sehir' : 'Farkli Sehir',
            infoText:
                '${warehouse.slots.length} uygun stok | Bos kapasite: $remainingInputCapacity',
            isHighlightBadge: warehouse.isSameCity,
            onTap: () {
              Navigator.pop(context);
              _showFieldInboundSelectionSheet(
                context: context,
                ref: ref,
                detail: detail,
                warehouse: warehouse,
                remainingInputCapacity: remainingInputCapacity,
              );
            },
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.isHighlightBadge != b.isHighlightBadge) {
          return a.isHighlightBadge ? -1 : 1;
        }
        return a.title.compareTo(b.title);
      });

    await WarehouseSelectionSheet.show(
      context: context,
      title: 'Kaynak Depo Sec',
      options: options,
    );
  }

  Future<void> _startFieldSendFlow(
    BuildContext context,
    WidgetRef ref,
    FieldDetailModel detail,
  ) async {
    final sendableInventories = [
      ...detail.inputInventories.where((item) => item.quantity > 0),
      ...detail.orphanInputInventories.where((item) => item.quantity > 0),
      ...detail.outputInventories.where((item) => item.quantity > 0),
    ];
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
      warehouses = await ref.read(fieldActionProvider).getPlayerWarehousesRaw();
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
      final acceptedProductIds = _parseAcceptedProductIds(
        (warehouse['warehouse_type'] as Map?)?['accepted_product_ids'],
      );
      final eligibleInventories = sendableInventories
          .where((inventory) => acceptedProductIds.contains(inventory.productId))
          .toList();
      if (eligibleInventories.isEmpty) continue;

      final warehouseOption = ProductionLogisticsWarehouseOption.fromJson(
        warehouse,
        productionCityId: detail.field.cityId,
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
            _showFieldOutboundSelectionSheet(
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

  Future<void> _showFieldInboundSelectionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required FieldDetailModel detail,
    required _FieldInboundWarehouseChoice warehouse,
    required int remainingInputCapacity,
  }) async {
    final selectedQuantities = <String, int>{};

    int maxSelectableForSlot(_FieldInboundWarehouseSlotOption slot) {
      final selectedQuantity = warehouse.slots.fold<int>(0, (sum, current) {
        final selectedQty = selectedQuantities[current.warehouseSlotId] ?? 0;
        return sum + selectedQty;
      });
      final currentSelectedQty = selectedQuantities[slot.warehouseSlotId] ?? 0;
      final availableQuantity =
          remainingInputCapacity - selectedQuantity + currentSelectedQty;
      return availableQuantity.clamp(0, slot.availableQuantity);
    }

    Future<void> openQuantityEditor(
      BuildContext sheetContext,
      StateSetter modalSetState,
      _FieldInboundWarehouseSlotOption slot,
    ) async {
      final maxQuantity = maxSelectableForSlot(slot);
      final controller = TextEditingController(
        text: ((selectedQuantities[slot.warehouseSlotId] ?? maxQuantity).clamp(
          0,
          maxQuantity,
        )).toString(),
      );
      final result = await showDialog<int>(
        context: sheetContext,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            slot.productName,
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kalite ${slot.qualityLevel} | Stok: ${slot.availableQuantity}',
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
                    value: (maxQuantity / 4)
                        .floor()
                        .clamp(1, maxQuantity)
                        .toString(),
                  ),
                  NumericKeyboardShortcut(
                    label: 'Yari',
                    value: (maxQuantity / 2)
                        .floor()
                        .clamp(1, maxQuantity)
                        .toString(),
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
              onPressed: () {
                final quantity = int.tryParse(controller.text) ?? 0;
                if (quantity <= 0 || quantity > maxQuantity) {
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
        selectedQuantities[slot.warehouseSlotId] = result;
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
          final selectedItems = warehouse.slots
              .where(
                (slot) => (selectedQuantities[slot.warehouseSlotId] ?? 0) > 0,
              )
              .map(
                (slot) => _SelectedFieldInboundTransferItem(
                  slot: slot,
                  quantity: selectedQuantities[slot.warehouseSlotId] ?? 0,
                ),
              )
              .toList();
          final totalQuantity = selectedItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final totalVolume = selectedItems.fold<double>(
            0,
            (sum, item) => sum + (item.quantity * item.slot.unitVolume),
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
                    'Alinacak Hammaddeleri Sec',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${warehouse.warehouseName} | ${warehouse.cityName}',
                    style: TextStyle(color: AppColors.goldLight, fontSize: 12.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${selectedItems.length} stok | $totalQuantity adet | ${totalVolume.toStringAsFixed(1)} m3 secildi',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: warehouse.slots.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 10.h),
                      itemBuilder: (_, index) {
                        final slot = warehouse.slots[index];
                        final selectedQuantity =
                            selectedQuantities[slot.warehouseSlotId] ?? 0;
                        final isSelected = selectedQuantity > 0;
                        final maxQuantity = maxSelectableForSlot(slot);
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
                                      slot.productName,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Kalite ${slot.qualityLevel} | Stok ${slot.availableQuantity} | Hedef kapasite: ${slot.targetInventory.quantity}',
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
                                onPressed: maxQuantity <= 0
                                    ? null
                                    : () => openQuantityEditor(
                                          sheetContext,
                                          modalSetState,
                                          slot,
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
                              await _submitFieldInboundSelection(
                                context: context,
                                ref: ref,
                                detail: detail,
                                warehouse: warehouse,
                                items: selectedItems,
                              );
                            },
                      icon: const Icon(Icons.download_rounded),
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

  Future<void> _submitFieldInboundSelection({
    required BuildContext context,
    required WidgetRef ref,
    required FieldDetailModel detail,
    required _FieldInboundWarehouseChoice warehouse,
    required List<_SelectedFieldInboundTransferItem> items,
  }) async {
    final transferItems = items
        .map(
          (item) => {
            'warehouse_slot_id': item.slot.warehouseSlotId,
            'production_inventory_id': item.slot.targetInventory.id,
            'quantity': item.quantity,
          },
        )
        .toList();

    if (warehouse.isSameCity) {
      final result = await ref
          .read(fieldActionProvider)
          .startMultiWarehouseToProductionTransfer(
            sourceWarehouseId: warehouse.warehouseId,
            items: transferItems,
            syncProviders: false,
          );
      if (!context.mounted) return;
      if (!result.success) {
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

      await _refreshFieldEcosystem(
        includeTransfers: true,
        includeWarehouseList: true,
        includePlayer: false,
      );
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Secilen hammaddeler ciftlige aktarildi.',
        type: SnackbarType.success,
      );
      return;
    }

    await _startFieldGroupedLogisticsInputTransfer(
      context: context,
      ref: ref,
      detail: detail,
      warehouse: warehouse,
      items: items,
    );
  }

  Future<void> _startFieldGroupedLogisticsInputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FieldDetailModel detail,
    required _FieldInboundWarehouseChoice warehouse,
    required List<_SelectedFieldInboundTransferItem> items,
  }) async {
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    final totalQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalVolume = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.slot.unitVolume),
    );

    try {
      vehicleResult = await ref
          .read(fieldActionProvider)
          .getProductionRouteVehicleOptions(
            sourceCityId: warehouse.cityId,
            targetCityId: detail.field.cityId,
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
      title: 'Hammadde Lojistigi',
      subtitle: '$totalQuantity adet hammadde icin uygun araci secin',
      options: vehicleResult.options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(fieldActionProvider)
            .startMultiWarehouseToProductionTransfer(
              sourceWarehouseId: warehouse.warehouseId,
              items: items
                  .map(
                    (item) => {
                      'warehouse_slot_id': item.slot.warehouseSlotId,
                      'production_inventory_id': item.slot.targetInventory.id,
                      'quantity': item.quantity,
                    },
                  )
                  .toList(),
              vehicleId: vehicleId,
              syncProviders: false,
            );
        if (!context.mounted) return;
        if (result.success) {
          await _refreshFieldEcosystem(
            includeTransfers: true,
            includeWarehouseList: true,
            includePlayer: false,
          );
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: 'Secilen hammadde transferi icin arac yola cikti.',
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

  Future<void> _showFieldOutboundSelectionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required FieldDetailModel detail,
    required ProductionLogisticsWarehouseOption targetWarehouse,
    required List<ProductionInventoryModel> inventories,
  }) async {
    final sortedInventories = [...inventories]
      ..sort((a, b) {
        if (a.isInput != b.isInput) return a.isInput ? -1 : 1;
        return (a.product?.urunAdi ?? a.productId).compareTo(
          b.product?.urunAdi ?? b.productId,
        );
      });
    final selectedQuantities = <String, int>{};

    Future<void> openQuantityEditor(
      BuildContext sheetContext,
      StateSetter modalSetState,
      ProductionInventoryModel item,
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
            (item.product?.urunAdi ?? item.productId) +
                (!item.isInput &&
                        item.brandId !=
                            SelectableProductionProductModel.defaultBrandId
                    ? ' (${_currentBrandName ?? 'Markali'})'
                    : ''),
            style: TextStyle(color: Colors.white, fontSize: 18.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.isInput ? 'Hammadde' : 'Urun'} | Kalite ${item.qualityLevel} | Stok: ${item.quantity}',
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
                (item) => _SelectedFieldProductionTransferItem(
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
                                      (item.product?.urunAdi ?? item.productId) +
                                          (!item.isInput &&
                                                  item.brandId !=
                                                      SelectableProductionProductModel
                                                          .defaultBrandId
                                              ? ' (${_currentBrandName ?? 'Markali'})'
                                              : ''),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      '${item.isInput ? 'Hammadde' : 'Urun'} | Kalite ${item.qualityLevel} | Stok ${item.quantity}',
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
                                    .read(fieldActionProvider)
                                    .startMultiProductionToWarehouseTransfer(
                                      sourceOwnerKind: 'field',
                                      sourceOwnerId: widget.fieldId,
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
                                  await _refreshFieldEcosystem(
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

                              await _startFieldLogisticsOutputTransfer(
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

  Future<void> _startFieldLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FieldDetailModel detail,
    required ProductionLogisticsWarehouseOption targetWarehouse,
    required List<_SelectedFieldProductionTransferItem> items,
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
          .read(fieldActionProvider)
          .getProductionRouteVehicleOptions(
            sourceCityId: detail.field.cityId,
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
      title: items.first.inventory.isInput
          ? 'Hammadde Geri Gonderim Lojistigi'
          : 'Uretilen Urun Lojistigi',
      subtitle: items.first.inventory.isInput
          ? '$totalQuantity adet hammaddeyi depoya geri gondermek icin uygun araci secin'
          : '$totalQuantity adet uretilen urunu depoya gondermek icin uygun araci secin',
      options: vehicleResult.options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(fieldActionProvider)
            .startMultiProductionToWarehouseTransfer(
              sourceOwnerKind: 'field',
              sourceOwnerId: widget.fieldId,
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
          await _refreshFieldEcosystem(
            warehouseId: targetWarehouse.id,
            includeTransfers: true,
            includePlayer: false,
          );
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: items.first.inventory.isInput
                ? 'Hammaddeyi depoya geri goturen arac yola cikti.'
                : 'Uretilen urunu depoya goturen arac yola cikti.',
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
        child: ListView(
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp),
            ),
            SizedBox(height: 12.h),
            ...options.map(
              (option) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: TransferVehicleOptionCard(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateUsedCapacity(List<ProductionInventoryModel> inventories) {
    var total = 0;
    for (final inventory in inventories) {
      total += inventory.quantity;
    }
    return total;
  }

  int _calculateRemainingInputCapacity(
    List<ProductionInventoryModel> inventories,
    int capacity,
  ) {
    final usedAndPending = inventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.quantity + inventory.pendingQuantity,
    );
    return (capacity - usedAndPending.ceil()).clamp(0, capacity);
  }

  double _inventoryRatio(int current, int capacity) {
    if (capacity <= 0) return 0.0;
    return (current / capacity).clamp(0.0, 1.0);
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

  Color _inputColorForProduct(String productId) {
    const palette = <Color>[
      Color(0xFF4FC3F7),
      Color(0xFF81C784),
      Color(0xFFFF8A65),
      Color(0xFFBA68C8),
      Color(0xFFFFD54F),
      Color(0xFF64B5F6),
    ];
    final hash = productId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[hash % palette.length];
  }

  bool _isSameCity(String warehouseCityId, String productionCityId) {
    return warehouseCityId.isNotEmpty && warehouseCityId == productionCityId;
  }

  String _estimateProductionPerHour(
    ProductionSlotModel slot,
    BuildingBoostModel? activeBoost,
  ) {
    final product = slot.product;
    if (product == null) return '0';
    final perHour = product.uretimAdedi * (activeBoost?.multiplier ?? 1);
    return perHour.toStringAsFixed(perHour >= 10 ? 0 : 1);
  }

  Widget _buildQualityStars(int quality) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < quality;
        return Padding(
          padding: EdgeInsets.only(right: 2.w),
          child: Icon(
            isFilled ? Icons.star : Icons.star_border,
            color: isFilled ? AppColors.gold : AppColors.textMuted,
            size: 14.sp,
          ),
        );
      }),
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

class _SelectedFieldProductionTransferItem {
  final ProductionInventoryModel inventory;
  final int quantity;

  const _SelectedFieldProductionTransferItem({
    required this.inventory,
    required this.quantity,
  });
}

class _FieldInboundWarehouseChoice {
  final String warehouseId;
  final String warehouseName;
  final String cityId;
  final String cityName;
  final bool isSameCity;
  final List<_FieldInboundWarehouseSlotOption> slots;

  const _FieldInboundWarehouseChoice({
    required this.warehouseId,
    required this.warehouseName,
    required this.cityId,
    required this.cityName,
    required this.isSameCity,
    required this.slots,
  });
}

class _FieldInboundWarehouseSlotOption {
  final String warehouseSlotId;
  final String productId;
  final String productName;
  final String? productIcon;
  final int qualityLevel;
  final int availableQuantity;
  final double unitVolume;
  final ProductionInventoryModel targetInventory;

  const _FieldInboundWarehouseSlotOption({
    required this.warehouseSlotId,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.availableQuantity,
    required this.unitVolume,
    required this.targetInventory,
  });
}

class _SelectedFieldInboundTransferItem {
  final _FieldInboundWarehouseSlotOption slot;
  final int quantity;

  const _SelectedFieldInboundTransferItem({
    required this.slot,
    required this.quantity,
  });
}

String _inventoryKey(String productId, int qualityLevel) {
  return '$productId::$qualityLevel';
}

Set<String> _parseAcceptedProductIds(dynamic rawValue) {
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

class _ActiveFieldBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveFieldBoostCard({required this.boost});

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

class _ActiveFieldUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveFieldUpgradeCard({
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
                      'Ciftlik Yukseltmesi Devam Ediyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Seviye ${upgrade.currentLevel} -> ${upgrade.targetLevel} | Hammadde ${upgrade.previousInputCapacity} -> ${upgrade.nextInputCapacity} | Cikti ${upgrade.previousOutputCapacity} -> ${upgrade.nextOutputCapacity}',
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
