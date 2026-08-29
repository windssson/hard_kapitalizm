import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_quote_provider.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/models/building_boost_model.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:hard_kapitalizm/core/models/selectable_production_product_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/utils/experience_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/building_upgrade_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/rewarded_time_reduce_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_detail_model.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart'
    show warehouseCapacityStatusProvider;
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/production_quality_warning_dialog.dart';
import 'package:hard_kapitalizm/core/data/player_active_products_service.dart';

class FactoryDetailScreen extends ConsumerStatefulWidget {
  final String factoryId;

  const FactoryDetailScreen({super.key, required this.factoryId});

  @override
  ConsumerState<FactoryDetailScreen> createState() =>
      _FactoryDetailScreenState();
}

class _FactoryDetailScreenState extends ConsumerState<FactoryDetailScreen> {
  static const Map<int, int> _factoryBoostStarCosts = {6: 3, 12: 6, 24: 12};

  String? get _currentBrandName =>
      ref.read(playerBrandCompanyProvider).value?.brandName;

  Future<void> _refreshFactoryDetail() async {
    await Future.wait([
      ref.read(factoryDetailProvider(widget.factoryId).notifier).refresh(),
      ref.read(activeFactoryBoostProvider(widget.factoryId).future),
      ref.read(activeFactoryUpgradeProvider(widget.factoryId).future),
    ]);
  }

  Future<void> _refreshFactoryEcosystem({
    String? warehouseId,
    bool includeTransfers = false,
    bool includeWarehouseList = false,
    bool includePlayer = true,
  }) async {
    _refreshFactoryDetail();
    ref.invalidate(factoryListProvider);
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

    await ref.read(factoryDetailProvider(widget.factoryId).future);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(playerBrandCompanyProvider);
    final detailAsync = ref.watch(factoryDetailProvider(widget.factoryId));
    final activeBoost = ref
        .watch(activeFactoryBoostProvider(widget.factoryId))
        .value;
    final activeUpgrade = ref
        .watch(activeFactoryUpgradeProvider(widget.factoryId))
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
              title: 'Fabrika Yönetimi',
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
                      _showSellFactoryDialog(context);
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
                            'Fabrikayı Sat',
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
                    _refreshFactoryDetail();
                    await ref.read(
                      factoryDetailProvider(widget.factoryId).future,
                    );
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(5.w, 8.h, 5.w, 24.h),
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final listAsync = ref.watch(factoryListProvider);
                          return listAsync.maybeWhen(
                            data: (list) {
                              if (list.length <= 1) return const SizedBox.shrink();
                              final hasCurrent = list.any(
                                (item) => item.factory.id == widget.factoryId,
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
                                    value: widget.factoryId,
                                    isExpanded: true,
                                    dropdownColor: AppColors.cardBg,
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.gold,
                                    ),
                                    items: list.map((item) {
                                      final f = item.factory;
                                      final displayCity = item.cityName;
                                      return DropdownMenuItem<String>(
                                        value: f.id,
                                        child: Row(
                                          children: [
                                            Icon(
                                              AppIcons.factory,
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
                                          newId != widget.factoryId) {
                                        context.pushReplacement(
                                          '/factories/$newId',
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
                        _ActiveFactoryBoostCard(boost: activeBoost),
                      ],
                      if (activeUpgrade != null) ...[
                        SizedBox(height: 12.h),
                        _ActiveFactoryUpgradeCard(
                          upgrade: activeUpgrade,
                          onFinishWithGold: () =>
                              _finishFactoryUpgradeWithGold(activeUpgrade),
                          onReduceTimeWithAd: () =>
                              _reduceFactoryUpgradeTimeWithAd(activeUpgrade),
                          calculateStarCost: _calculateUpgradeStarCost,
                          formatCountdown: _formatCountdown,
                        ),
                      ],
                      SizedBox(height: 14.h),
                      _buildSectionHeader(
                        'Uretim Hatti',
                        'Fabrikanın aktif ürününü, hammadde akışını ve depoya sevklerini buradan yönetebilirsin.',
                        icon: AppIcons.precisionManufacturingRounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      _buildProductionCard(context, ref, detail, activeBoost),
                      if (detail.orphanInputInventories.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        _buildSectionHeader(
                          'Bagli Olmayan Hammaddeler',
                          'Ürün değişikliği sonrasında elde kalan hammaddeleri buradan depoya geri gönderebilirsin.',
                          icon: AppIcons.inventory2Outlined,
                          color: AppColors.blue,
                        ),
                        SizedBox(height: 10.h),
                        ...detail.orphanInputInventories.map(
                          (inventory) => _buildInputInventoryCard(
                            context,
                            ref,
                            detail,
                            inventory,
                            isOrphan: true,
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

  Widget _buildHero(FactoryDetailModel detail) {
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
                      fileName: detail.factoryType.icon,
                      fit: BoxFit.contain,
                      errorWidget: Icon(
                        AppIcons.precisionManufacturingRounded,
                        color: AppColors.gold,
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
                                detail.factory.name,
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
                                detail.factoryType.name,
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
                  '${detail.inputInventories.fold<int>(0, (sum, item) => sum + item.quantity)}/${detail.factory.inputCapacity}',
                  AppColors.blue,
                  ratio: _safeProgress(
                    detail.inputInventories
                        .fold<int>(0, (sum, item) => sum + item.quantity)
                        .toDouble(),
                    detail.factory.inputCapacity.toDouble(),
                  ),
                  icon: AppIcons.scienceOutlined,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildHeroStat(
                  'Üretilen ürün',
                  '${detail.outputInventories.isNotEmpty ? detail.outputInventories.first.quantity : 0}/${detail.factory.outputCapacity}',
                  AppColors.green,
                  ratio: _safeProgress(
                    (detail.outputInventories.isNotEmpty
                            ? detail.outputInventories.first.quantity
                            : 0)
                        .toDouble(),
                    detail.factory.outputCapacity.toDouble(),
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
          AppProgressBar.stock(value: ratio, size: AppProgressSize.compact),
        ],
      ),
    );
  }

  Widget _buildHeroChipColumn(FactoryDetailModel detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [_buildTag('Lv ${detail.factory.level}', AppColors.gold)],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    final hasProduct = detail.product != null;
    final canBoost = hasProduct && detail.factory.isActive;
    final canUpgrade = detail.factory.isActive;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.18),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppFx.softOverlay(0.05)),
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
                  () => _startFactoryReceiveFlow(context, ref, detail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Ürün Gönder',
                  AppIcons.localShippingRounded,
                  AppColors.blue,
                  () => _startFactorySendFlow(context, ref, detail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  detail.factory.isActive ? 'Durdur' : 'Baslat',
                  detail.factory.isActive
                      ? AppIcons.stopCircleOutlined
                      : AppIcons.playCircleOutline,
                  detail.factory.isActive ? AppColors.red : AppColors.green,
                  hasProduct
                      ? () => _toggleFactoryActive(context, ref, detail)
                      : () {
                          AppSnackbar.show(
                            context,
                            title: 'Bilgi',
                            message:
                                'Üretimi başlatmadan önce fabrikaya bir ürün atamalısın.',
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
                  AppIcons.flashOnRounded,
                  canBoost ? AppColors.goldDark : AppColors.textMuted,
                  canBoost
                      ? () => _showFactoryBoostSheet(
                          context,
                          ref,
                          detail,
                          activeBoost,
                        )
                      : () {
                          AppSnackbar.show(
                            context,
                            title: 'Bilgi',
                            message: hasProduct
                                ? 'Boost başlatmak için fabrikanın aktif olması gerekir.'
                                : 'Boost başlatmadan önce fabrikaya bir ürün atamalısın.',
                            type: SnackbarType.info,
                          );
                        },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Yukselt',
                  AppIcons.upgradeRounded,
                  canUpgrade ? AppColors.green : AppColors.textMuted,
                  canUpgrade
                      ? () => _showFactoryUpgradeSheet(
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
                                'Yükseltme başlatmak için fabrikanın aktif olması gerekir.',
                            type: SnackbarType.info,
                          );
                        },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Rapor',
                  AppIcons.queryStatsRounded,
                  AppColors.blue,
                  () => context.push(
                    '/production-report/factory/${detail.factory.id}?name=${Uri.encodeComponent(detail.factory.name)}',
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
            Icon(icon, color: color, size: AppIconSizes.small),
            SizedBox(height: 3.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.standardCopyWith(
                color: color,
                fontSize: AppTypography.caption,
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
              child: Icon(icon, color: color, size: AppIconSizes.compact),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h2.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          subtitle,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message, {Widget? action}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppFx.softOverlay(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.body,
            ),
          ),
          if (action != null) ...[SizedBox(height: 12.h), action],
        ],
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
        style: AppTextStyles.caption.standardCopyWith(
          color: color,
          fontSize: AppTypography.label,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProductionCard(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    BuildingBoostModel? activeBoost,
  ) {
    if (detail.product == null) {
      return _buildEmptyCard(
        'Fabrikada henüz seçili bir ürün yok. Önce ürün seçerek üretim hattını aktifleştir.',
        action: Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _showProductDialog(context, ref, detail),
            icon: const Icon(AppIcons.categoryOutlined),
            label: const Text('Ürün Seç'),
          ),
        ),
      );
    }

    final product = detail.product!;
    final outputInventory = detail.outputInventories.isNotEmpty
        ? detail.outputInventories.first
        : null;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(
        detail.factory.isActive ? AppColors.gold : null,
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
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.3),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: BrandedProductImage(
                  fileName: product.urunIconu,
                  fit: BoxFit.contain,
                  brandId: detail.factory.brandId,
                  brandName:
                      detail.factory.brandId !=
                          SelectableProductionProductModel.defaultBrandId
                      ? _currentBrandName
                      : null,
                  productId: product.id,
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
                            product.urunAdi +
                                (detail.factory.brandId !=
                                        SelectableProductionProductModel
                                            .defaultBrandId
                                    ? ' (${_currentBrandName ?? 'Markalı'})'
                                    : ''),
                            style: AppTextStyles.title.standardCopyWith(
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.title,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        _buildTag(
                          detail.factory.isActive ? 'AKTIF' : 'PASIF',
                          detail.factory.isActive
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
                              _showProductDialog(context, ref, detail);
                            } else if (value == 'toggle') {
                              _toggleFactoryActive(context, ref, detail);
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
                                    'Ürün Değiştir',
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
                                    detail.factory.isActive
                                        ? AppIcons.stopCircle
                                        : AppIcons.playCircle,
                                    color: detail.factory.isActive
                                        ? AppColors.red
                                        : AppColors.green,
                                    size: AppIconSizes.regular,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    detail.factory.isActive
                                        ? 'Uretimi Durdur'
                                        : 'Uretime Basla',
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
                    _buildFactoryStatsRow(detail, outputInventory, activeBoost),
                  ],
                ),
              ),
            ],
          ),
          _buildProductionFormulaRow(product, detail.inputInventories),
          if (outputInventory != null) ...[
            SizedBox(height: 10.h),
            _buildOutputSummaryRow(context, ref, detail, outputInventory),
          ],
          SizedBox(height: 10.h),
          _buildFlowSection(
            title: 'Hammadde',
            color: AppColors.blue,
            child: detail.inputInventories.isEmpty
                ? _buildInlineEmptyState(
                    'Bu ürün için bağlı hammadde stoğu bulunmuyor.',
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
                        _buildSharedInputCapacityBar(detail),
                        if (detail.inputInventories.isNotEmpty) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Divider(
                              color: AppFx.softOverlay(0.06),
                              height: 1.h,
                            ),
                          ),
                          ...detail.inputInventories.map(
                            (inventory) => _buildCompactInventoryRow(inventory),
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

  Widget _buildFactoryStatsRow(
    FactoryDetailModel detail,
    FactoryProductionInventoryModel? outputInventory,
    BuildingBoostModel? activeBoost,
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
              _buildQualityStars(detail.factory.qualityLevel),
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
                    '${(outputInventory?.cost ?? 0).toStringAsFixed(2)} TL',
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
                'Üretim / Saat',
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
                    _estimateProductionPerHour(detail, activeBoost).toString(),
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
        ],
      ),
    );
  }

  Widget _buildProductionFormulaRow(
    ProductModel product,
    List<dynamic> inputInventories,
  ) {
    final List<Widget> items = [];

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
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.label,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.label,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSharedInputCapacityBar(FactoryDetailModel detail) {
    final capacity = detail.factory.inputCapacity;
    final totalStock = detail.inputInventories.fold<int>(
      0,
      (sum, inventory) => sum + inventory.quantity,
    );
    final totalPending = detail.inputInventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.pendingQuantity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$totalStock adet | ${totalPending.toStringAsFixed(1)} yolda / $capacity adet',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8.h),
        _buildFactorySegmentedCapacityBar(detail),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 6.h,
          children: [
            ...detail.inputInventories.map(
              (inventory) => _buildCapacityLegendChip(
                inventory.product?.urunAdi ?? inventory.productId,
                _inputColorForProduct(inventory.productId),
              ),
            ),
            _buildCapacityLegendChip('Yolda', AppColors.goldDark),
          ],
        ),
      ],
    );
  }

  Widget _buildFactorySegmentedCapacityBar(FactoryDetailModel detail) {
    final capacity = detail.factory.inputCapacity;
    if (capacity <= 0) {
      return Container(
        height: 8.h,
        decoration: BoxDecoration(
          color: AppFx.panelWash(0.35),
          borderRadius: BorderRadius.circular(999.r),
        ),
      );
    }

    final segments = <({double amount, Color color})>[];
    for (final inventory in detail.inputInventories) {
      if (inventory.quantity > 0) {
        segments.add((
          amount: inventory.quantity.toDouble(),
          color: _inputColorForProduct(inventory.productId),
        ));
      }
    }

    final totalPending = detail.inputInventories.fold<double>(
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
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textSecondary,
              fontSize: AppTypography.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInventoryRow(FactoryProductionInventoryModel inventory) {
    final isBranded =
        !inventory.isInput &&
        inventory.brandId != SelectableProductionProductModel.defaultBrandId;
    final title =
        (inventory.product?.urunAdi.isNotEmpty == true
            ? inventory.product!.urunAdi
            : inventory.productId) +
        (isBranded ? ' (${_currentBrandName ?? 'Markalı'})' : '');
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
                  style: AppTextStyles.body.standardCopyWith(
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

  Widget _buildOutputSummaryRow(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    FactoryProductionInventoryModel? inventory,
  ) {
    final quantity = inventory?.quantity ?? 0;
    final isBranded =
        (inventory?.brandId ?? detail.factory.brandId) !=
        SelectableProductionProductModel.defaultBrandId;
    final progress = _safeProgress(
      quantity.toDouble(),
      detail.factory.outputCapacity.toDouble(),
    );

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.inventory2Outlined,
                color: AppColors.green,
                size: AppIconSizes.small,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Üretilen Ürün Stoğu',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isBranded) ...[
                _buildInlineMetaChip('Markalı', AppColors.gold),
                SizedBox(width: 6.w),
              ],
              Text(
                '$quantity / ${detail.factory.outputCapacity} ad',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.green,
                  fontSize: AppTypography.bodySmall,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          AppProgressBar(value: progress, kind: AppProgressKind.positive),
        ],
      ),
    );
  }

  Widget _buildInputInventoryCard(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    FactoryProductionInventoryModel inventory, {
    bool isOrphan = false,
  }) {
    final isBranded =
        !inventory.isInput &&
        inventory.brandId != SelectableProductionProductModel.defaultBrandId;
    final title =
        (inventory.product?.urunAdi.isNotEmpty == true
            ? inventory.product!.urunAdi
            : inventory.productId) +
        (isBranded ? ' (${_currentBrandName ?? 'Markalı'})' : '');
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
                    Row(
                      children: [
                        _buildQualityStars(inventory.qualityLevel),
                        if (!inventory.isInput) ...[
                          SizedBox(width: 6.w),
                          _buildInlineMetaChip(
                            inventory.brandId !=
                                    SelectableProductionProductModel
                                        .defaultBrandId
                                ? 'Markalı'
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
          if (isOrphan) ...[
            SizedBox(height: 8.h),
            Text(
              'Bu stok Ürün Gönder akışı ile depoya geri yollanabilir.',
              style: AppTextStyles.caption.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _safeProgress(double current, double max) {
    if (max <= 0) return 0;
    return (current / max).clamp(0.0, 1.0);
  }

  String _estimateProductionPerHour(
    FactoryDetailModel detail,
    BuildingBoostModel? activeBoost,
  ) {
    final product = detail.product;
    if (product == null) return '-';
    final qualityMultiplier = 1.0 + (detail.factory.qualityLevel - 1) * 0.20;
    final amount =
        product.uretimAdedi *
        (activeBoost?.multiplier ?? 1) *
        qualityMultiplier;
    return amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(1);
  }

  Widget _buildQualityStars(int qualityLevel) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < qualityLevel;
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

  Color _inputColorForProduct(String productId) {
    final palette = <Color>[
      AppColors.blue,
      AppColors.green,
      AppColors.red,
      AppColors.goldDark,
      AppColors.gold,
      AppColors.info,
    ];
    final hash = productId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[hash % palette.length];
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

  Future<void> _showFactoryBoostSheet(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
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
              'Fabrika Boostu',
              style: AppTextStyles.h2.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.headline,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              activeBoost != null
                  ? 'Bu fabrikada zaten aktif bir boost var. Süre dolana kadar üretim x${activeBoost.multiplier.toStringAsFixed(1)} hızla çalışır.'
                  : 'Boost başladığında fabrikanın üretim hızı süre boyunca 2 katına çıkar.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.body,
                height: 1.45,
              ),
            ),
            SizedBox(height: 16.h),
            if (activeBoost == null)
              ..._factoryBoostStarCosts.entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final result = await ref
                          .read(factoryActionProvider)
                          .startFactoryBoost(
                            factoryId: detail.factory.id,
                            durationHours: entry.key,
                            starCost: entry.value,
                            syncProviders: false,
                          );
                      if (!context.mounted) return;
                      if (result['success'] == true) {
                        ref
                            .read(activeFactoryBoostProvider(widget.factoryId).notifier)
                            .setBoost(BuildingBoostModel.fromJson(result));
                        if (!context.mounted) return;
                        AppSnackbar.show(
                          context,
                          title: 'Başarılı',
                          message: 'Fabrika boostu başlatıldı.',
                          type: SnackbarType.success,
                        );
                      } else {
                        AppSnackbar.show(
                          context,
                          title: 'Hata',
                          message:
                              result['message'] ??
                              'Fabrika boostu başlatılamadı.',
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
                                    fontSize: AppTypography.bodyLarge,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Katsayi x2.0',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                AppIcons.starRounded,
                                color: AppColors.gold,
                                size: AppIconSizes.compact,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${entry.value}',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: AppTypography.bodyLarge,
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

  Future<void> _showFactoryUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    BuildingUpgradeModel? activeUpgrade,
  ) async {
    if (activeUpgrade != null) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Oyun genelinde devam eden bir yukseltme var.',
        type: SnackbarType.info,
      );
      return;
    }
    final quote = await ref.read(
      buildingUpgradeQuoteProvider((
        buildingKind: 'factory',
        entityId: detail.factory.id,
      )).future,
    );
    if (!context.mounted) return;
    if (quote.isMaximumLevel) {
      AppSnackbar.show(
        context,
        title: 'Maksimum Seviye',
        message: 'Bu fabrika maksimum seviye ${quote.maxLevel}.',
        type: SnackbarType.info,
      );
      return;
    }
    final nextLevel = quote.targetLevel!;
    final nextInputCapacity =
        quote.effect('input_capacity')?.nextValue.toInt() ??
        detail.factory.inputCapacity;
    final nextOutputCapacity =
        quote.effect('output_capacity')?.nextValue.toInt() ??
        detail.factory.outputCapacity;
    final durationMinutes = quote.durationMinutes;
    final upgradeCost = quote.cashCost;

    await showBuildingUpgradeSheet(
      context: context,
      title: 'Fabrika Yükseltmesi',
      buildingName: detail.factory.name,
      icon: AppIcons.factory,
      currentLevel: detail.factory.level,
      targetLevel: nextLevel,
      durationLabel: '$durationMinutes dk',
      costLabel: AppMoney.compact(upgradeCost),
      requirementLabel: quote.requirementLabel,
      benefits: [
        BuildingUpgradeBenefit(
          icon: AppIcons.inventory2Outlined,
          label: 'Hammadde kapasitesi',
          before: '${detail.factory.inputCapacity}',
          after: '$nextInputCapacity',
        ),
        BuildingUpgradeBenefit(
          icon: AppIcons.inventory2Rounded,
          label: 'Uretim kapasitesi',
          before: '${detail.factory.outputCapacity}',
          after: '$nextOutputCapacity',
        ),
      ],
      canConfirm: quote.canUpgrade,
      onConfirm: () async {
        final result = await ref
            .read(factoryActionProvider)
            .startFactoryUpgrade(detail.factory.id, syncProviders: false);
        if (!context.mounted) return;
        if (result['success'] == true) {
          ref
              .read(activeFactoryUpgradeProvider(widget.factoryId).notifier)
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
            message: 'Fabrika yükseltmesi başlatıldı.',
            type: SnackbarType.success,
          );
        } else {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message:
                result['message'] ?? 'Fabrika yükseltmesi başlatılamadı.',
            type: SnackbarType.error,
          );
        }
      },
    );
  }

  Future<void> _finishFactoryUpgradeWithGold(
    BuildingUpgradeModel upgrade,
  ) async {
    final result = await ref
        .read(factoryActionProvider)
        .finishFactoryUpgradeWithGold(upgrade.id, syncProviders: false);

    if (!mounted) return;

    if (result['success'] == true) {
      final newLevel = (result['target_level'] as num?)?.toInt() ??
          (result['new_level'] as num?)?.toInt() ??
          upgrade.targetLevel;
      ref.read(activeFactoryUpgradeProvider(widget.factoryId).notifier).clear();
      ref
          .read(factoryDetailProvider(widget.factoryId).notifier)
          .patchFactoryLevel(newLevel);
      ref
          .read(factoryListProvider.notifier)
          .patchFactoryLevel(factoryId: widget.factoryId, level: newLevel);

      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'Fabrika yükseltmesi tamamlandı.',
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

  Future<void> _reduceFactoryUpgradeTimeWithAd(
    BuildingUpgradeModel upgrade,
  ) async {
    final success = await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'upgrade_time_reduce',
      resourceId: upgrade.id,
      onApplyReduction: () => ref
          .read(factoryActionProvider)
          .reduceFactoryUpgradeTimeWithAd(upgrade.id, syncProviders: false),
      successMessage: 'Fabrika yükseltme süresi 10 dakika kısaltıldı.',
    );

    if (success) {
      ref
          .read(activeFactoryUpgradeProvider(widget.factoryId).notifier)
          .reduceTime(const Duration(minutes: 10));
    }
  }

  Future<void> _showProductDialog(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) async {
    List<SelectableProductionProductModel> products;
    try {
      products = await ref
          .read(factoryActionProvider)
          .getSelectableProducts(typeId: detail.factoryType.id);
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

    final activeProducts = ref.read(playerActiveProductsProvider).value ?? [];
    final sellingProductIds = activeProducts
        .where((p) => p.role == 'sale')
        .map((p) => p.productId)
        .toSet();

    final options = products.map((selectableProduct) {
      final product = selectableProduct.product;
      final isSelling = sellingProductIds.contains(product.id);
      return ProductSelectionOption(
        id: product.id,
        title:
            product.urunAdi +
            (selectableProduct.hasPreferredBrand
                ? ' (${_currentBrandName ?? 'Markalı'})'
                : ''),
        subtitle:
            'Saatlik uretim: ${(product.uretimAdedi * (1.0 + (detail.factory.qualityLevel - 1) * 0.20)).toInt()}',
        badgeText:
            'Maks Kalite: ${selectableProduct.maxQualityLevel}'
            '${selectableProduct.hasPreferredBrand ? ' Ã¢â‚¬Â¢ Marka Hazir' : ''}',
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
        onTap: () async {
          Navigator.pop(context);
          await _selectFactoryProduct(context, ref, detail, selectableProduct);
        },
      );
    }).toList();

    if (!context.mounted) return;
    await ProductSelectionSheet.show(
      context: context,
      title: 'ÃƒÅ“rÃƒÂ¼n SeÃƒÂ§',
      options: options,
    );
  }

  Future<void> _selectFactoryProduct(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
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

    final result = await ref
        .read(factoryActionProvider)
        .setFactoryProduct(
          factoryId: detail.factory.id,
          productId: product.id,
          qualityLevel: qualityLevel,
          syncProviders: true,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      final deletedObsoleteCount =
          (result['deleted_obsolete_inventory_count'] as num?)?.toInt() ?? 0;
      final cleanupNote = deletedObsoleteCount > 0
          ? ' Eski boş kayıtlardan $deletedObsoleteCount adet temizlendi.'
          : '';
      final isBranded = selectableProduct.hasPreferredBrand;
      final productName =
          product.urunAdi +
          (isBranded ? ' (${_currentBrandName ?? 'Markalı'})' : '');
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message:
            '$productName otomatik kalite $qualityLevel ile ayarlandi.$cleanupNote',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Ürün seçilemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _toggleFactoryActive(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) async {
    final nextActive = !detail.factory.isActive;
    final result = await ref
        .read(factoryActionProvider)
        .setFactoryActive(
          factoryId: detail.factory.id,
          isActive: nextActive,
          syncProviders: true,
        );

    if (!context.mounted) return;
    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: detail.factory.isActive
            ? 'Fabrika pasif moda alındı.'
            : 'Fabrika aktif edildi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Fabrika durumu güncellenemedi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _startFactoryReceiveFlow(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) async {
    final targetInventories = detail.inputInventories
        .where((inventory) => inventory.product != null)
        .toList();
    if (targetInventories.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Bilgi',
        message: 'Bu fabrikada aktif hammadde girdisi bulunamadı.',
        type: SnackbarType.info,
      );
      return;
    }

    final remainingInputCapacity = _calculateRemainingFactoryInputCapacity(
      detail.inputInventories,
      detail.factory.inputCapacity,
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
          .read(factoryActionProvider)
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

    final targetByKey = <String, FactoryProductionInventoryModel>{
      for (final inventory in targetInventories)
        _factoryInventoryKey(inventory.productId, inventory.qualityLevel):
            inventory,
    };
    final warehouseChoices = <_FactoryInboundWarehouseChoice>[];

    for (final warehouse in warehouses) {
      final slots = (warehouse['warehouse_slots'] as List<dynamic>? ?? const [])
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();
      final eligibleSlots = <_FactoryInboundWarehouseSlotOption>[];
      for (final slot in slots) {
        final quantity = (slot['quantity'] as num?)?.toInt() ?? 0;
        if (quantity <= 0) continue;
        final key = _factoryInventoryKey(
          slot['product_id']?.toString() ?? '',
          (slot['quality_level'] as num?)?.toInt() ?? 0,
        );
        final targetInventory = targetByKey[key];
        if (targetInventory == null) continue;
        eligibleSlots.add(
          _FactoryInboundWarehouseSlotOption(
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
      final double capacityRatio = totalCapacity > 0 ? (reservedCapacity / totalCapacity) : 0.0;
      final capacityLabel = '${reservedCapacity.toStringAsFixed(0)}/${totalCapacity.toStringAsFixed(0)} m³';

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
        _FactoryInboundWarehouseChoice(
          warehouseId: warehouseId,
          warehouseName: name,
          cityId: cityId,
          cityName: cityName,
          isSameCity: _isSameCity(cityId, detail.factory.cityId),
          slots: eligibleSlots,
          capacityRatio: capacityRatio,
          capacityLabel: capacityLabel,
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
            'Bu fabrikanın kullandığı hammaddeler için uygun depo stoğu bulunamadı.',
        type: SnackbarType.info,
      );
      return;
    }

    final options =
        warehouseChoices
            .map(
              (warehouse) => WarehouseSelectionOption(
                id: warehouse.warehouseId,
                title: warehouse.warehouseName,
                subtitle: warehouse.cityName,
                cityName: warehouse.cityName,
                isStoreWarehouse: warehouse.warehouseName.toLowerCase().contains('mağaza') ||
                    warehouse.warehouseName.toLowerCase().contains('magaza') ||
                    warehouse.warehouseName.toLowerCase().contains('bakkal') ||
                    warehouse.warehouseName.toLowerCase().contains('market'),
                badgeText: warehouse.isSameCity ? 'Aynı Şehir' : 'Lojistik',
                infoText:
                    '✓ ${warehouse.slots.length} uygun hammadde mevcut',
                isHighlightBadge: warehouse.isSameCity,
                capacityRatio: warehouse.capacityRatio,
                capacityLabel: warehouse.capacityLabel,
                productPreviews: warehouse.productPreviews,
                onTap: () {
                  Navigator.pop(context);
                  _showFactoryInboundSelectionSheet(
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

  Future<void> _startFactorySendFlow(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) async {
    final sendableInventories = [
      ...detail.inputInventories.where((inventory) => inventory.quantity > 0),
      ...detail.orphanInputInventories.where(
        (inventory) => inventory.quantity > 0,
      ),
      ...detail.outputInventories.where((inventory) => inventory.quantity > 0),
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
      warehouses = await ref
          .read(factoryActionProvider)
          .getPlayerWarehousesRaw();
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
      final acceptedProductIds = _parseFactoryAcceptedProductIds(
        (warehouse['warehouse_type'] as Map?)?['accepted_product_ids'],
      );
      final eligibleInventories = sendableInventories
          .where(
            (inventory) => acceptedProductIds.contains(inventory.productId),
          )
          .toList();
      if (eligibleInventories.isEmpty) continue;

      final warehouseOption = ProductionLogisticsWarehouseOption.fromJson(
        warehouse,
        productionCityId: detail.factory.cityId,
      );

      final totalCapacity = (warehouse['capacity'] as num?)?.toDouble() ?? 0.0;
      final reservedCapacity = (warehouse['reserved_capacity'] as num?)?.toDouble() ?? 0.0;
      final double capacityRatio = totalCapacity > 0 ? (reservedCapacity / totalCapacity) : 0.0;
      final double freeCapacity = (totalCapacity - reservedCapacity).clamp(0.0, totalCapacity);
      final capacityLabel = '${reservedCapacity.toStringAsFixed(0)}/${totalCapacity.toStringAsFixed(0)} m³';
      final freeCapacityLabel = '🟢 ${freeCapacity.toStringAsFixed(0)} m³ Boş Alan';

      final previews = warehouseOption.slots.map((s) {
        return WarehouseSelectionProductPreview(
          icon: s.productIcon ?? '',
          quantity: s.quantity.toDouble(),
          quality: s.qualityLevel,
        );
      }).where((p) => p.quantity > 0 && p.icon.isNotEmpty).toList();

      options.add(
        WarehouseSelectionOption(
          id: warehouseOption.id,
          title: warehouseOption.name,
          subtitle: warehouseOption.cityName,
          cityName: warehouseOption.cityName,
          isStoreWarehouse: warehouseOption.isStoreWarehouse,
          badgeText: warehouseOption.isSameCity
              ? 'Aynı Şehir'
              : 'Lojistik',
          infoText: '✓ ${eligibleInventories.length} gönderilebilir ürün uygun',
          isHighlightBadge: warehouseOption.isSameCity,
          capacityRatio: capacityRatio,
          capacityLabel: capacityLabel,
          freeCapacityLabel: freeCapacityLabel,
          productPreviews: previews,
          onTap: () async {
            Navigator.pop(context);
            WarehouseCapacityStatusModel? capacityStatus;
            try {
              capacityStatus = await ref.read(
                warehouseCapacityStatusProvider(warehouseOption.id).future,
              );
            } catch (_) {
              capacityStatus = null;
            }
            if (!context.mounted) return;
            _showFactoryOutboundSelectionSheet(
              context: context,
              ref: ref,
              detail: detail,
              targetWarehouse: warehouseOption,
              targetCapacityStatus: capacityStatus,
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

  Future<void> _showFactoryInboundSelectionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required _FactoryInboundWarehouseChoice warehouse,
    required int remainingInputCapacity,
  }) async {
    final selectedQuantities = <String, int>{};

    int maxSelectableForSlot(_FactoryInboundWarehouseSlotOption slot) {
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
      _FactoryInboundWarehouseSlotOption slot,
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
                            style: AppTextStyles.button.standardCopyWith(
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
                              style: AppTextStyles.button.standardCopyWith(
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
                (slot) => _SelectedFactoryInboundTransferItem(
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
              (detail.factory.inputCapacity - remainingInputCapacity)
                  .clamp(0, detail.factory.inputCapacity)
                  .toDouble();
          final projectedInputCapacity =
              currentUsedInputCapacity + totalQuantity.toDouble();
          final currentInputRatio = detail.factory.inputCapacity <= 0
              ? 0.0
              : (currentUsedInputCapacity / detail.factory.inputCapacity).clamp(
                  0.0,
                  1.0,
                );
          final projectedInputRatio = detail.factory.inputCapacity <= 0
              ? 0.0
              : (projectedInputCapacity / detail.factory.inputCapacity).clamp(
                  0.0,
                  1.0,
                );
          final projectedInputColor = projectedInputRatio >= 0.9
              ? AppColors.red
              : projectedInputRatio >= 0.75
              ? AppColors.gold
              : AppColors.green;

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
                                        AppIcons.precisionManufacturingRounded,
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
                                            detail.factory.name,
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
                                            'Hedef Fabrika',
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
                                'Fabrika Boş: $remainingInputCapacity / ${detail.factory.inputCapacity} adet',
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
                                color: projectedInputColor,
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
                                            color: projectedInputColor
                                                .withValues(alpha: 0.75),
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
                                  isSelected
                                      ? 'Adet: $selectedQuantity'
                                      : 'Ekle',
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
                              await _submitFactoryInboundSelection(
                                context: context,
                                ref: ref,
                                detail: detail,
                                warehouse: warehouse,
                                items: selectedItems,
                              );
                            },
                      icon: const Icon(AppIcons.downloadRounded),
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

  Future<void> _submitFactoryInboundSelection({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required _FactoryInboundWarehouseChoice warehouse,
    required List<_SelectedFactoryInboundTransferItem> items,
  }) async {
    if (warehouse.isSameCity) {
      final result = await ref
          .read(factoryActionProvider)
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
            syncProviders: false,
          );
      if (!context.mounted) return;
      if (result.success) {
        await _refreshFactoryEcosystem(
          includeWarehouseList: true,
          includePlayer: false,
        );
        if (!context.mounted) return;
        AppSnackbar.show(
          context,
          title: 'Başarılı',
          message: 'Seçilen hammaddeler fabrikaya aktarıldı.',
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
      return;
    }

    await _startFactoryGroupedLogisticsInputTransfer(
      context: context,
      ref: ref,
      detail: detail,
      warehouse: warehouse,
      items: items,
    );
  }

  Future<void> _startFactoryGroupedLogisticsInputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required _FactoryInboundWarehouseChoice warehouse,
    required List<_SelectedFactoryInboundTransferItem> items,
  }) async {
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    final totalVolume = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.slot.unitVolume),
    );
    try {
      vehicleResult = await ref
          .read(factoryActionProvider)
          .getProductionRouteVehicleOptions(
            sourceCityId: warehouse.cityId,
            targetCityId: detail.factory.cityId,
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
            'Bu transfer için uygun araç bulunamadı.',
        type: SnackbarType.info,
      );
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: 'Hammadde Lojistiği',
      options: vehicleResult.options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(factoryActionProvider)
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
          await _refreshFactoryEcosystem(
            includeTransfers: true,
            includeWarehouseList: true,
            includePlayer: false,
          );
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: 'Seçilen hammaddeler için araç yola çıktı.',
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

  Future<void> _showFactoryOutboundSelectionSheet({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required ProductionLogisticsWarehouseOption targetWarehouse,
    WarehouseCapacityStatusModel? targetCapacityStatus,
    required List<FactoryProductionInventoryModel> inventories,
  }) async {
    final selectedQuantities = <String, int>{};
    final sortedInventories = [...inventories]
      ..sort((a, b) {
        if (a.isInput != b.isInput) {
          return a.isInput ? -1 : 1;
        }
        return (a.product?.urunAdi ?? a.productId).compareTo(
          b.product?.urunAdi ?? b.productId,
        );
      });

    Future<void> openQuantityEditor(
      BuildContext sheetContext,
      StateSetter modalSetState,
      FactoryProductionInventoryModel item,
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
                            ? ' (${_currentBrandName ?? 'Markalı'})'
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
                            style: AppTextStyles.button.standardCopyWith(
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
                              style: AppTextStyles.button.standardCopyWith(
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
                (item) => _SelectedFactoryProductionTransferItem(
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
                    _resolveFactoryInventoryUnitVolume(detail, item.inventory)),
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
          final projectedCapacityColor = projectedCapacityRatio >= 0.9
              ? AppColors.red
              : projectedCapacityRatio >= 0.75
              ? AppColors.gold
              : AppColors.green;

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
                                        AppIcons.precisionManufacturingRounded,
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
                                            detail.factory.name,
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
                                            'Kaynak Fabrika',
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
                                        AppIcons.warehouseRounded,
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
                                  color: projectedCapacityColor,
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
                                              color: projectedCapacityColor
                                                  .withValues(alpha: 0.75),
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
                                title: 'Üretilen Ürünler (Fabrika Mamulleri)',
                                subtitle:
                                    'Fabrikada üretilen ürünleri depoya aktar',
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
                                title: 'Hammaddeler (Fabrika Girdileri)',
                                subtitle:
                                    'Fabrikadaki hammadde ve girdileri depoya geri gönder',
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
                              if (targetWarehouse.isSameCity) {
                                final result = await ref
                                    .read(factoryActionProvider)
                                    .startMultiProductionToWarehouseTransfer(
                                      sourceOwnerKind: 'factory',
                                      sourceOwnerId: widget.factoryId,
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
                                  await _refreshFactoryEcosystem(
                                    warehouseId: targetWarehouse.id,
                                    includeTransfers: true,
                                    includePlayer: false,
                                  );
                                  if (!context.mounted) return;
                                  AppSnackbar.show(
                                    context,
                                    title: 'Başarılı',
                                    message:
                                        'Seçilen stoklar depoya gönderildi.',
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
                                return;
                              }

                              await _startFactoryMultiLogisticsOutputTransfer(
                                context: context,
                                ref: ref,
                                detail: detail,
                                targetWarehouse: targetWarehouse,
                                items: selectedItems,
                              );
                            },
                      icon: const Icon(AppIcons.localShippingRounded),
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

  Future<void> _startFactoryMultiLogisticsOutputTransfer({
    required BuildContext context,
    required WidgetRef ref,
    required FactoryDetailModel detail,
    required ProductionLogisticsWarehouseOption targetWarehouse,
    required List<_SelectedFactoryProductionTransferItem> items,
  }) async {
    TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    final totalVolume = items.fold<double>(
      0,
      (sum, item) =>
          sum +
          (_resolveFactoryInventoryUnitVolume(detail, item.inventory) *
              item.quantity),
    );
    try {
      vehicleResult = await ref
          .read(factoryActionProvider)
          .getProductionRouteVehicleOptions(
            sourceCityId: detail.factory.cityId,
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
            'Bu transfer için uygun araç bulunamadı.',
        type: SnackbarType.info,
      );
      return;
    }

    _showProductionVehicleOptionsSheet(
      context: context,
      title: items.first.inventory.isInput
          ? 'Hammadde Geri Gönderim Lojistiği'
          : 'Ürün Lojistiği',
      options: vehicleResult.options,
      onSelected: (vehicleId) async {
        final result = await ref
            .read(factoryActionProvider)
            .startMultiProductionToWarehouseTransfer(
              sourceOwnerKind: 'factory',
              sourceOwnerId: widget.factoryId,
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
          await _refreshFactoryEcosystem(
            warehouseId: targetWarehouse.id,
            includeTransfers: true,
            includePlayer: false,
          );
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message: items.first.inventory.isInput
                ? 'Hammaddeyi depoya geri götüren araç yola çıktı.'
                : 'Ürünü depoya götüren araç yola çıktı.',
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

  Future<void> _showProductionVehicleOptionsSheet({
    required BuildContext context,
    required String title,
    required List<ProductionLogisticsVehicleOption> options,
    required Future<void> Function(String vehicleId) onSelected,
  }) async {
    final selectedVehicleId = await showTransferVehicleSelectionSheet(
      context: context,
      title: title,
      sourceCityName: 'Fabrika',
      targetCityName: 'Depo',
      options: options.map(TransferVehicleOptionItem.fromProduction).toList(),
    );

    if (selectedVehicleId != null && context.mounted) {
      await onSelected(selectedVehicleId);
    }
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
    required FactoryProductionInventoryModel item,
    required BuildContext sheetContext,
    required StateSetter modalSetState,
    required Map<String, int> selectedQuantities,
    required Future<void> Function(
      BuildContext sheetContext,
      StateSetter modalSetState,
      FactoryProductionInventoryModel item,
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
                          ? ' (${_currentBrandName ?? 'Markalı'})'
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

  int _calculateRemainingFactoryInputCapacity(
    List<FactoryProductionInventoryModel> inventories,
    int capacity,
  ) {
    final usedAndPending = inventories.fold<double>(
      0,
      (sum, inventory) => sum + inventory.quantity + inventory.pendingQuantity,
    );
    return (capacity - usedAndPending.ceil()).clamp(0, capacity);
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

  double _resolveFactoryInventoryUnitVolume(
    FactoryDetailModel detail,
    FactoryProductionInventoryModel inventory,
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

    final detailProduct = detail.product;
    if (detailProduct != null &&
        detailProduct.id == inventory.productId &&
        detailProduct.birimHacim > 0) {
      return detailProduct.birimHacim;
    }

    return 0;
  }

  Future<void> _showSellFactoryDialog(BuildContext context) async {
    final detail = ref.read(factoryDetailProvider(widget.factoryId)).value;
    if (detail == null) return;
    final factory = detail.factory;

    final quote = await ref
        .read(factoryActionProvider)
        .sellFactory(factoryId: factory.id, confirm: false);

    if (!context.mounted) return;

    if (quote['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: quote['message'] ?? 'Satis teklifi hazirlanamadi.',
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
          'Fabrikayı Sat',
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
              '${factory.name} kalici olarak silinecek. Bu islem geri alinamaz.',
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
              'Fabrikayı Sat',
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
        .read(factoryActionProvider)
        .sellFactory(factoryId: factory.id, confirm: true);

    if (!context.mounted) return;

    if (result['success'] == true) {
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'Fabrika satıldı. ${totalRefund.toStringAsFixed(1)} TL iade edildi.',
        type: SnackbarType.success,
      );
      context.go('/factories');
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Fabrika satılamadı.',
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

class _SelectedFactoryProductionTransferItem {
  final FactoryProductionInventoryModel inventory;
  final int quantity;

  const _SelectedFactoryProductionTransferItem({
    required this.inventory,
    required this.quantity,
  });
}

class _FactoryInboundWarehouseChoice {
  final String warehouseId;
  final String warehouseName;
  final String cityId;
  final String cityName;
  final bool isSameCity;
  final List<_FactoryInboundWarehouseSlotOption> slots;
  final double? capacityRatio;
  final String? capacityLabel;
  final List<WarehouseSelectionProductPreview>? productPreviews;

  const _FactoryInboundWarehouseChoice({
    required this.warehouseId,
    required this.warehouseName,
    required this.cityId,
    required this.cityName,
    required this.isSameCity,
    required this.slots,
    this.capacityRatio,
    this.capacityLabel,
    this.productPreviews,
  });
}

class _FactoryInboundWarehouseSlotOption {
  final String warehouseSlotId;
  final String productId;
  final String productName;
  final String? productIcon;
  final int qualityLevel;
  final int availableQuantity;
  final double unitVolume;
  final FactoryProductionInventoryModel targetInventory;

  const _FactoryInboundWarehouseSlotOption({
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

class _SelectedFactoryInboundTransferItem {
  final _FactoryInboundWarehouseSlotOption slot;
  final int quantity;

  const _SelectedFactoryInboundTransferItem({
    required this.slot,
    required this.quantity,
  });
}

String _factoryInventoryKey(String productId, int qualityLevel) {
  return '$productId::$qualityLevel';
}

Set<String> _parseFactoryAcceptedProductIds(dynamic rawValue) {
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

class _ActiveFactoryBoostCard extends ConsumerWidget {
  final BuildingBoostModel boost;

  const _ActiveFactoryBoostCard({required this.boost});

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
                      style: AppTextStyles.title.standardCopyWith(
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
                style: AppTextStyles.label.standardCopyWith(
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

class _ActiveFactoryUpgradeCard extends ConsumerWidget {
  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final Future<void> Function()? onReduceTimeWithAd;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

  const _ActiveFactoryUpgradeCard({
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
                      'Fabrika Yükseltmesi Devam Ediyor',
                      style: AppTextStyles.title.standardCopyWith(
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
                style: AppTextStyles.label.standardCopyWith(
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
                  'Bir reklam ödülü al ve fabrika yükseltme süresini 10 dakika kısalt.',
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
