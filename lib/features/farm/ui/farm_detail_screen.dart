import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_ad_action_flow.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_quote_provider.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_error_message.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/building_upgrade_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/rewarded_time_reduce_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_detail_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_list_item_model.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart'
    show warehouseCapacityStatusProvider;
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/production_quality_warning_dialog.dart';
import 'package:hard_kapitalizm/core/data/player_active_products_service.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';

class FarmDetailScreen extends ConsumerStatefulWidget {
  final String farmId;

  const FarmDetailScreen({super.key, required this.farmId});

  @override
  ConsumerState<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends ConsumerState<FarmDetailScreen> {
  static const Map<int, int> _farmBoostStarCosts = {6: 3, 12: 6, 24: 12};

  String? get _currentBrandName =>
      ref.read(playerBrandCompanyProvider).value?.brandName;

  Future<void> _refreshFarmDetail() async {
    await Future.wait([
      ref.read(farmDetailProvider(widget.farmId).notifier).refresh(),
      ref.read(activeFarmBoostProvider(widget.farmId).future),
      ref.read(activeFarmUpgradeProvider(widget.farmId).future),
    ]);
  }

  Future<void> _refreshFarmEcosystem({
    String? warehouseId,
    bool includeTransfers = false,
    bool includeWarehouseList = false,
    bool includePlayer = true,
  }) async {
    _refreshFarmDetail();
    ref.invalidate(farmListProvider);
    if (includePlayer) {
    }

    if (includeWarehouseList ||
        (warehouseId != null && warehouseId.isNotEmpty)) {
      ref.invalidate(warehouseListProvider);
    }

    if (warehouseId != null && warehouseId.isNotEmpty) {
      ref.invalidate(warehouseDetailProvider(warehouseId));
    }

    if (includeTransfers) {
      ref.invalidate(buyerTransferMapProvider);
      ref.invalidate(buyerTransferHistoryProvider);
    }

    await ref.read(farmDetailProvider(widget.farmId).future);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerBrandCompanyProvider);
    final detailAsync = ref.watch(farmDetailProvider(widget.farmId));
    final activeBoost = ref.watch(activeFarmBoostProvider(widget.farmId)).value;
    final activeUpgrade = ref
        .watch(activeFarmUpgradeProvider(widget.farmId))
        .value;

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
        onItemSelected: (_) {},
      ),
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(
              title: 'Tarla Yönetimi',
              actions: [
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  offset: const Offset(0, 40),
                  color: AppColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(
                      color: AppColors.borderGold.withValues(alpha: 0.3),
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'sell') {
                      _showSellFarmDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'sell',
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.sellOutlined,
                            color: AppColors.red,
                            size: AppIconSizes.regular,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Tarlayı Sat',
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.05),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: AppFx.softOverlay(0.06),
                      ),
                    ),
                    child: Icon(
                      AppIcons.moreVert,
                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                      size: AppIconSizes.medium,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: detailAsync.when(
                loading: () =>
                    Center(child: AppLoadingIndicator(color: AppColors.gold)),
                error: (error, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Text(
                      error.toString(),
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.red,
                        fontSize: AppTypography.bodyLarge,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (detail) => RefreshIndicator(
                  onRefresh: () async {
                    _refreshFarmDetail();
                    await ref.read(farmDetailProvider(widget.farmId).future);
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(5.w, 8.h, 5.w, 24.h),
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final listAsync = ref.watch(farmListProvider);
                          return listAsync.maybeWhen(
                            data: (list) {
                              if (list.length <= 1) return const SizedBox.shrink();
                              final hasCurrent = list.any(
                                (item) => item.farm.id == widget.farmId,
                              );
                              if (!hasCurrent) return const SizedBox.shrink();

                              return Container(
                                margin: EdgeInsets.only(bottom: 8.h),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppColors.borderGold.withValues(
                                      alpha: 0.25,
                                    ),
                                    width: 1.w,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: widget.farmId,
                                    isExpanded: true,
                                    dropdownColor: AppColors.cardBg,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.gold,
                                    ),
                                    items: list.map((item) {
                                      final f = item.farm;
                                      final displayCity = item.cityName;
                                      return DropdownMenuItem<String>(
                                        value: f.id,
                                        child: Row(
                                          children: [
                                            Icon(
                                              AppIcons.agriculture,
                                              color: AppColors.gold,
                                              size: 18.sp,
                                            ),
                                            SizedBox(width: 8.w),
                                            Expanded(
                                              child: Text(
                                                '${f.name} ($displayCity)',
                                                style: AppTextStyles.body
                                                    .standardCopyWith(
                                                      color:
                                                          AppColors.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize:
                                                          AppTypography
                                                              .bodySmall,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newId) {
                                      if (newId != null &&
                                          newId != widget.farmId) {
                                        context.pushReplacement(
                                          '/farms/$newId',
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          );
                        },
                      ),
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
                        _ActiveFarmBoostCard(boost: activeBoost),
                      ],
                      if (activeUpgrade != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveFarmUpgradeCard(
                          upgrade: activeUpgrade,
                          onFinishWithGold: () =>
                              _finishFarmUpgradeWithGold(activeUpgrade),
                          onReduceTimeWithAd: () =>
                              _reduceFarmUpgradeTimeWithAd(activeUpgrade),
                          calculateStarCost: _calculateUpgradeStarCost,
                          formatCountdown: _formatCountdown,
                        ),
                      ],
                      SizedBox(height: 12.h),
                      _buildSharedOutputCapacityCard(detail),
                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Tarlalar',
                        'Her tarlada ekili ürünü, kaliteyi ve üretim akışlarını buradan yönetebilirsin.',
                        icon: AppIcons.tuneRounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      if (detail.slots.isEmpty)
                        _buildEmptyCard(
                          'Bu tarlada henüz aktif üretim slotu yok.',
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
                          'Ürün değişikliği sonrasında elde kalan hammaddeleri burada depoya geri aktarabilirsin.',
                          icon: AppIcons.inventory2Outlined,
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

  Widget _buildHero(FarmDetailModel detail) {
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
                    width: 90.w,
                    height: 90.w,
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: AppFx.panelWash(0.3),
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
                      fileName: detail.farmType.icon,
                      fit: BoxFit.contain,
                      errorWidget: Icon(
                        AppIcons.agriculture,
                        color: AppColors.green,
                        size: AppIconSizes.display,
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
                                detail.farm.name,
                                style: AppTextStyles.h2.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTypography.headline,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                detail.farmType.name,
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: AppTypography.label,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.locationOn,
                                    color: AppColors.gold,
                                    size: AppIconSizes.small,
                                  ),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      detail.cityName,
                                      style: AppTextStyles.caption
                                          .standardCopyWith(
                                            color: AppColors.textMuted,
                                            fontSize: AppTypography.bodySmall,
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
                  '${_calculateUsedCapacity(detail.inputInventories)}/${detail.farm.inputCapacity}',
                  AppColors.blue,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.inputInventories),
                    detail.farm.inputCapacity,
                  ),
                  icon: AppIcons.scienceOutlined,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildHeroStat(
                  'Üretilen ürün',
                  '${_calculateUsedCapacity(detail.outputInventories)}/${detail.farm.outputCapacity}',
                  AppColors.green,
                  ratio: _inventoryRatio(
                    _calculateUsedCapacity(detail.outputInventories),
                    detail.farm.outputCapacity,
                  ),
                  icon: AppIcons.agricultureOutlined,
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
        color: AppFx.panelWash(0.16),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: AppIconSizes.small),
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
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.caption,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodySmall,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          AppProgressBar.stock(
            value: ratio,
            size: AppProgressSize.compact,
            minHeight: 3.h,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.14),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Ürün Al',
                  AppIcons.downloadRounded,
                  AppColors.gold,
                  () => _startFarmReceiveFlow(context, ref, detail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Ürün Gönder',
                  AppIcons.localShippingRounded,
                  AppColors.blue,
                  () => _startFarmSendFlow(context, ref, detail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Slot Ac',
                  AppIcons.addBoxOutlined,
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
                  AppIcons.flashOnRounded,
                  AppColors.goldDark,
                  () => _showFarmBoostSheet(context, ref, detail, activeBoost),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Yukselt',
                  AppIcons.upgradeRounded,
                  AppColors.green,
                  () => _showFarmUpgradeSheet(
                    context,
                    ref,
                    detail,
                    activeUpgrade,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Rapor',
                  AppIcons.queryStatsRounded,
                  AppColors.blue,
                  () => context.push(
                    '/production-report/farm/${detail.farm.id}?name=${Uri.encodeComponent(detail.farm.name)}',
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
      borderRadius: BorderRadius.circular(11.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11.r),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: AppIconSizes.compact),
            SizedBox(height: 4.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.standardCopyWith(
                color: color,
                fontSize: AppTypography.caption,
                fontWeight: FontWeight.w700,
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: color, size: AppIconSizes.regular),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h2.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.titleLarge,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.03),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodyLarge,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
    BuildingBoostModel? activeBoost,
  ) {
    final slotActiveColor = slot.isActive ? AppColors.green : AppColors.red;
    final isBranded =
        slot.brandId != SelectableProductionProductModel.defaultBrandId;
    final slotTitle = slot.isEmpty
        ? 'Boş Tarla ${slot.slotIndex}'
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showSlotProductDialog(
                    context,
                    ref,
                    detail,
                    slot,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    width: 70.w,
                    height: 70.w,
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: AppFx.panelWash(0.3),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: !slot.isEmpty
                            ? AppColors.green.withValues(alpha: 0.3)
                            : AppFx.softOverlay(0.10),
                      ),
                    ),
                    child: slot.isEmpty || slot.product?.urunIconu == null
                        ? Icon(
                            AppIcons.addCircleOutline,
                            color: AppColors.textMuted,
                            size: AppIconSizes.large,
                          )
                        : BrandedProductImage(
                            fileName: slot.product!.urunIconu,
                            fit: BoxFit.contain,
                            brandId: slot.brandId,
                            brandName:
                                slot.brandId !=
                                    SelectableProductionProductModel.defaultBrandId
                                ? _currentBrandName
                                : null,
                            productId: slot.productId,
                            showFrame: false,
                          ),
                  ),
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
                          child: GestureDetector(
                            onTap: slot.isEmpty
                                ? () => _showSlotProductDialog(
                                      context,
                                      ref,
                                      detail,
                                      slot,
                                    )
                                : null,
                            child: Text(
                              slotTitle,
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontSize: AppTypography.title,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                              color: AppFx.softOverlay(0.05),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: AppFx.softOverlay(0.06),
                              ),
                            ),
                            child: Icon(
                              AppIcons.moreVert,
                              color: AppColors.textMuted,
                              size: AppIconSizes.compact,
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
                                    AppIcons.category,
                                    color: AppColors.gold,
                                    size: AppIconSizes.regular,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    slot.isEmpty ? 'Ürün Seç' : 'Ürün Değiştir',
                                    style: AppTextStyles.body.standardCopyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: AppTypography.bodyLarge,
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
                                        ? AppIcons.stopCircle
                                        : AppIcons.playCircle,
                                    color: slot.isActive
                                        ? AppColors.red
                                        : AppColors.green,
                                    size: AppIconSizes.regular,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    slot.isActive
                                        ? 'Üretimi Durdur'
                                        : 'Üretime Başla',
                                    style: AppTextStyles.body.standardCopyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: AppTypography.bodyLarge,
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
                      GestureDetector(
                        onTap: () => _showSlotProductDialog(
                          context,
                          ref,
                          detail,
                          slot,
                        ),
                        child: Text(
                          'Beklemede. Ürün seçmek için dokunun.',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.goldLight,
                            fontSize: AppTypography.label,
                          ),
                        ),
                      )
                    else
                      _buildSlotStatsRow(
                        slot,
                        outputInventory,
                        activeBoost,
                        detail.farm.cityId,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!slot.isEmpty && slot.product != null)
            _buildProductionFormulaRow(ref, slot.product!, detail.inventories),
          if (!slot.isEmpty) ...[
            SizedBox(height: 10.h),
            _buildSlotFlowGroup(context, ref, detail, slot),
          ],
        ],
      ),
    );
  }

  Widget _buildSlotStatsRow(
    FarmProductionSlotModel slot,
    FarmProductionInventoryModel? outputInventory,
    BuildingBoostModel? activeBoost,
    String cityId,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.02),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppFx.softOverlay(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kalite',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                ),
              ),
              SizedBox(height: 2.h),
              _buildQualityStars(slot.qualityLevel),
            ],
          ),
          Container(width: 1.w, height: 18.h, color: AppFx.softOverlay(0.10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Birim Maliyet',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.paymentsOutlined,
                    color: AppColors.gold,
                    size: AppIconSizes.xSmall,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    '${((outputInventory?.cost != null && outputInventory!.cost > 0) ? outputInventory.cost : (slot.product?.iscilikMaliyeti ?? 0.0)).toStringAsFixed(2)} TL',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(width: 1.w, height: 18.h, color: AppFx.softOverlay(0.10)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uretim / Saat',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.micro,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.schedule,
                    color: AppColors.green,
                    size: AppIconSizes.xSmall,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    _estimateProductionPerHour(
                      slot,
                      activeBoost,
                      cityId,
                    ).toString(),
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (slot.product != null &&
                      _getCityProductBonus(cityId, slot.product!.kategori) >
                          1.0) ...[
                    SizedBox(width: 4.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: Colors.green, width: 0.5),
                      ),
                      child: Text(
                        'x${_getCityProductBonus(cityId, slot.product!.kategori).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
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
    if (remaining.inSeconds <= 0) return 'Tamamlanıyor';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    }
    return '${remaining.inMinutes}dk';
  }

  Widget _buildProductionFormulaRow(
    WidgetRef ref,
    ProductModel product,
    List<dynamic> inputInventories,
  ) {
    final List<Widget> items = [];
    final catalogProducts =
        ref.watch(staticCatalogsProvider).value?.products ?? const [];

    // 1. Labor Cost
    if (product.iscilikMaliyeti > 0) {
      items.add(
        _buildFormulaItem(
          icon: AppIcons.engineeringOutlined,
          color: AppColors.blue,
          label: 'İşçilik:',
          value: ' ${product.iscilikMaliyeti.toStringAsFixed(2)} TL',
        ),
      );
    }

    // 2. Raw Materials
    final rawMaterials = [
      (id: product.hammadde1Id, qty: product.hammadde1Miktar),
      (id: product.hammadde2Id, qty: product.hammadde2Miktar),
      (id: product.hammadde3Id, qty: product.hammadde3Miktar),
    ];

    for (final rm in rawMaterials) {
      if (rm.id != null && rm.id!.isNotEmpty && rm.qty != null && rm.qty! > 0) {
        String name = rm.id!;
        for (final inv in inputInventories) {
          if (inv.productId == rm.id && inv.product != null) {
            name = inv.product!.urunAdi;
            break;
          }
        }
        if (name == rm.id) {
          final catalogMatch = catalogProducts.cast<ProductModel?>().firstWhere(
            (p) => p?.id == rm.id,
            orElse: () => null,
          );
          if (catalogMatch != null && catalogMatch.urunAdi.isNotEmpty) {
            name = catalogMatch.urunAdi;
          }
        }
        items.add(
          _buildFormulaItem(
            icon: AppIcons.layersOutlined,
            color: AppColors.gold,
            label: '$name:',
            value: ' ${rm.qty!.toStringAsFixed(1)} ad',
          ),
        );
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.015),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppFx.softOverlay(0.035)),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.receiptLongOutlined,
            color: AppColors.textMuted,
            size: AppIconSizes.xSmall,
          ),
          SizedBox(width: 6.w),
          Text(
            'Tarif:',
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    items[i],
                    if (i < items.length - 1)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text(
                          '+',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppFx.softOverlay(0.24),
                            fontSize: AppTypography.label,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaItem({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: AppIconSizes.xSmall),
        SizedBox(width: 4.w),
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.label,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.label,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _showFarmBoostSheet(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
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
              'Tarla Boostu',
              style: AppTextStyles.h2.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.headline,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              activeBoost != null
                  ? 'Bu tarlada zaten aktif bir boost var. Süre dolana kadar tüm slotlar x${activeBoost.multiplier.toStringAsFixed(1)} hızla çalışır.'
                  : 'Boost başladığında tüm tarla slotlarının boost katsayısı 2 olur. Üretim hızı süre boyunca artar.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.body,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            if (activeBoost == null) ...[
              Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await RewardedAdActionFlow.run(
                      context,
                      rewardKind: 'building_boost_start',
                      resourceId: 'farm:${detail.farm.id}',
                      loadingMessage: '30 dakikalık boost reklamı yükleniyor.',
                      successTitle: 'Boost Baslatildi',
                      successMessage:
                          'Tarla boostu 30 dakika için başlatıldı.',
                      feedbackAmount: 30,
                      feedbackType: FloatingFeedbackType.boostAdd,
                      onApplyAction: () async {
                        final result = await ref
                            .read(farmActionProvider)
                            .startFarmBoostWithAdReward(
                              farmId: detail.farm.id,
                              syncProviders: false,
                            );
                        if (result['success'] == true) {
                          ref
                              .read(activeFarmBoostProvider(widget.farmId).notifier)
                              .setBoost(BuildingBoostModel.fromJson(result));
                        }
                        return result;
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            AppIcons.playCircleFill,
                            color: AppColors.green,
                            size: AppIconSizes.regular,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reklam izle, 30 dk boost al',
                                style: AppTextStyles.title.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTypography.body,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Tum slotlari 30 dakika boyunca yildiz harcamadan hizlandir.',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: AppTypography.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (activeBoost == null)
              ..._farmBoostStarCosts.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await ref
                          .read(farmActionProvider)
                          .startFarmBoost(
                            farmId: detail.farm.id,
                            durationHours: entry.key,
                            starCost: entry.value,
                            syncProviders: false,
                          );

                      if (!context.mounted) return;

                      if (result['success'] == true) {
                        ref
                            .read(activeFarmBoostProvider(widget.farmId).notifier)
                            .setBoost(BuildingBoostModel.fromJson(result));
                        if (!context.mounted) return;
                        AppSnackbar.show(
                          context,
                          title: 'Başarılı',
                          message: 'Tarla boostu başlatıldı.',
                          type: SnackbarType.success,
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message:
                              result['message'] ??
                              'Tarla boostu başlatılamadı.',
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
                              AppIcons.flashOnRounded,
                              color: AppColors.goldDark,
                              size: AppIconSizes.regular,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key} Saat',
                                  style: AppTextStyles.body.standardCopyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: AppTypography.title,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tum slotlar x2 uretim hizi kazanir',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${entry.value} ★',
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: AppTypography.title,
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
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.body,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFarmUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    if (activeUpgrade != null) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu tarla için zaten devam eden bir yükseltme var.',
        type: SnackbarType.info,
      );
      return;
    }

    final quote = await ref.read(
      buildingUpgradeQuoteProvider((
        buildingKind: 'farm',
        entityId: detail.farm.id,
      )).future,
    );
    if (!context.mounted) return;
    if (quote.isMaximumLevel) {
      AppSnackbar.show(
        context,
        title: 'Maksimum Seviye',
        message: 'Bu tarla maksimum seviye ${quote.maxLevel}.',
        type: SnackbarType.info,
      );
      return;
    }
    final targetLevel = quote.targetLevel!;
    final upgradeCost = quote.cashCost;
    final durationMinutes = quote.durationMinutes;
    final nextInputCapacity =
        quote.effect('input_capacity')?.nextValue.toInt() ??
        detail.farm.inputCapacity;
    final nextOutputCapacity =
        quote.effect('output_capacity')?.nextValue.toInt() ??
        detail.farm.outputCapacity;

    await showBuildingUpgradeSheet(
      context: context,
      title: 'Tarla Yükseltmesi',
      buildingName: detail.farm.name,
      icon: AppIcons.grass,
      currentLevel: detail.farm.level,
      targetLevel: targetLevel,
      durationLabel: '$durationMinutes dk',
      costLabel: AppMoney.compact(upgradeCost),
      requirementLabel: quote.requirementLabel,
      benefits: [
        BuildingUpgradeBenefit(
          icon: AppIcons.inventory2Outlined,
          label: 'Hammadde kapasitesi',
          before: '${detail.farm.inputCapacity}',
          after: '$nextInputCapacity',
        ),
        BuildingUpgradeBenefit(
          icon: AppIcons.inventory2Rounded,
          label: 'Ürün kapasitesi',
          before: '${detail.farm.outputCapacity}',
          after: '$nextOutputCapacity',
        ),
      ],
      canConfirm: quote.canUpgrade,
      onConfirm: () async {
        final result = await ref
            .read(farmActionProvider)
            .startFarmUpgrade(detail.farm.id, syncProviders: false);
        if (!context.mounted) return;
        if (result['success'] == true) {
          ref
              .read(activeFarmUpgradeProvider(widget.farmId).notifier)
              .setUpgrade(BuildingUpgradeModel.fromJson(result));
          if (!context.mounted) return;
          FloatingFeedback.show(
            context,
            amount: upgradeCost,
            type: FloatingFeedbackType.cashRemove,
          );
          AppSnackbar.show(
            context,
            title: 'Başarılı',
            message: 'Tarla yükseltmesi başlatıldı.',
            type: SnackbarType.success,
          );
          return;
        }
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: result['message'] ?? 'Yükseltme başlatılamadı.',
          type: SnackbarType.error,
        );
      },
    );
  }

  Future<void> _finishFarmUpgradeWithGold(BuildingUpgradeModel upgrade) async {
    final result = await ref
        .read(farmActionProvider)
        .finishFarmUpgradeWithGold(upgrade.id, syncProviders: false);

    if (!mounted) return;
    if (result['success'] == true) {
      final targetLevel = (result['target_level'] as num?)?.toInt() ?? upgrade.targetLevel;
      final outputIncrease = (result['output_capacity_increase'] as num?)?.toInt() ?? 0;
      final inputIncrease = (result['input_capacity_increase'] as num?)?.toInt() ?? 0;
      final currentDetail = ref.read(farmDetailProvider(widget.farmId)).value;
      final newOutput = (currentDetail?.farm.outputCapacity ?? 0) + outputIncrease;
      final newInput = (currentDetail?.farm.inputCapacity ?? 0) + inputIncrease;

      ref.read(activeFarmUpgradeProvider(widget.farmId).notifier).clear();
      ref
          .read(farmDetailProvider(widget.farmId).notifier)
          .patchFarmLevelAndCapacity(
            level: targetLevel,
            outputCapacity: newOutput,
            inputCapacity: newInput,
          );
      ref
          .read(farmListProvider.notifier)
          .patchFarmLevelAndCapacity(
            farmId: widget.farmId,
            level: targetLevel,
            outputCapacity: newOutput,
            inputCapacity: newInput,
          );

      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'Tarla yükseltmesi tamamlandı.',
        type: SnackbarType.success,
      );
      await showExperienceFeedbackFromResult(context, result);
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yükseltme tamamlanamadı.',
      type: SnackbarType.error,
    );
  }

  Future<void> _reduceFarmUpgradeTimeWithAd(
    BuildingUpgradeModel upgrade,
  ) async {
    final success = await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'upgrade_time_reduce',
      resourceId: upgrade.id,
      onApplyReduction: () => ref
          .read(farmActionProvider)
          .reduceFarmUpgradeTimeWithAd(upgrade.id, syncProviders: false),
      successMessage: 'Tarla yükseltme süresi 10 dakika kısaltıldı.',
    );

    if (success) {
      ref
          .read(activeFarmUpgradeProvider(widget.farmId).notifier)
          .reduceTime(const Duration(minutes: 10));
    }
  }

  Widget _buildSlotFlowGroup(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
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
              : Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppFx.softOverlay(0.03),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: AppColors.blue.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSharedInputCapacityBar(detail, inputInventories),
                      if (inputInventories.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          child: Divider(
                            color: AppFx.softOverlay(0.06),
                            height: 1.h,
                          ),
                        ),
                        ...inputInventories.map(
                          (inventory) => _buildCompactInventoryRow(inventory),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCompactInventoryRow(FarmProductionInventoryModel inventory) {
    final isBranded =
        !inventory.isInput &&
        inventory.brandId != SelectableProductionProductModel.defaultBrandId;
    final title =
        (inventory.product?.urunAdi.isNotEmpty == true
            ? inventory.product!.urunAdi
            : inventory.productId) +
        (isBranded ? ' (${_currentBrandName ?? 'Markali'})' : '');
    final color = AppColors.blue;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            padding: EdgeInsets.all(1.w),
            decoration: BoxDecoration(
              color: AppFx.panelWash(0.2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: inventory.product?.urunIconu != null
                ? BrandedProductImage(
                    fileName: inventory.product!.urunIconu,
                    fit: BoxFit.contain,
                    brandId: inventory.brandId,
                    brandName: isBranded ? _currentBrandName : null,
                    productId: inventory.productId,
                    showFrame: false,
                  )
                : Icon(
                    AppIcons.inventory2,
                    color: color,
                    size: AppIconSizes.small,
                  ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3.h),
                _buildQualityStars(inventory.qualityLevel),
                SizedBox(height: 2.h),
                Text(
                  'Maliyet: ${inventory.cost.toStringAsFixed(2)} TL${inventory.pendingQuantity > 0 ? " | Yolda: ${inventory.pendingQuantity.toStringAsFixed(0)}" : ""}',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.caption,
                  ),
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
              '${inventory.quantity} ad',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.label,
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

  Widget _buildHeroChipColumn(FarmDetailModel detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [_buildTag('Lv ${detail.farm.level}', AppColors.gold)],
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
            color == AppColors.blue
                ? AppIcons.scienceOutlined
                : AppIcons.agricultureOutlined,
            color: color,
            size: AppIconSizes.small,
          ),
        ),
        SizedBox(width: 7.w),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedOutputCapacityCard(FarmDetailModel detail) {
    final capacity = detail.farm.outputCapacity;
    final totalStock = detail.outputInventories.fold<int>(
      0,
      (sum, inventory) => sum + inventory.quantity,
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  AppIcons.inventory2Outlined,
                  color: AppColors.green,
                  size: AppIconSizes.small,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Üretilen Ürün Stoğu',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$totalStock / $capacity ad',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.green,
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _buildSegmentedCapacityBar(
            inventories: detail.outputInventories,
            capacity: capacity,
            isInput: false,
          ),
          if (totalStock > 0) ...[
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                ...detail.outputInventories
                    .where((inv) => inv.quantity > 0)
                    .map((inventory) {
                      final isBranded =
                          inventory.brandId !=
                          SelectableProductionProductModel.defaultBrandId;
                      final name =
                          (inventory.product?.urunAdi.isNotEmpty == true
                              ? inventory.product!.urunAdi
                              : inventory.productId) +
                          (isBranded
                              ? ' (${_currentBrandName ?? 'Markalı'})'
                              : '');
                      return _buildCapacityLegendChip(
                        '$name (${inventory.quantity} ad)',
                        _outputColorForProduct(inventory.productId),
                      );
                    }),
              ],
            ),
          ] else ...[
            SizedBox(height: 8.h),
            Text(
              'Henüz üretilmiş ürün bulunmuyor. Üretime başlayarak ürün elde edebilirsin.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.label,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _outputColorForProduct(String productId) {
    final palette = <Color>[
      AppColors.blue,
      AppColors.green,
      AppColors.gold,
      AppColors.warning,
      AppColors.red,
      AppColors.goldDark,
      AppColors.borderGold,
    ];
    final hash = productId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[hash % palette.length];
  }

  Widget _buildInlineEmptyState(String message) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
      child: Text(
        message,
        style: AppTextStyles.body.standardCopyWith(
          color: AppColors.textMuted,
          fontSize: AppTypography.bodySmall,
        ),
      ),
    );
  }

  Widget _buildSharedInputCapacityBar(
    FarmDetailModel detail,
    List<FarmProductionInventoryModel> inventories,
  ) {
    final capacity = detail.farm.inputCapacity;
    final totalStock = inventories.fold<int>(
      0,
      (sum, inventory) => sum + inventory.quantity,
    );
    final totalPending = inventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.pendingQuantity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$totalStock adet | ${totalPending.toStringAsFixed(0)} yolda / $capacity',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySmall,
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
    );
  }

  Widget _buildSegmentedCapacityBar({
    required List<FarmProductionInventoryModel> inventories,
    required int capacity,
    bool isInput = true,
  }) {
    if (capacity <= 0) {
      return Container(
        height: 6.h,
        decoration: BoxDecoration(
          color: AppFx.panelWash(0.35),
          borderRadius: BorderRadius.circular(999.r),
        ),
      );
    }

    final segments = <({double amount, Color color})>[];
    for (final inventory in inventories) {
      if (inventory.quantity > 0) {
        segments.add((
          amount: inventory.quantity.toDouble(),
          color: isInput
              ? _inputColorForProduct(inventory.productId)
              : _outputColorForProduct(inventory.productId),
        ));
      }
    }

    final totalPending = isInput
        ? inventories.fold<double>(
            0,
            (sum, inventory) => sum + inventory.pendingQuantity,
          )
        : 0.0;
    if (totalPending > 0) {
      segments.add((amount: totalPending, color: AppColors.goldDark));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var left = 0.0;

        return Container(
          height: 6.h,
          decoration: BoxDecoration(
            color: AppFx.panelWash(0.35),
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
                      child: Container(width: width, color: segment.color),
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
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<FarmProductionInventoryModel> _inputInventoriesForSlot(
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
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

  FarmProductionInventoryModel? _outputInventoryForSlot(
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
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
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
  ) {
    final isBranded =
        !inventory.isInput &&
        inventory.brandId != SelectableProductionProductModel.defaultBrandId;
    final title =
        (inventory.product?.urunAdi.isNotEmpty == true
            ? inventory.product!.urunAdi
            : inventory.productId) +
        (isBranded ? ' (${_currentBrandName ?? 'Markali'})' : '');
    final color = inventory.isInput ? AppColors.blue : AppColors.green;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.16),
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
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.35),
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
                        brandId: inventory.brandId,
                        brandName:
                            !inventory.isInput &&
                                inventory.brandId !=
                                    SelectableProductionProductModel
                                        .defaultBrandId
                            ? _currentBrandName
                            : null,
                        productId: inventory.productId,
                        showFrame: false,
                      )
                    : Icon(
                        AppIcons.inventory2,
                        color: color,
                        size: AppIconSizes.medium,
                      ),
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
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodyLarge,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    if (inventory.isInput)
                      Row(
                        children: [
                          Text(
                            'Kalite',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.label,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          _buildQualityStars(inventory.qualityLevel),
                        ],
                      )
                    else
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
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Divider(color: AppFx.softOverlay(0.04), height: 1),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.paymentsOutlined,
                    color: AppColors.textMuted,
                    size: AppIconSizes.xSmall,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Maliyet: ${inventory.cost.toStringAsFixed(2)} TL',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.label,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    AppIcons.localShippingOutlined,
                    color: inventory.pendingQuantity > 0
                        ? AppColors.gold
                        : AppColors.textMuted,
                    size: AppIconSizes.xSmall,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    inventory.pendingQuantity > 0
                        ? 'Yolda: ${inventory.pendingQuantity.toStringAsFixed(0)}'
                        : 'Yolda yok',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: inventory.pendingQuantity > 0
                          ? AppColors.goldLight
                          : AppColors.textMuted,
                      fontSize: AppTypography.label,
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

  Future<void> _handleAddSlot(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
  ) async {
    final result = await ref
        .read(farmActionProvider)
        .addProductionSlot(detail.farm.id, syncProviders: false);

    if (!context.mounted) return;
    if (result['success'] == true) {
      final slotJson = result['slot'] as Map<String, dynamic>?;
      if (slotJson != null) {
        final newSlot = FarmProductionSlotModel.fromJson(slotJson);
        ref
            .read(farmDetailProvider(widget.farmId).notifier)
            .addSlot(newSlot);
        ref
            .read(farmListProvider.notifier)
            .addSlot(
              farmId: widget.farmId,
              slot: FarmSlotPreviewModel(
                id: newSlot.id,
                slotIndex: newSlot.slotIndex,
                isActive: newSlot.isActive,
                productId: null,
                product: null,
              ),
            );
      }
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Başarılı',
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
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) async {
    final nextActive = !slot.isActive;
    final result = await ref
        .read(farmActionProvider)
        .setProductionSlotActive(
          slotId: slot.id,
          isActive: nextActive,
          syncProviders: false,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      ref
          .read(farmDetailProvider(widget.farmId).notifier)
          .patchSlotActive(slotId: slot.id, isActive: nextActive);
      ref
          .read(farmListProvider.notifier)
          .patchSlotActive(farmId: widget.farmId, slotId: slot.id, isActive: nextActive);
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
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
  ) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref
          .read(farmActionProvider)
          .getSelectableProducts(ownerKind: 'farm', typeId: detail.farmType.id);
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

    final activeProducts = ref.read(playerActiveProductsProvider).value ?? [];
    final sellingProductIds = activeProducts
        .where((p) => p.role == 'sale')
        .map((p) => p.productId)
        .toSet();

    final options = products.map((selectableProduct) {
      final product = selectableProduct.product;
      final isSelling = sellingProductIds.contains(product.id);
      final isDisabled = disabledProductIds.contains(product.id);
      return ProductSelectionOption(
        id: product.id,
        title:
            product.urunAdi +
            (selectableProduct.hasPreferredBrand
                ? ' (${_currentBrandName ?? 'Markali'})'
                : ''),
        subtitle:
            'Saatlik üretim: ${(product.uretimAdedi * (1.0 + (slot.qualityLevel - 1) * 0.20) * _getCityProductBonus(detail.farm.cityId, product.kategori)).toInt()}'
            '${_getCityProductBonus(detail.farm.cityId, product.kategori) > 1.0 ? " (x${_getCityProductBonus(detail.farm.cityId, product.kategori).toStringAsFixed(2)} Bölge)" : ""}',
        badgeText:
            'Maks Kalite: ${selectableProduct.maxQualityLevel}'
            '${selectableProduct.hasPreferredBrand ? ' • Marka Hazir' : ''}',
        iconPath: product.urunIconu,
        trailingWidget: isSelling
            ? Container(
                margin: EdgeInsets.only(top: 4.h),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    width: 1.w,
                  ),
                ),
                child: Text(
                  'Satışta',
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.goldLight,
                    fontSize: AppTypography.caption,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        isDisabled: isDisabled,
        disabledReason: isDisabled
            ? 'Bu ürün başka bir slotta kullanılıyor'
            : null,
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
    FarmDetailModel detail,
    FarmProductionSlotModel slot,
    SelectableProductionProductModel selectableProduct,
  ) async {
    final product = selectableProduct.product;
    final qualityLevel = selectableProduct.suggestedOutputQualityLevel;
    final hasRawMaterials = (product.hammadde1Id != null &&
            product.hammadde1Id!.isNotEmpty) ||
        (product.hammadde2Id != null && product.hammadde2Id!.isNotEmpty) ||
        (product.hammadde3Id != null && product.hammadde3Id!.isNotEmpty);

    if (qualityLevel > 2 && hasRawMaterials) {
      final confirmed = await ProductionQualityWarningDialog.show(
        context: context,
        product: product,
        qualityLevel: qualityLevel,
        requiredInputQuality: qualityLevel - 1,
      );
      if (!confirmed || !context.mounted) return;
    }

    final action = ref.read(farmActionProvider);
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
      final slotsRaw = result['slots'] as List<dynamic>?;
      final inventoriesRaw = result['inventories'] as List<dynamic>?;
      if (slotsRaw != null && inventoriesRaw != null) {
        final newSlots = slotsRaw
            .map((s) => FarmProductionSlotModel.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
        final newInventories = inventoriesRaw
            .map((i) => FarmProductionInventoryModel.fromJson(Map<String, dynamic>.from(i as Map)))
            .toList();
        ref
            .read(farmDetailProvider(widget.farmId).notifier)
            .patchSlotsAndInventories(slots: newSlots, inventories: newInventories);
      }
      ref
          .read(farmListProvider.notifier)
          .patchSlotProduct(
            farmId: widget.farmId,
            slotId: slot.id,
            productId: product.id,
            product: product,
          );
      if (!context.mounted) return;
      final deletedObsoleteCount =
          (result['deleted_obsolete_inventory_count'] as num?)?.toInt() ?? 0;
      final cleanupNote = deletedObsoleteCount > 0
          ? ' Eski boş kayıtlardan $deletedObsoleteCount adet temizlendi.'
          : '';
      final isBranded = selectableProduct.hasPreferredBrand;
      final productName =
          product.urunAdi +
          (isBranded ? ' (${_currentBrandName ?? 'Markali'})' : '');
      AppSnackbar.show(
        context,
        title: 'Başarılı',
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
      message: sanitizeUserFacingError(result['message'] ?? 'Ürün seçilemedi.'),
      type: SnackbarType.error,
    );
  }

  Future<void> _startFarmReceiveFlow(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
  ) async {
    final targetInventories = detail.inputInventories
        .where((inventory) => inventory.product != null)
        .toList();
    if (targetInventories.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu tarlada aktif hammadde girdisi bulunamadı.',
        type: SnackbarType.info,
      );
      return;
    }

    final remainingInputCapacity = _calculateRemainingInputCapacity(
      detail.inputInventories,
      detail.farm.inputCapacity,
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
          .read(farmActionProvider)
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

    final targetByKey = <String, FarmProductionInventoryModel>{
      for (final inventory in targetInventories)
        _inventoryKey(inventory.productId, inventory.qualityLevel): inventory,
    };
    final warehouseChoices = <_FarmInboundWarehouseChoice>[];

    for (final warehouse in warehouses) {
      if (warehouse['city_id']?.toString() != detail.farm.cityId) continue;
      final slots = (warehouse['warehouse_slots'] as List<dynamic>? ?? const [])
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();
      final eligibleSlots = <_FarmInboundWarehouseSlotOption>[];
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
          _FarmInboundWarehouseSlotOption(
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
            unitVolume: targetInventory.unitVolume,
            targetInventory: targetInventory,
          ),
        );
      }

      if (eligibleSlots.isEmpty) continue;
      final warehouseId = warehouse['id']?.toString() ?? '';
      final cityId = warehouse['city_id']?.toString() ?? '';
      final name = (warehouse['name'] ?? 'Depo').toString();
      final cityName = (warehouse['city']?['name'] ?? detail.cityName)
          .toString();
      final totalCapacity = (warehouse['capacity'] as num?)?.toDouble() ?? 0.0;
      final reservedCapacity = (warehouse['reserved_capacity'] as num?)?.toDouble() ?? 0.0;

      final slotsRaw = warehouse['warehouse_slots'] as List<dynamic>? ?? [];
      final previews = slotsRaw.map((s) {
        final qty = (s['quantity'] as num?)?.toDouble() ?? 0.0;
        final qual = (s['quality_level'] as num?)?.toInt() ?? 0;
        final icon = (s['product'] as Map?)?['urun_iconu']?.toString() ?? '';
        return WarehouseSelectionProductPreview(
          icon: icon,
          quantity: qty,
          quality: qual,
        );
      }).where((p) => p.quantity > 0 && p.icon.isNotEmpty).toList();

      warehouseChoices.add(
        _FarmInboundWarehouseChoice(
          warehouseId: warehouseId,
          warehouseName: name,
          cityId: cityId,
          cityName: cityName,
          isSameCity: _isSameCity(cityId, detail.farm.cityId),
          slots: eligibleSlots,
          capacity: totalCapacity,
          reservedCapacity: reservedCapacity,
          productPreviews: previews,
        ),
      );
    }

    if (!context.mounted) return;
    if (warehouseChoices.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message:
            'Bu şehirdeki Genel Depoda tarlanın kullandığı uygun tohum/girdi bulunamadı.',
        type: SnackbarType.info,
      );
      return;
    }

    _showFarmInboundSelectionSheet(
      context: context,
      ref: ref,
      detail: detail,
      warehouse: warehouseChoices.first,
      remainingInputCapacity: remainingInputCapacity,
    );
  }

  Future<void> _startFarmSendFlow(
    BuildContext context,
    WidgetRef ref,
    FarmDetailModel detail,
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
      warehouses = await ref.read(farmActionProvider).getPlayerWarehousesRaw();
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

    final localWarehouse = warehouses.firstWhere(
      (w) => w['city_id']?.toString() == detail.farm.cityId && w['is_active'] == true,
      orElse: () => <String, dynamic>{},
    );

    if (localWarehouse.isEmpty) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu şehirde aktif bir Genel Depo bulunamadı.',
        type: SnackbarType.info,
      );
      return;
    }

    final warehouseOption = ProductionLogisticsWarehouseOption.fromJson(
      localWarehouse,
      productionCityId: detail.farm.cityId,
    );

    WarehouseCapacityStatusModel? capacityStatus;
    try {
      capacityStatus = await ref.read(
        warehouseCapacityStatusProvider(warehouseOption.id).future,
      );
    } catch (_) {
      capacityStatus = null;
    }

    if (!context.mounted) return;
    _showFarmOutboundSelectionSheet(
      context: context,
      ref: ref,
      detail: detail,
      targetWarehouse: warehouseOption,
      targetCapacityStatus: capacityStatus,
      inventories: sendableInventories,
    );
  }

  Future<void> _showFarmInboundSelectionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required FarmDetailModel detail,
    required _FarmInboundWarehouseChoice warehouse,
    required int remainingInputCapacity,
  }) async {
    final selectedQuantities = <String, int>{};

    int maxSelectableForSlot(_FarmInboundWarehouseSlotOption slot) {
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
      _FarmInboundWarehouseSlotOption slot,
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
        builder: (dialogContext) => Dialog(
          backgroundColor: AppColors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: AppDecorations.premiumCard(AppColors.gold, 20.r),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    slot.productName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.titleLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 5; i++)
                        Icon(
                          i < slot.qualityLevel
                              ? AppIcons.starRounded
                              : AppIcons.starBorderRounded,
                          color: i < slot.qualityLevel
                              ? AppColors.gold
                              : AppFx.softOverlay(0.24),
                          size: AppIconSizes.compact,
                        ),
                      SizedBox(width: 6.w),
                      Text(
                        'Q${slot.qualityLevel}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Container(
                      width: 72.w,
                      height: 72.w,
                      margin: EdgeInsets.symmetric(vertical: 12.h),
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AppFx.panelWash(0.35),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: BrandedProductImage(
                        fileName: slot.productIcon ?? 'default.webp',
                        productId: slot.productId,
                        fit: BoxFit.contain,
                        showFrame: false,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 6.h,
                      horizontal: 12.w,
                    ),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.03),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppFx.softOverlay(0.10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mevcut Stok:',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                        Text(
                          '${slot.availableQuantity} Adet',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: controller,
                    readOnly: true,
                    showCursor: true,
                    enableInteractiveSelection: false,
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Miktar (Maks: $maxQuantity)',
                      labelStyle: AppTextStyles.body.standardCopyWith(
                        color: AppColors.gold,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppFx.softOverlay(0.24)),
                      ),
                      focusedBorder: OutlineInputBorder(
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
                        label: 'Yarı',
                        value: (maxQuantity / 2)
                            .floor()
                            .clamp(1, maxQuantity)
                            .toString(),
                      ),
                      NumericKeyboardShortcut(
                        label: 'Tamamı',
                        value: maxQuantity.toString(),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppFx.softOverlay(0.24)),
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            'İptal',
                            style: AppTextStyles.body.standardCopyWith(
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.textOnAccent,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: () {
                              final quantity =
                                  int.tryParse(controller.text) ?? 0;
                              if (quantity <= 0 || quantity > maxQuantity) {
                                AppSnackbar.show(
                                  sheetContext,
                                  title: 'Hata',
                                  message: 'Geçersiz miktar!',
                                  type: SnackbarType.error,
                                );
                                return;
                              }
                              Navigator.pop(dialogContext, quantity);
                            },
                            child: Text(
                              'Kaydet',
                              style: AppTextStyles.body.standardCopyWith(
                                fontSize: AppTypography.body,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                (slot) => _SelectedFarmInboundTransferItem(
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
          final currentUsedInputCapacity =
              (detail.farm.inputCapacity - remainingInputCapacity)
                  .clamp(0, detail.farm.inputCapacity)
                  .toDouble();
          final projectedInputCapacity =
              currentUsedInputCapacity + totalQuantity.toDouble();
          final currentInputRatio = detail.farm.inputCapacity <= 0
              ? 0.0
              : (currentUsedInputCapacity / detail.farm.inputCapacity).clamp(
                  0.0,
                  1.0,
                );
          final projectedInputRatio = detail.farm.inputCapacity <= 0
              ? 0.0
              : (projectedInputCapacity / detail.farm.inputCapacity).clamp(
                  0.0,
                  1.0,
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
                    'Alınacak Hammaddeleri Seç',
                    style: AppTextStyles.h2.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.headline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.035),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.borderGoldLight.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: AppFx.panelWash(0.16),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: AppColors.blue.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30.w,
                                      height: 30.w,
                                      decoration: BoxDecoration(
                                        color: AppFx.panelWash(0.22),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      child: Icon(
                                        AppIcons.warehouseRounded,
                                        color: AppColors.blue,
                                        size: AppIconSizes.compact,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            warehouse.warehouseName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize:
                                                      AppTypography.bodyLarge,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            warehouse.cityName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color: AppColors.goldLight,
                                                  fontSize: AppTypography.label,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          SizedBox(height: 5.h),
                                          _buildInlineMetaChip(
                                            'Kaynak Depo',
                                            AppColors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 30.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppFx.softOverlay(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderGoldLight.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              child: Icon(
                                AppIcons.arrowForwardRounded,
                                color: AppColors.gold,
                                size: AppIconSizes.regular,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(8.w),
                                decoration: BoxDecoration(
                                  color: AppFx.panelWash(0.16),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: AppColors.green.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30.w,
                                      height: 30.w,
                                      decoration: BoxDecoration(
                                        color: AppFx.panelWash(0.22),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      child: Icon(
                                        AppIcons.agricultureRounded,
                                        color: AppColors.green,
                                        size: AppIconSizes.compact,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            detail.farm.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize:
                                                      AppTypography.bodyLarge,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            detail.cityName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color: AppColors.goldLight,
                                                  fontSize: AppTypography.label,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          SizedBox(height: 5.h),
                                          _buildInlineMetaChip(
                                            'Hedef Tarla',
                                            AppColors.green,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tarla Boş: $remainingInputCapacity / ${detail.farm.inputCapacity} adet',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.textMuted,
                                  fontSize: AppTypography.bodySmall,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '%${(projectedInputRatio * 100).round()}',
                              style: AppTextStyles.body.standardCopyWith(
                                color: projectedInputRatio >= 0.9
                                    ? AppColors.red
                                    : projectedInputRatio >= 0.75
                                    ? AppColors.warning
                                    : AppColors.green,
                                fontSize: AppTypography.bodySmall,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          height: 9.h,
                          decoration: BoxDecoration(
                            color: AppFx.softOverlay(0.08),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999.r),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final totalWidth = constraints.maxWidth;
                                final currentWidth =
                                    totalWidth * currentInputRatio;
                                final projectedWidth =
                                    totalWidth * projectedInputRatio;
                                final rawAddedWidth =
                                    (projectedWidth - currentWidth).clamp(
                                      0.0,
                                      totalWidth,
                                    );
                                final addedWidth = rawAddedWidth > 0
                                    ? rawAddedWidth.clamp(3.0, totalWidth)
                                    : 0.0;
                                final baseWidth = currentWidth.clamp(
                                  0.0,
                                  totalWidth - addedWidth,
                                );

                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (baseWidth > 0)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: baseWidth,
                                          decoration: BoxDecoration(
                                            color: projectedInputRatio >= 0.9
                                                ? AppColors.red.withValues(
                                                    alpha: 0.75,
                                                  )
                                                : projectedInputRatio >= 0.75
                                                ? AppColors.warning.withValues(
                                                    alpha: 0.75,
                                                  )
                                                : AppColors.green.withValues(
                                                    alpha: 0.75,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              999.r,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (addedWidth > 0)
                                      Positioned(
                                        left: baseWidth,
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: addedWidth,
                                          decoration: BoxDecoration(
                                            color: AppColors.blue,
                                            borderRadius: BorderRadius.circular(
                                              999.r,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Seçilen: $totalQuantity adet | ${totalVolume.toStringAsFixed(1)} m3',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${selectedItems.length} stok | $totalQuantity adet | ${totalVolume.toStringAsFixed(1)} m3 seçildi',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.body,
                    ),
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
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: AppFx.softOverlay(0.04),
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
                              Container(
                                width: 42.w,
                                height: 42.w,
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: AppFx.panelWash(0.2),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color:
                                        (isSelected
                                                ? AppColors.green
                                                : AppFx.softOverlay(0.10))
                                            .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: BrandedProductImage(
                                  fileName: slot.productIcon ?? 'default.webp',
                                  productId: slot.productId,
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
                                      slot.productName,
                                      style: AppTextStyles.body
                                          .standardCopyWith(
                                            color: AppColors.textPrimary,
                                            fontSize: AppTypography.bodyLarge,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    SizedBox(height: 3.h),
                                    Row(
                                      children: [
                                        for (int i = 0; i < 5; i++)
                                          Icon(
                                            i < slot.qualityLevel
                                                ? AppIcons.starRounded
                                                : AppIcons.starBorderRounded,
                                            color: i < slot.qualityLevel
                                                ? AppColors.gold
                                                : AppFx.softOverlay(0.12),
                                            size: AppIconSizes.xSmall,
                                          ),
                                        SizedBox(width: 4.w),
                                        Expanded(
                                          child: Text(
                                            '| Stok ${slot.availableQuantity} | Hedef: ${slot.targetInventory.quantity}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color: AppColors.textMuted,
                                                  fontSize: AppTypography.label,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              OutlinedButton(
                                onPressed: maxQuantity <= 0
                                    ? null
                                    : () {
                                        if (!isSelected) {
                                          modalSetState(() {
                                            selectedQuantities[
                                                  slot.warehouseSlotId
                                                ] =
                                                maxQuantity;
                                          });
                                          return;
                                        }
                                        openQuantityEditor(
                                          sheetContext,
                                          modalSetState,
                                          slot,
                                        );
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isSelected
                                      ? AppColors.green
                                      : AppColors.goldLight,
                                ),
                                child: Text(
                                  isSelected
                                      ? 'Adet: $selectedQuantity'
                                      : 'Ekle',
                                  style: AppTextStyles.button.standardCopyWith(
                                    color: isSelected
                                        ? AppColors.green
                                        : AppColors.goldLight,
                                    fontSize: AppTypography.bodySmall,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                        foregroundColor: AppColors.textOnAccent,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: selectedItems.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              await _submitFarmInboundSelection(
                                context: context,
                                ref: ref,
                                detail: detail,
                                warehouse: warehouse,
                                items: selectedItems,
                              );
                            },
                      icon: const Icon(AppIcons.downloadRounded),
                      label: const Text('Tohum/Girdiyi Çek (Anında)'),
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

  Future<void> _submitFarmInboundSelection({
    required BuildContext context,
    required WidgetRef ref,
    required FarmDetailModel detail,
    required _FarmInboundWarehouseChoice warehouse,
    required List<_SelectedFarmInboundTransferItem> items,
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

    final result = await ref
        .read(farmActionProvider)
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
            : 'Transfer başarısız oldu.',
        type: SnackbarType.error,
      );
      return;
    }

    await _refreshFarmEcosystem(
      includeTransfers: true,
      includeWarehouseList: true,
      includePlayer: false,
    );
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      title: 'Başarılı',
      message: 'Seçilen tohum/girdiler tarlaya aktarıldı.',
      type: SnackbarType.success,
    );
  }

  Future<void> _showFarmOutboundSelectionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required FarmDetailModel detail,
    required ProductionLogisticsWarehouseOption targetWarehouse,
    WarehouseCapacityStatusModel? targetCapacityStatus,
    required List<FarmProductionInventoryModel> inventories,
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
      FarmProductionInventoryModel item,
    ) async {
      final controller = TextEditingController(
        text: ((selectedQuantities[item.id] ?? item.quantity).clamp(
          0,
          item.quantity,
        )).toString(),
      );
      final result = await showDialog<int>(
        context: sheetContext,
        builder: (dialogContext) => Dialog(
          backgroundColor: AppColors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: AppDecorations.premiumCard(AppColors.gold, 20.r),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    (item.product?.urunAdi ?? item.productId) +
                        (!item.isInput &&
                                item.brandId !=
                                    SelectableProductionProductModel
                                        .defaultBrandId
                            ? ' (${_currentBrandName ?? 'Markali'})'
                            : ''),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.titleLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < 5; i++)
                        Icon(
                          i < item.qualityLevel
                              ? AppIcons.starRounded
                              : AppIcons.starBorderRounded,
                          color: i < item.qualityLevel
                              ? AppColors.gold
                              : AppFx.softOverlay(0.24),
                          size: AppIconSizes.compact,
                        ),
                      SizedBox(width: 6.w),
                      Text(
                        'Q${item.qualityLevel}',
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.gold,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: Container(
                      width: 72.w,
                      height: 72.w,
                      margin: EdgeInsets.symmetric(vertical: 12.h),
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AppFx.panelWash(0.35),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: BrandedProductImage(
                        fileName: item.product?.urunIconu ?? 'default.webp',
                        brandId: item.brandId,
                        brandName:
                            !item.isInput &&
                                item.brandId !=
                                    SelectableProductionProductModel
                                        .defaultBrandId
                            ? _currentBrandName
                            : null,
                        productId: item.productId,
                        fit: BoxFit.contain,
                        showFrame: false,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 6.h,
                      horizontal: 12.w,
                    ),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.03),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppFx.softOverlay(0.10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mevcut Stok:',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                        Text(
                          '${item.quantity} Adet',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: controller,
                    readOnly: true,
                    showCursor: true,
                    enableInteractiveSelection: false,
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Miktar (Maks: ${item.quantity})',
                      labelStyle: AppTextStyles.body.standardCopyWith(
                        color: AppColors.gold,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppFx.softOverlay(0.24)),
                      ),
                      focusedBorder: OutlineInputBorder(
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
                        label: 'Yarı',
                        value: (item.quantity / 2)
                            .floor()
                            .clamp(1, item.quantity)
                            .toString(),
                      ),
                      NumericKeyboardShortcut(
                        label: 'Tamamı',
                        value: item.quantity.toString(),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppFx.softOverlay(0.24)),
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(
                            'İptal',
                            style: AppTextStyles.body.standardCopyWith(
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.textOnAccent,
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: () {
                              final quantity =
                                  int.tryParse(controller.text) ?? 0;
                              if (quantity <= 0 || quantity > item.quantity) {
                                AppSnackbar.show(
                                  sheetContext,
                                  title: 'Hata',
                                  message: 'Geçersiz miktar!',
                                  type: SnackbarType.error,
                                );
                                return;
                              }
                              Navigator.pop(dialogContext, quantity);
                            },
                            child: Text(
                              'Kaydet',
                              style: AppTextStyles.body.standardCopyWith(
                                fontSize: AppTypography.body,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                (item) => _SelectedFarmProductionTransferItem(
                  inventory: item,
                  quantity: selectedQuantities[item.id] ?? 0,
                ),
              )
              .toList();
          final totalQuantity = selectedItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final totalVolume = selectedItems.fold<double>(
            0,
            (sum, item) =>
                sum +
                (item.quantity *
                    _resolveFarmInventoryUnitVolume(detail, item.inventory)),
          );
          final currentUsedCapacity = targetCapacityStatus == null
              ? 0.0
              : targetCapacityStatus.usedCapacity +
                    targetCapacityStatus.reservedCapacity;
          final projectedUsedCapacity = currentUsedCapacity + totalVolume;
          final currentCapacityRatio =
              targetCapacityStatus == null ||
                  targetCapacityStatus.totalCapacity <= 0
              ? 0.0
              : (currentUsedCapacity / targetCapacityStatus.totalCapacity)
                    .clamp(0.0, 1.0);
          final projectedCapacityRatio =
              targetCapacityStatus == null ||
                  targetCapacityStatus.totalCapacity <= 0
              ? 0.0
              : (projectedUsedCapacity / targetCapacityStatus.totalCapacity)
                    .clamp(0.0, 1.0);

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
                    'Depoya Gönderilecek Stokları Seç',
                    style: AppTextStyles.h2.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.headline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.035),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppColors.borderGoldLight.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: AppFx.panelWash(0.16),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: AppColors.blue.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30.w,
                                      height: 30.w,
                                      decoration: BoxDecoration(
                                        color: AppFx.panelWash(0.22),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      child: Icon(
                                        AppIcons.agricultureRounded,
                                        color: AppColors.blue,
                                        size: AppIconSizes.compact,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            detail.farm.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize:
                                                      AppTypography.bodyLarge,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            detail.cityName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color: AppColors.goldLight,
                                                  fontSize: AppTypography.label,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          SizedBox(height: 5.h),
                                          _buildInlineMetaChip(
                                            'Kaynak Tarla',
                                            AppColors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Container(
                              width: 34.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppFx.softOverlay(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.borderGoldLight.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                              child: Icon(
                                AppIcons.arrowForwardRounded,
                                color: AppColors.gold,
                                size: AppIconSizes.regular,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: AppFx.panelWash(0.16),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: AppColors.green.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30.w,
                                      height: 30.w,
                                      decoration: BoxDecoration(
                                        color: AppFx.panelWash(0.22),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                      ),
                                      child: Icon(
                                        AppIcons.warehouseRounded,
                                        color: AppColors.green,
                                        size: AppIconSizes.compact,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            targetWarehouse.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize:
                                                      AppTypography.bodyLarge,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            targetWarehouse.cityName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.caption
                                                .standardCopyWith(
                                                  color: AppColors.goldLight,
                                                  fontSize: AppTypography.label,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          SizedBox(height: 5.h),
                                          _buildInlineMetaChip(
                                            'Hedef Depo',
                                            AppColors.green,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (targetCapacityStatus != null) ...[
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Boş: ${targetCapacityStatus.availableCapacity.toStringAsFixed(1)} / ${targetCapacityStatus.totalCapacity.toStringAsFixed(1)} m3',
                                  style: AppTextStyles.body.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.bodySmall,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '%${(projectedCapacityRatio * 100).round()}',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: projectedCapacityRatio >= 0.9
                                      ? AppColors.red
                                      : projectedCapacityRatio >= 0.75
                                      ? AppColors.warning
                                      : AppColors.green,
                                  fontSize: AppTypography.bodySmall,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            height: 9.h,
                            decoration: BoxDecoration(
                              color: AppFx.softOverlay(0.08),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999.r),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final totalWidth = constraints.maxWidth;
                                  final currentWidth =
                                      totalWidth * currentCapacityRatio;
                                  final projectedWidth =
                                      totalWidth * projectedCapacityRatio;
                                  final rawAddedWidth =
                                      (projectedWidth - currentWidth).clamp(
                                        0.0,
                                        totalWidth,
                                      );
                                  final addedWidth = rawAddedWidth > 0
                                      ? rawAddedWidth.clamp(3.0, totalWidth)
                                      : 0.0;
                                  final baseWidth = currentWidth.clamp(
                                    0.0,
                                    totalWidth - addedWidth,
                                  );

                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (baseWidth > 0)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: baseWidth,
                                            decoration: BoxDecoration(
                                              color:
                                                  projectedCapacityRatio >= 0.9
                                                  ? AppColors.red.withValues(
                                                      alpha: 0.75,
                                                    )
                                                  : projectedCapacityRatio >=
                                                        0.75
                                                  ? AppColors.warning
                                                        .withValues(alpha: 0.75)
                                                  : AppColors.green.withValues(
                                                      alpha: 0.75,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(999.r),
                                            ),
                                          ),
                                        ),
                                      if (addedWidth > 0)
                                        Positioned(
                                          left: baseWidth,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: addedWidth,
                                            decoration: BoxDecoration(
                                              color: AppColors.gold,
                                              borderRadius:
                                                  BorderRadius.circular(999.r),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'Seçilen Hacim: ${totalVolume.toStringAsFixed(1)} m3',
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.textMuted,
                              fontSize: AppTypography.bodySmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${selectedItems.length} stok | $totalQuantity adet seçildi',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.body,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final outputList = sortedInventories
                            .where((i) => !i.isInput)
                            .toList();
                        final inputList = sortedInventories
                            .where((i) => i.isInput)
                            .toList();

                        return ListView(
                          children: [
                            if (outputList.isNotEmpty) ...[
                              _buildOutboundCategoryHeader(
                                title: 'Üretilen Ürünler (Çiftlik Ürünleri)',
                                subtitle:
                                    'Çiftlikte üretilen ürünleri depoya aktar',
                                icon: AppIcons.inventory2Rounded,
                                color: AppColors.green,
                                count: outputList.length,
                              ),
                              SizedBox(height: 8.h),
                              for (final item in outputList) ...[
                                _buildOutboundInventoryTile(
                                  item: item,
                                  sheetContext: sheetContext,
                                  modalSetState: modalSetState,
                                  selectedQuantities: selectedQuantities,
                                  openQuantityEditor: openQuantityEditor,
                                ),
                                SizedBox(height: 8.h),
                              ],
                              SizedBox(height: 8.h),
                            ],
                            if (inputList.isNotEmpty) ...[
                              _buildOutboundCategoryHeader(
                                title: 'Hammaddeler (Yem & Girdiler)',
                                subtitle:
                                    'Çiftlikteki yem ve hammaddeleri depoya geri gönder',
                                icon: AppIcons.layersOutlined,
                                color: AppColors.blue,
                                count: inputList.length,
                              ),
                              SizedBox(height: 8.h),
                              for (final item in inputList) ...[
                                _buildOutboundInventoryTile(
                                  item: item,
                                  sheetContext: sheetContext,
                                  modalSetState: modalSetState,
                                  selectedQuantities: selectedQuantities,
                                  openQuantityEditor: openQuantityEditor,
                                ),
                                SizedBox(height: 8.h),
                              ],
                            ],
                          ],
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
                        foregroundColor: AppColors.textOnAccent,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      onPressed: selectedItems.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              final result = await ref
                                  .read(farmActionProvider)
                                  .startMultiProductionToWarehouseTransfer(
                                    sourceOwnerKind: 'farm',
                                    sourceOwnerId: widget.farmId,
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
                                await _refreshFarmEcosystem(
                                  warehouseId: targetWarehouse.id,
                                  includeTransfers: true,
                                  includePlayer: false,
                                );
                                if (!context.mounted) return;
                                AppSnackbar.show(
                                  context,
                                  title: 'Başarılı',
                                  message:
                                      'Seçilen ürünler Genel Depoya aktarıldı.',
                                  type: SnackbarType.success,
                                );
                                return;
                              }
                              AppSnackbar.show(
                                context,
                                title: 'Hata',
                                message: result.message.isNotEmpty
                                    ? result.message
                                    : 'Transfer başarısız oldu.',
                                type: SnackbarType.error,
                              );
                            },
                      icon: const Icon(AppIcons.warehouseRounded),
                      label: const Text('Genel Depoya Aktar (Anında)'),
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

  bool _isSameCity(String warehouseCityId, String productionCityId) {
    return warehouseCityId.isNotEmpty &&
        productionCityId.isNotEmpty &&
        warehouseCityId == productionCityId;
  }

  Widget _buildOutboundCategoryHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int count,
  }) {
    return Container(
      margin: EdgeInsets.only(top: 4.h, bottom: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: AppIconSizes.small),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.standardCopyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: AppTypography.bodySmall,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.micro,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              '$count Çeşit',
              style: AppTextStyles.caption.standardCopyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.micro,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutboundInventoryTile({
    required FarmProductionInventoryModel item,
    required BuildContext sheetContext,
    required StateSetter modalSetState,
    required Map<String, int> selectedQuantities,
    required Future<void> Function(
      BuildContext sheetContext,
      StateSetter modalSetState,
      FarmProductionInventoryModel item,
    ) openQuantityEditor,
  }) {
    final selectedQuantity = selectedQuantities[item.id] ?? 0;
    final isSelected = selectedQuantity > 0;
    final isOutput = !item.isInput;
    final accentColor = isOutput ? AppColors.green : AppColors.blue;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.04),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: (isSelected ? accentColor : AppColors.borderGoldLight)
              .withValues(alpha: isSelected ? 0.40 : 0.15),
          width: isSelected ? 1.2.w : 1.w,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: AppFx.panelWash(0.2),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: (isSelected ? accentColor : AppFx.softOverlay(0.10))
                    .withValues(alpha: 0.2),
              ),
            ),
            child: BrandedProductImage(
              fileName: item.product?.urunIconu ?? 'default.webp',
              brandId: item.brandId,
              brandName: isOutput &&
                      item.brandId !=
                          SelectableProductionProductModel.defaultBrandId
                  ? _currentBrandName
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
                  (item.product?.urunAdi ?? item.productId) +
                      (isOutput &&
                              item.brandId !=
                                  SelectableProductionProductModel
                                      .defaultBrandId
                          ? ' (${_currentBrandName ?? 'Markali'})'
                          : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodyLarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    for (int i = 0; i < 5; i++)
                      Icon(
                        i < item.qualityLevel
                            ? AppIcons.starRounded
                            : AppIcons.starBorderRounded,
                        color: i < item.qualityLevel
                            ? AppColors.gold
                            : AppFx.softOverlay(0.12),
                        size: AppIconSizes.xSmall,
                      ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        '| Stok: ${item.quantity} ad.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.label,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          OutlinedButton(
            onPressed: () {
              if (!isSelected) {
                modalSetState(() {
                  selectedQuantities[item.id] = item.quantity;
                });
                return;
              }
              openQuantityEditor(
                sheetContext,
                modalSetState,
                item,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isSelected ? accentColor : AppColors.goldLight,
              side: BorderSide(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.6)
                    : AppColors.goldLight.withValues(alpha: 0.4),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            ),
            child: Text(
              isSelected ? 'Adet: $selectedQuantity' : 'Ekle',
              style: AppTextStyles.button.standardCopyWith(
                color: isSelected ? accentColor : AppColors.goldLight,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateUsedCapacity(List<FarmProductionInventoryModel> inventories) {
    var total = 0;
    for (final inventory in inventories) {
      total += inventory.quantity;
    }
    return total;
  }

  int _calculateRemainingInputCapacity(
    List<FarmProductionInventoryModel> inventories,
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
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  double _resolveFarmInventoryUnitVolume(
    FarmDetailModel detail,
    FarmProductionInventoryModel inventory,
  ) {
    if (inventory.unitVolume > 0) return inventory.unitVolume;
    final productVolume = inventory.product?.birimHacim ?? 0;
    if (productVolume > 0) return productVolume;

    for (final candidate in detail.inventories) {
      if (candidate.productId != inventory.productId) continue;
      if (candidate.unitVolume > 0) return candidate.unitVolume;
      final candidateProductVolume = candidate.product?.birimHacim ?? 0;
      if (candidateProductVolume > 0) return candidateProductVolume;
    }

    for (final slot in detail.slots) {
      final slotProduct = slot.product;
      if (slotProduct == null || slot.productId != inventory.productId) {
        continue;
      }
      if (slotProduct.birimHacim > 0) return slotProduct.birimHacim;
    }

    return 0;
  }

  Color _inputColorForProduct(String productId) {
    final palette = <Color>[
      AppColors.blue,
      AppColors.green,
      AppColors.warning,
      AppColors.goldDark,
      AppColors.gold,
      AppColors.borderGold,
    ];
    final hash = productId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[hash % palette.length];
  }

  String _estimateProductionPerHour(
    FarmProductionSlotModel slot,
    BuildingBoostModel? activeBoost,
    String cityId,
  ) {
    final product = slot.product;
    if (product == null) return '0';
    final qualityMultiplier = 1.0 + (slot.qualityLevel - 1) * 0.20;
    final double cityBonus = _getCityProductBonus(cityId, product.kategori);
    final perHour =
        product.uretimAdedi *
        (activeBoost?.multiplier ?? 1) *
        qualityMultiplier *
        cityBonus;
    return perHour.toStringAsFixed(perHour >= 10 ? 0 : 1);
  }

  Widget _buildQualityStars(int quality) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < quality;
        return Padding(
          padding: EdgeInsets.only(right: 2.w),
          child: Icon(
            isFilled ? AppIcons.star : AppIcons.starBorder,
            color: isFilled ? AppColors.gold : AppColors.textMuted,
            size: AppIconSizes.small,
          ),
        );
      }),
    );
  }

  double _getCityProductBonus(String cityId, String? productCategory) {
    if (productCategory == null || productCategory.isEmpty) return 1.0;
    final cities = ref.watch(citiesProvider).value;
    if (cities == null) return 1.0;

    final city = cities.cast<CityModel?>().firstWhere(
      (c) => c != null && c.id == cityId,
      orElse: () => null,
    );
    if (city == null) return 1.0;

    String clean = productCategory.toLowerCase().trim();
    clean = clean
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('/', '_')
        .replaceAll('&', 've');

    final String key = 'bonus_$clean';
    return city.categoryBonuses[key] ?? 1.0;
  }

  Future<void> _showSellFarmDialog(BuildContext context) async {
    final detail = ref.read(farmDetailProvider(widget.farmId)).value;
    if (detail == null) return;
    final farm = detail.farm;

    final quote = await ref
        .read(farmActionProvider)
        .sellFarm(farmId: farm.id, confirm: false);

    if (!context.mounted) return;

    if (quote['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: quote['message'] ?? 'Satış teklifi hazırlanamadı.',
        type: SnackbarType.error,
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
          'Tarlayı Sat',
          style: AppTextStyles.h2.standardCopyWith(
            color: AppColors.red,
            fontSize: AppTypography.headline,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${farm.name} kalici olarak silinecek. Bu islem geri alinamaz.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodyLarge,
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
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _buildSalesSummaryRow('Kurulus Iadesi', constructionRefund),
                  _buildSalesSummaryRow('Stok Iadesi', stockRefund),
                  Divider(color: AppColors.border, height: 12.h),
                  _buildSalesSummaryRow('Toplam Odeme', totalRefund, valueColor: AppColors.green),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Aktif transferler veya devam eden uretim varsa satis engellenir.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
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
            child: Text(
              'Tarlayı Sat',
              style: AppTextStyles.button.standardCopyWith(
                color: AppColors.textOnAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldSell != true || !context.mounted) return;

    final result = await ref
        .read(farmActionProvider)
        .sellFarm(farmId: farm.id, confirm: true, syncProviders: false);

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref.read(farmListProvider.notifier).removeFarm(farm.id);
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'Tarla satıldı. ${totalRefund.toStringAsFixed(1)} TL iade edildi.',
        type: SnackbarType.success,
      );
      context.go('/farms');
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Tarla satılamadı.',
      type: SnackbarType.error,
    );
  }

  Widget _buildSalesSummaryRow(String label, double value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.body,
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)} TL',
            style: AppTextStyles.body.standardCopyWith(
              color: valueColor ?? AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedFarmProductionTransferItem {
  final FarmProductionInventoryModel inventory;
  final int quantity;

  const _SelectedFarmProductionTransferItem({
    required this.inventory,
    required this.quantity,
  });
}

class _FarmInboundWarehouseChoice {
  final String warehouseId;
  final String warehouseName;
  final String cityId;
  final String cityName;
  final bool isSameCity;
  final List<_FarmInboundWarehouseSlotOption> slots;
  final double capacity;
  final double reservedCapacity;
  final List<WarehouseSelectionProductPreview>? productPreviews;

  const _FarmInboundWarehouseChoice({
    required this.warehouseId,
    required this.warehouseName,
    required this.cityId,
    required this.cityName,
    required this.isSameCity,
    required this.slots,
    required this.capacity,
    required this.reservedCapacity,
    this.productPreviews,
  });
}

class _FarmInboundWarehouseSlotOption {
  final String warehouseSlotId;
  final String productId;
  final String productName;
  final String? productIcon;
  final int qualityLevel;
  final int availableQuantity;
  final double unitVolume;
  final FarmProductionInventoryModel targetInventory;

  const _FarmInboundWarehouseSlotOption({
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

class _SelectedFarmInboundTransferItem {
  final _FarmInboundWarehouseSlotOption slot;
  final int quantity;

  const _SelectedFarmInboundTransferItem({
    required this.slot,
    required this.quantity,
  });
}

String _inventoryKey(String productId, int qualityLevel) {
  return '$productId::$qualityLevel';
}

class _ActiveFarmBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveFarmBoostCard({required this.boost});

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
                  AppIcons.flashOnRounded,
                  color: AppColors.goldDark,
                  size: AppIconSizes.regular,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boost Aktif',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${boost.durationLabel} | Katsayi x${boost.multiplier.toStringAsFixed(1)} | ${boost.starCost > 0 ? '${boost.starCost} yildiz' : 'Reklam odulu'}',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCountdownLabel(remaining),
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: AppProgressBar(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFarmUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final Future<void> Function()? onReduceTimeWithAd;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveFarmUpgradeCard({
    required this.upgrade,
    required this.onFinishWithGold,
    this.onReduceTimeWithAd,
    required this.calculateStarCost,
    required this.formatCountdown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final totalSeconds = upgrade.finishAt
        .difference(upgrade.startedAt)
        .inSeconds;
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
                  AppIcons.upgradeRounded,
                  color: AppColors.green,
                  size: AppIconSizes.regular,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarla Yükseltmesi Devam Ediyor',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Seviye ${upgrade.currentLevel} -> ${upgrade.targetLevel} | Hammadde ${upgrade.previousInputCapacity} -> ${upgrade.nextInputCapacity} | Cikti ${upgrade.previousOutputCapacity} -> ${upgrade.nextOutputCapacity}',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCountdown(remaining),
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.gold,
                  fontSize: AppTypography.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: AppProgressBar(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.textPrimary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
                foregroundColor: AppColors.goldLight,
              ),
              onPressed: onFinishWithGold,
              icon: const Icon(AppIcons.starRounded),
              label: Text(
                '${calculateStarCost(upgrade.finishAt)} yildiz ile bitir',
              ),
            ),
          ),
          if (remaining.inSeconds > 0 && onReduceTimeWithAd != null) ...[
            SizedBox(height: 10.h),
            RewardedTimeReduceButton(
              onPressed: () => onReduceTimeWithAd!.call(),
              caption:
                  'Bir reklam ödülü al ve tarla yükseltme süresini 10 dakika kısalt.',
            ),
          ],
        ],
      ),
    );
  }
}

String _formatCountdownLabel(Duration remaining) {
  if (remaining.inSeconds <= 0) return 'Tamamlanıyor';
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours > 0) {
    return '${hours}s ${minutes}dk';
  }
  return '${remaining.inMinutes}dk';
}
