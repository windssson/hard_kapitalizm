import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/rewarded_time_reduce_button.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_model.dart';
import 'package:hard_kapitalizm/features/company/models/brand_company_product_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';

class WarehouseDetailScreen extends ConsumerStatefulWidget {
  final String warehouseId;

  const WarehouseDetailScreen({super.key, required this.warehouseId});

  @override
  ConsumerState<WarehouseDetailScreen> createState() =>
      _WarehouseDetailScreenState();
}

class _WarehouseDetailScreenState extends ConsumerState<WarehouseDetailScreen> {
  static const String _defaultBrandId = '00000000-0000-0000-0000-000000000000';

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(playerBrandCompanyProvider);
    final company = companyAsync.value;
    final companyProductsAsync = ref.watch(playerBrandCompanyProductsProvider);
    final companyProducts = companyProductsAsync.value;
    final currentBrandName = company?.brandName;
    final warehouseAsync = ref.watch(
      warehouseDetailProvider(widget.warehouseId),
    );
    final now = ref.watch(secondTickerProvider).value ?? DateTime.now();
    final activeUpgradeAsync = ref.watch(
      activeWarehouseUpgradeProvider(widget.warehouseId),
    );
    final anyActiveUpgradeAsync = ref.watch(anyActiveWarehouseUpgradeProvider);
    final activeUpgrade =
        activeUpgradeAsync.isLoading || activeUpgradeAsync.isRefreshing
        ? null
        : activeUpgradeAsync.maybeWhen(
            data: (value) => value,
            orElse: () => null,
          );
    final anyActiveUpgrade =
        anyActiveUpgradeAsync.isLoading || anyActiveUpgradeAsync.isRefreshing
        ? null
        : anyActiveUpgradeAsync.maybeWhen(
            data: (value) => value,
            orElse: () => null,
          );
    final visibleActiveUpgrade =
        activeUpgrade != null &&
            activeUpgrade.isInProgress &&
            activeUpgrade.finishAt.isAfter(now)
        ? activeUpgrade
        : null;
    final hasAnotherActiveUpgrade =
        anyActiveUpgrade != null &&
        (anyActiveUpgrade.buildingKind != 'warehouse' ||
            anyActiveUpgrade.entityId != widget.warehouseId);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: -1,
        onItemSelected: (_) {},
      ),
      floatingActionButton: warehouseAsync.maybeWhen(
        data: (warehouse) => FloatingActionButton.extended(
          onPressed: () => _showProductSelection(context, warehouse),
          backgroundColor: AppColors.gold,
          icon: Icon(AppIcons.addShoppingCart, color: AppColors.textOnAccent),
          label: Text(
            'Ürün Ekle',
            style: AppTextStyles.button.standardCopyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: warehouseAsync.when(
          data: (warehouse) => Column(
            children: [
              SecondaryTopBar(
                title: '${warehouse.cityName ?? ''} • ${warehouse.name}',
                actions: [
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 40),
                    color: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      side: BorderSide(
                        color: AppColors.borderGold.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'sell') {
                        _showSellWarehouseDialog(context, ref, warehouse);
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
                                    'Depoyu Sat',
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
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.7,
                              ),
                              size: AppIconSizes.medium,
                            ),
                          ),
                        ),
                      ],
              ),
              _buildWarehouseSwitcher(context, ref, warehouse),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _refreshWarehouse(ref),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 96.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(
                          warehouse,
                          visibleActiveUpgrade,
                          hasAnotherActiveUpgrade,
                          currentBrandName,
                        ),
                        if (visibleActiveUpgrade != null) ...[
                          SizedBox(height: 12.h),
                          _ActiveWarehouseUpgradeCard(
                            upgrade: visibleActiveUpgrade,
                            calculateStarCost: _calculateUpgradeStarCost,
                            formatCountdown: _formatCountdown,
                            onFinishWithGold: () =>
                                _finishWarehouseUpgradeWithGold(
                                  visibleActiveUpgrade,
                                ),
                            onReduceTimeWithAd: () =>
                                _reduceWarehouseUpgradeTimeWithAd(
                                  visibleActiveUpgrade,
                                ),
                          ),
                        ],
                        SizedBox(height: 18.h),
                        _buildSlotList(
                          context,
                          ref,
                          warehouse,
                          company,
                          companyProducts,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () =>
              Center(child: AppLoadingIndicator(color: AppColors.gold)),
          error: (error, stack) => _buildErrorState(error),
        ),
      ),
    );
  }

  Widget _buildWarehouseSwitcher(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel currentWarehouse,
  ) {
    final listAsync = ref.watch(warehouseListProvider);
    return listAsync.maybeWhen(
      data: (list) {
        final warehouses = list.where((w) => w.isActive).toList();
        if (warehouses.length <= 1) return const SizedBox.shrink();

        return Container(
          margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.borderGold.withValues(alpha: 0.25),
              width: 1.w,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentWarehouse.id,
              isExpanded: true,
              dropdownColor: AppColors.cardBg,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.gold,
              ),
              items: warehouses.map((w) {
                final displayCity = w.cityName ?? 'Bilinmeyen Şehir';
                return DropdownMenuItem<String>(
                  value: w.id,
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.inventory,
                        color: AppColors.gold,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          '$displayCity • ${w.name}',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newId) {
                if (newId != null && newId != currentWarehouse.id) {
                  context.pushReplacement('/warehouses/$newId');
                }
              },
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Future<void> _refreshWarehouse(WidgetRef ref) async {
    await ref.read(warehouseActionProvider).completeDueWarehouseUpgrades();
    final warehouse = await ref
        .read(warehouseDetailProvider(widget.warehouseId).notifier)
        .refresh();
    ref.read(warehouseListProvider.notifier).replaceWarehouse(warehouse);
    ref.invalidate(activeWarehouseUpgradeProvider(widget.warehouseId));
    ref.invalidate(anyActiveWarehouseUpgradeProvider);
  }

  void _showProductSelection(
    BuildContext context,
    WarehouseModel warehouse,
  ) async {
    try {
      final allProducts = await ref.read(allProductsProvider.future);
      final warehouseTypes = await ref.read(warehouseTypesProvider.future);
      final typeDetail = _findWarehouseTypeDetail(
        warehouse.warehouseTypeId,
        warehouseTypes,
      );

      final acceptedIds = _parseAcceptedProductIds(
        typeDetail['accepted_product_ids'],
      );

      final filteredProducts = allProducts.where((p) {
        if (acceptedIds.isEmpty) return true;
        return acceptedIds.contains(p.id.trim().toUpperCase());
      }).toList();

      final options = filteredProducts.map((product) {
        return ProductSelectionOption(
          id: product.id,
          title: product.urunAdi,
          subtitle: 'Birim Hacim: ${product.birimHacim} m3',
          iconPath: product.urunIconu,
          trailingWidget: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(
                Uri(
                  path: '/market/${product.id}',
                  queryParameters: {
                    'warehouseId': warehouse.id,
                    'playerId': warehouse.playerId,
                    'cityId': warehouse.cityId,
                  },
                ).toString(),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.gold.withValues(alpha: 0.6),
                width: 1.w,
              ),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'Pazar',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.gold,
                fontSize: AppTypography.bodySmall,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            context.push(
              Uri(
                path: '/market/${product.id}',
                queryParameters: {
                  'warehouseId': warehouse.id,
                  'playerId': warehouse.playerId,
                  'cityId': warehouse.cityId,
                },
              ).toString(),
            );
          },
        );
      }).toList();

      if (!context.mounted) return;
      await ProductSelectionSheet.show(
        context: context,
        title: 'Deponun Alabildiği Ürünler',
        options: options,
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: 'Ürün listesi yüklenemedi: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  List<String> _parseAcceptedProductIds(dynamic rawValue) {
    if (rawValue == null) return const [];

    final cleaned = rawValue
        .toString()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('"', '')
        .replaceAll("'", '');

    return cleaned
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _findWarehouseTypeDetail(
    String warehouseTypeId,
    List<dynamic> warehouseTypes,
  ) {
    for (final item in warehouseTypes) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['id']?.toString() == warehouseTypeId) {
        return map;
      }
    }
    return const {};
  }

  void _openMarketForSlot(
    BuildContext context,
    WarehouseModel warehouse,
    WarehouseSlotModel slot,
  ) {
    final productId = slot.productId;
    if (productId == null || productId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Ürün Yok',
        message: 'Bu slot için pazar açılamadı.',
        type: SnackbarType.warning,
      );
      return;
    }

    context.push(
      Uri(
        path: '/market/$productId',
        queryParameters: {
          'warehouseId': warehouse.id,
          'playerId': warehouse.playerId,
          'cityId': warehouse.cityId,
        },
      ).toString(),
    );
  }

  Widget _buildHeaderCard(
    WarehouseModel warehouse,
    BuildingUpgradeModel? activeUpgrade,
    bool hasAnotherActiveUpgrade,
    String? currentBrandName,
  ) {
    final filledSlots = warehouse.slots.where((slot) => !slot.isEmpty).toList();
    final usedCapacity = filledSlots.fold<double>(
      0,
      (sum, slot) => sum + (slot.quantity * slot.unitVolume),
    );
    final reserved = warehouse.reservedCapacity;
    final capacity = warehouse.capacity;
    final availableCapacity = (capacity - usedCapacity - reserved).clamp(
      0.0,
      capacity,
    );
    final stockRatio = capacity > 0
        ? (usedCapacity / capacity).clamp(0.0, 1.0)
        : 0.0;
    final reserveRatio = capacity > 0
        ? (reserved / capacity).clamp(0.0, 1.0)
        : 0.0;

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
                    padding: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
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
                      fileName: warehouse.typeIcon ?? 'warehouse.webp',
                      fit: BoxFit.cover,
                      errorWidget: Icon(
                        AppIcons.warehouseOutlined,
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
                                warehouse.name,
                                style: AppTextStyles.h1.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTypography.headline,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Depo / Lojistik',
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
                                      warehouse.cityName ?? '-',
                                      style: AppTextStyles.body
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
                          child: _buildHeroChipColumn(warehouse),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12.h),
          _buildCapacityBreakdown(
            totalCapacity: capacity,
            usedCapacity: usedCapacity,
            reservedCapacity: reserved,
            availableCapacity: availableCapacity,
            stockRatio: stockRatio,
            reserveRatio: reserveRatio,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildMinimalActionButton(
                  onPressed: activeUpgrade != null || hasAnotherActiveUpgrade
                      ? null
                      : () =>
                            _showWarehouseUpgradeSheet(context, ref, warehouse),
                  icon: AppIcons.upgradeRounded,
                  label: activeUpgrade != null
                      ? 'Devam Ediyor'
                      : hasAnotherActiveUpgrade
                      ? 'Başka Yükseltme Var'
                      : 'Yükselt',
                  color: activeUpgrade != null || hasAnotherActiveUpgrade
                      ? AppColors.textMuted
                      : AppColors.green,
                  isEnabled: activeUpgrade == null && !hasAnotherActiveUpgrade,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildMinimalActionButton(
                  onPressed: () =>
                      context.push('/warehouses/${warehouse.id}/history'),
                  icon: AppIcons.historyRounded,
                  label: 'Kayitlar',
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isEnabled = true,
  }) {
    final accent = isEnabled ? color : AppColors.textMuted;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: accent,
        backgroundColor: accent.withValues(alpha: 0.08),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11.r),
          side: BorderSide(color: accent.withValues(alpha: 0.18)),
        ),
        textStyle: AppTextStyles.label.standardCopyWith(
          fontSize: AppTypography.bodySmall,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: Icon(icon, size: AppIconSizes.compact),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildCapacityBreakdown({
    required double totalCapacity,
    required double usedCapacity,
    required double reservedCapacity,
    required double availableCapacity,
    required double stockRatio,
    required double reserveRatio,
  }) {
    final availableRatio = totalCapacity > 0
        ? (availableCapacity / totalCapacity).clamp(0.0, 1.0)
        : 0.0;
    String formatVolume(double value) => '${_formatValue(value)} m3';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.16),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.straighten,
                color: AppColors.gold,
                size: AppIconSizes.small,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Kapasite Dağılımı',
                  style: AppTextStyles.label.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.bodySmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${formatVolume(usedCapacity + reservedCapacity)}/${formatVolume(totalCapacity)}',
                style: AppTextStyles.caption.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.label,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            height: 10.h,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppFx.softOverlay(0.15),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Row(
              children: [
                if (stockRatio > 0)
                  Flexible(
                    flex: (stockRatio * 1000).round().clamp(1, 1000),
                    child: Container(color: AppColors.blue),
                  ),
                if (reserveRatio > 0)
                  Flexible(
                    flex: (reserveRatio * 1000).round().clamp(1, 1000),
                    child: Container(color: AppColors.gold),
                  ),
                if (availableRatio > 0)
                  Flexible(
                    flex: (availableRatio * 1000).round().clamp(1, 1000),
                    child: Container(
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 6.h,
            children: [
              _buildCapacityLegend(
                'Mevcut Stok',
                formatVolume(usedCapacity),
                AppColors.blue,
                icon: AppIcons.inventory2Outlined,
              ),
              if (reservedCapacity > 0)
                _buildCapacityLegend(
                  'Sevkiyatta',
                  formatVolume(reservedCapacity),
                  AppColors.gold,
                  icon: AppIcons.localShippingOutlined,
                ),
              _buildCapacityLegend(
                'Boş Alan',
                formatVolume(availableCapacity),
                AppColors.textMuted,
                icon: Icons.storage_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityLegend(
    String label,
    String value,
    Color color, {
    IconData? icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.sp, color: color),
            SizedBox(width: 4.w),
          ] else ...[
            Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: 4.w),
          ],
          Text(
            '$label: $value',
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: AppTypography.micro,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChipColumn(WarehouseModel warehouse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildTag('Lv ${warehouse.level}', AppColors.gold),
        SizedBox(height: 6.h),
        _buildTag(
          warehouse.isActive ? 'AKTIF' : 'PASIF',
          warehouse.isActive ? AppColors.green : AppColors.red,
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
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

  List<WarehouseSlotModel> _sortedSlots(List<WarehouseSlotModel> slots) {
    final items = [...slots];
    items.sort((a, b) {
      if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
      return b.quantity.compareTo(a.quantity);
    });
    return items;
  }

  Widget _buildSlotList(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel warehouse,
    BrandCompanyModel? company,
    List<BrandCompanyProductModel>? companyProducts,
  ) {
    final sortedSlots = _sortedSlots(warehouse.slots);

    if (sortedSlots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: AppDecorations.premiumCard(AppColors.border, 18.r),
        child: Column(
          children: [
            Icon(
              AppIcons.inventory2Outlined,
              color: AppColors.textMuted,
              size: AppIconSizes.displayLarge,
            ),
            SizedBox(height: 12.h),
            Text('Bu depoda henüz ürün yok.', style: AppTextStyles.body),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedSlots.length,
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final slot = sortedSlots[index];
        return _buildSlotCard(
          context,
          ref,
          warehouse,
          slot,
          company,
          companyProducts,
        );
      },
    );
  }

  Widget _buildMetaChip({required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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

  PopupMenuItem<String> _buildSlotMenuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: AppIconSizes.regular),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.standardCopyWith(
                color: color,
                fontSize: AppTypography.bodyLarge,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool filled,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: AppIconSizes.small),
        SizedBox(width: 6.w),
        Text(
          label,
          style: AppTextStyles.label.standardCopyWith(
            fontSize: AppTypography.bodySmall,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.textOnAccent,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      child: child,
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel warehouse,
    WarehouseSlotModel slot,
    BrandCompanyModel? company,
    List<BrandCompanyProductModel>? companyProducts,
  ) {
    final currentBrandName = company?.brandName;
    final hasBrand = slot.brandId != _defaultBrandId;
    if (slot.isEmpty) {
      return Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppFx.softOverlay(0.03),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 66.w,
              height: 66.w,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: AppFx.panelWash(0.3),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppFx.softOverlay(0.10)),
              ),
              child: Icon(
                AppIcons.addCircleOutline,
                color: AppColors.textMuted,
                size: 32.w,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Boş Slot',
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.titleLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Bu slot şu an boş. Ürün ekleyebilirsiniz.',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.bodySmall,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            SizedBox(
              width: 100.w,
              child: _buildQuickActionButton(
                label: 'Ürün Ekle',
                icon: AppIcons.addShoppingCartOutlined,
                onPressed: () => _showProductSelection(context, warehouse),
                filled: true,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(null, 18.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.24),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    width: 1.2.w,
                  ),
                ),
                child: BrandedProductImage(
                  fileName: slot.productIcon ?? 'default.webp',
                  brandId: slot.brandId,
                  brandName: _brandNameForSlot(slot, currentBrandName),
                  productId: slot.productId,
                  fit: BoxFit.cover,
                  showFrame: false,
                  company: company,
                  companyProducts: companyProducts,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.productName ?? 'Ürün',
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.titleLarge,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        _buildQualityStars(slot.qualityLevel),
                        SizedBox(width: 6.w),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 4.w,
                      runSpacing: 4.h,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5.r),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: 0.25),
                              width: 1.w,
                            ),
                          ),
                          child: Text(
                            '${slot.unitVolume > 0 ? slot.unitVolume.toStringAsFixed(1) : "1.0"} m³/ad.',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.blue,
                              fontSize: AppTypography.micro,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (hasBrand)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 1.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5.r),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                width: 1.w,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 9.sp,
                                  color: AppColors.gold,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  currentBrandName ?? 'Markali',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.gold,
                                    fontSize: AppTypography.micro,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // HERO STOK GÖSTERGESİ
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blue.withValues(alpha: 0.15),
                      AppColors.cardBgLight.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: slot.quantity > 0
                        ? AppColors.blue.withValues(alpha: 0.45)
                        : AppColors.red.withValues(alpha: 0.35),
                    width: 1.2.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (slot.quantity > 0 ? AppColors.blue : AppColors.red)
                              .withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${slot.quantity}',
                          style: AppTextStyles.h1.standardCopyWith(
                            color: slot.quantity > 0
                                ? AppColors.textPrimary
                                : AppColors.red,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'ADET',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: slot.quantity > 0
                                ? AppColors.blue
                                : AppColors.red,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${(slot.quantity * (slot.unitVolume > 0 ? slot.unitVolume : 1.0)).toStringAsFixed(0)} m³ Hacim',
                      style: AppTextStyles.caption.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // ALT KONTROL VE ENVANTER BARI
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: AppFx.softOverlay(0.03),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppFx.softOverlay(0.06)),
            ),
            child: Row(
              children: [
                // Birim Maliyet
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.paymentsOutlined,
                      size: 13.sp,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 4.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Birim Maliyet',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          slot.cost > 0
                              ? AppMoney.compact(slot.cost)
                              : '-',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(width: 12.w),
                Container(
                  width: 1,
                  height: 22.h,
                  color: AppColors.border.withValues(alpha: 0.3),
                ),
                SizedBox(width: 12.w),
                // Toplam Stok Değeri
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.inventory2,
                        size: 13.sp,
                        color: AppColors.gold,
                      ),
                      SizedBox(width: 4.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Toplam Deger',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            slot.quantity > 0 && slot.cost > 0
                                ? AppMoney.compact(slot.quantity * slot.cost)
                                : '-',
                            style: AppTextStyles.body.standardCopyWith(
                              color: AppColors.textPrimary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                // Hızlı Sevk Et Butonu
                if (slot.quantity > 0)
                  InkWell(
                    onTap: () => _startWarehouseOutboundFlow(
                      context,
                      ref,
                      warehouse,
                      slot,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.localShippingOutlined,
                            size: 13.sp,
                            color: AppColors.gold,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Sevk Et',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(width: 4.w),
                // Menü Butonu (Pazardan Al, vb. / Slotu Sil)
                SizedBox(
                  height: 28.h,
                  width: 28.h,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      AppIcons.moreVert,
                      color: AppColors.textMuted,
                      size: AppIconSizes.medium,
                    ),
                    color: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      side: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.2),
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'market') {
                        _openMarketForSlot(context, warehouse, slot);
                      } else if (value == 'transfer') {
                        _startWarehouseOutboundFlow(
                          context,
                          ref,
                          warehouse,
                          slot,
                        );
                      } else if (value == 'discard') {
                        _discardWarehouseSlot(context, ref, slot);
                      } else if (value == 'delete') {
                        _deleteWarehouseSlot(context, ref, slot);
                      }
                    },
                    itemBuilder: (context) => [
                      _buildSlotMenuItem(
                        value: 'market',
                        icon: AppIcons.storefrontOutlined,
                        label: 'Pazardan Al',
                        color: AppColors.textPrimary,
                      ),
                      _buildSlotMenuItem(
                        value: 'transfer',
                        icon: AppIcons.localShippingOutlined,
                        label: 'Başka Depoya Gönder',
                        color: AppColors.textPrimary,
                      ),
                      if (slot.quantity > 0)
                        _buildSlotMenuItem(
                          value: 'discard',
                          icon: AppIcons.deleteOutline,
                          label: 'Çöpe At',
                          color: AppColors.red,
                        ),
                      if (slot.quantity <= 0)
                        _buildSlotMenuItem(
                          value: 'delete',
                          icon: AppIcons.deleteOutline,
                          label: 'Slotu Sil',
                          color: AppColors.red,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _discardWarehouseSlot(
    BuildContext context,
    WidgetRef ref,
    WarehouseSlotModel slot,
  ) async {
    final productName = slot.productName ?? 'Ürün';
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(
          'Ürünü Çöpe At',
          style: AppTextStyles.h1.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.headline,
          ),
        ),
        content: Text(
          'Bu slottaki ${slot.quantity} adet "$productName" çöpe atılacak ve kalıcı olarak silinecektir.\n\nDevam etmek istediğinize emin misiniz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Çöpe At'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final actionResult = await ref
        .read(warehouseActionProvider)
        .discardWarehouseSlot(warehouseSlotId: slot.id);

    if (!context.mounted) return;

    if (actionResult['success'] == true) {
      ref
          .read(warehouseDetailProvider(widget.warehouseId).notifier)
          .removeSlot(slot.id);
      ref
          .read(warehouseListProvider.notifier)
          .removeSlot(warehouseId: widget.warehouseId, slotId: slot.id);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: '$productName çöpe atıldı.',
        type: SnackbarType.info,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: actionResult['message'] ?? 'Ürün çöpe atılamadı.',
      type: SnackbarType.error,
    );
  }

  Future<void> _deleteWarehouseSlot(
    BuildContext context,
    WidgetRef ref,
    WarehouseSlotModel slot,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(
          'Slotu Sil',
          style: AppTextStyles.h1.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.headline,
          ),
        ),
        content: Text(
          'Bu boş depo slotunu silmek istediğinize emin misiniz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final actionResult = await ref
        .read(warehouseActionProvider)
        .deleteWarehouseSlot(warehouseSlotId: slot.id);

    if (!context.mounted) return;

    if (actionResult['success'] == true) {
      ref
          .read(warehouseDetailProvider(widget.warehouseId).notifier)
          .removeSlot(slot.id);
      ref
          .read(warehouseListProvider.notifier)
          .removeSlot(warehouseId: widget.warehouseId, slotId: slot.id);
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Slot Silindi',
        message: 'Depo slotu başarıyla silindi.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'İşlem Başarısız',
        message: actionResult['message']?.toString() ?? 'Slot silinemedi.',
        type: SnackbarType.error,
      );
    }
  }

  Future<void> _startWarehouseOutboundFlow(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel warehouse,
    WarehouseSlotModel initialSlot,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: AppLoadingIndicator(color: AppColors.gold)),
    );

    List<Map<String, dynamic>> warehouses = const [];
    List<dynamic> warehouseTypes = const [];
    try {
      warehouses = await ref
          .read(warehouseActionProvider)
          .getPlayerActiveWarehousesBasic();
      warehouseTypes = await ref.read(warehouseTypesProvider.future);
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Depolar Alinamadi',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
      return;
    }

    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;

    final initialProductId = initialSlot.productId?.trim().toUpperCase();
    if (initialProductId == null || initialProductId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Ürün Yok',
        message: 'Seçili slotta geçerli ürün bilgisi yok.',
        type: SnackbarType.warning,
      );
      return;
    }

    final candidates = warehouses.where((item) {
      if (item['id']?.toString() == warehouse.id) return false;

      final typeDetail = _findWarehouseTypeDetail(
        item['warehouse_type_id']?.toString() ?? '',
        warehouseTypes,
      );
      final acceptedIds = _parseAcceptedProductIds(
        typeDetail['accepted_product_ids'],
      );
      if (acceptedIds.isEmpty) return true;
      return acceptedIds.contains(initialProductId);
    }).toList();

    if (candidates.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hedef Depo Yok',
        message: 'Seçilen ürünü kabul eden başka aktif deponuz bulunmuyor.',
        type: SnackbarType.info,
      );
      return;
    }

    if (!context.mounted) return;
    _showWarehouseTargetPicker(
      context,
      ref,
      warehouse,
      initialSlot,
      candidates,
    );
  }

  void _showWarehouseTargetPicker(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    WarehouseSlotModel initialSlot,
    List<Map<String, dynamic>> warehouses,
  ) {
    final options = warehouses.map((target) {
      final cityName = ((target['city'] as Map?)?['name'] ?? '-').toString();
      final sameCity =
          (target['city_id']?.toString() ?? '') == sourceWarehouse.cityId;
      final totalCapacity = (target['capacity'] as num?)?.toDouble() ?? 0;
      final reservedCapacity =
          (target['reserved_capacity'] as num?)?.toDouble() ?? 0;
      final roughAvailable = (totalCapacity - reservedCapacity).clamp(
        0.0,
        totalCapacity,
      );

      final double capacityRatio = totalCapacity > 0
          ? (reservedCapacity / totalCapacity)
          : 0.0;
      final capacityLabel =
          '${reservedCapacity.toStringAsFixed(0)}/${totalCapacity.toStringAsFixed(0)} m³';

      final slotsRaw = target['warehouse_slots'] as List<dynamic>? ?? [];
      final previews = slotsRaw
          .map((s) {
            final qty = (s['quantity'] as num?)?.toDouble() ?? 0.0;
            final qual = (s['quality_level'] as num?)?.toInt() ?? 0;
            final icon =
                (s['product'] as Map?)?['urun_iconu']?.toString() ?? '';
            return WarehouseSelectionProductPreview(
              icon: icon,
              quantity: qty,
              quality: qual,
            );
          })
          .where((p) => p.quantity > 0 && p.icon.isNotEmpty)
          .toList();

      final double freeCapacity = roughAvailable;
      final freeCapacityLabel = '🟢 ${_formatValue(freeCapacity)} m³ Boş Alan';
      return WarehouseSelectionOption(
        id: target['id'].toString(),
        title: (target['name'] ?? 'Genel Depo').toString(),
        subtitle: '$cityName • Seviye ${target['level'] ?? 1}',
        cityName: cityName,
        isStoreWarehouse: false,
        badgeText: sameCity ? 'Aynı Şehir' : 'Lojistik',
        infoText: '✓ ${_formatValue(roughAvailable)} m³ boş alan mevcut',
        isHighlightBadge: sameCity,
        capacityRatio: capacityRatio,
        capacityLabel: capacityLabel,
        freeCapacityLabel: freeCapacityLabel,
        productPreviews: previews,
        onTap: () {
          Navigator.pop(context);
          _openTargetAwareWarehouseTransferPicker(
            context,
            ref,
            sourceWarehouse,
            initialSlot,
            target,
          );
        },
      );
    }).toList();

    WarehouseSelectionSheet.show(
      context: context,
      title: 'Hedef Depo Seçin',
      options: options,
    );
  }

  Future<void> _openTargetAwareWarehouseTransferPicker(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    WarehouseSlotModel initialSlot,
    Map<String, dynamic> targetWarehouse,
  ) async {
    final targetWarehouseId = targetWarehouse['id']?.toString() ?? '';
    if (targetWarehouseId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hedef Geçersiz',
        message: 'Hedef depo bilgisi okunamadı.',
        type: SnackbarType.error,
      );
      return;
    }

    WarehouseCapacityStatusModel? capacityStatus;
    try {
      capacityStatus = await ref.read(
        warehouseCapacityStatusProvider(targetWarehouseId).future,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Kapasite Alınamadı',
        message: e.toString(),
        type: SnackbarType.error,
      );
      return;
    }

    final targetTypeDetail = _findWarehouseTypeDetail(
      targetWarehouse['warehouse_type_id']?.toString() ?? '',
      await ref.read(warehouseTypesProvider.future),
    );
    final acceptedIds = _parseAcceptedProductIds(
      targetTypeDetail['accepted_product_ids'],
    ).toSet();

    final transferableSlots = sourceWarehouse.slots
        .where(
          (slot) =>
              slot.quantity > 0 &&
              slot.productId != null &&
              slot.productId!.trim().isNotEmpty &&
              (acceptedIds.isEmpty ||
                  acceptedIds.contains(slot.productId!.trim().toUpperCase())),
        )
        .toList();

    if (transferableSlots.isEmpty) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Uygun Ürün Yok',
        message: 'Bu hedef depo kaynak depodaki uygun ürünleri kabul etmiyor.',
        type: SnackbarType.info,
      );
      return;
    }

    final normalizedInitialSlot =
        transferableSlots.any((slot) => slot.id == initialSlot.id)
        ? initialSlot
        : transferableSlots.first;

    if (!context.mounted) return;
    await _showWarehouseTransferItemPicker(
      context,
      ref,
      sourceWarehouse,
      transferableSlots,
      normalizedInitialSlot,
      targetWarehouse,
      capacityStatus,
    );
  }

  Future<void> _showWarehouseTransferItemPicker(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    List<WarehouseSlotModel> slots,
    WarehouseSlotModel initialSlot,
    Map<String, dynamic> targetWarehouse,
    WarehouseCapacityStatusModel? capacityStatus,
  ) async {
    final currentBrandName = ref
        .read(playerBrandCompanyProvider)
        .value
        ?.brandName;
    final availableCapacity = capacityStatus?.availableCapacity ?? 0.0;
    final initialFits =
        initialSlot.unitVolume <= 0 ||
        initialSlot.unitVolume <= availableCapacity;
    final selectedQuantities = <String, int>{
      if (initialFits) initialSlot.id: 1,
    };

    double selectedVolumeExcluding(String slotId) {
      var total = 0.0;
      for (final slot in slots) {
        if (slot.id == slotId) continue;
        final quantity = selectedQuantities[slot.id] ?? 0;
        total += quantity * slot.unitVolume;
      }
      return total;
    }

    int maxSelectableForSlot(WarehouseSlotModel slot) {
      final unitVolume = slot.unitVolume;
      if (unitVolume <= 0) return slot.quantity;
      final remainingCapacity =
          availableCapacity - selectedVolumeExcluding(slot.id);
      final maxByCapacity = remainingCapacity <= 0
          ? 0
          : (remainingCapacity / unitVolume).floor();
      return maxByCapacity.clamp(0, slot.quantity);
    }

    final anySelectable = slots.any((slot) => maxSelectableForSlot(slot) > 0);
    if (!anySelectable) {
      AppSnackbar.show(
        context,
        title: 'Boş Kapasite Yok',
        message:
            'Hedef depoda seçilebilir ürünler için yeterli boş kapasite yok.',
        type: SnackbarType.warning,
      );
      return;
    }

    Future<void> openQuantityEditor(
      BuildContext sheetContext,
      StateSetter modalSetState,
      WarehouseSlotModel slot,
    ) async {
      final currentQuantity = selectedQuantities[slot.id] ?? 0;
      final limit = maxSelectableForSlot(slot);
      if (limit <= 0 && currentQuantity <= 0) {
        AppSnackbar.show(
          sheetContext,
          title: 'Boş Kapasite Yok',
          message: 'Hedef depoda bu ürün için yeterli boş kapasite kalmadı.',
          type: SnackbarType.warning,
        );
        return;
      }

      final effectiveLimit = currentQuantity > limit ? currentQuantity : limit;
      final controller = TextEditingController(
        text: currentQuantity > 0
            ? currentQuantity.toString()
            : (effectiveLimit > 0 ? '1' : '0'),
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
                    (slot.productName ?? 'Ürün') +
                        (slot.brandId != _defaultBrandId
                            ? ' (${currentBrandName ?? 'Markali'})'
                            : ''),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title.standardCopyWith(
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
                        style: AppTextStyles.body.standardCopyWith(
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
                      child:
                          slot.productIcon == null || slot.productIcon!.isEmpty
                          ? Icon(
                              AppIcons.inventory2Outlined,
                              color: AppColors.gold,
                              size: AppIconSizes.display,
                            )
                          : BrandedProductImage(
                              fileName: slot.productIcon!,
                              brandId: slot.brandId,
                              brandName: _brandNameForSlot(
                                slot,
                                currentBrandName,
                              ),
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
                    child: Column(
                      children: [
                        Row(
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
                              '${slot.quantity} Adet',
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontSize: AppTypography.body,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hedef Maksimum:',
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.bodySmall,
                              ),
                            ),
                            Text(
                              '$effectiveLimit Adet',
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.goldLight,
                                fontSize: AppTypography.body,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
                    style: AppTextStyles.input,
                    decoration: InputDecoration(
                      labelText: 'Miktar (Maks: $effectiveLimit)',
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
                      if (effectiveLimit > 0)
                        NumericKeyboardShortcut(
                          label: '1/4',
                          value: ((effectiveLimit / 4).ceil().clamp(
                            1,
                            effectiveLimit,
                          )).toString(),
                        ),
                      if (effectiveLimit > 0)
                        NumericKeyboardShortcut(
                          label: 'Yari',
                          value: ((effectiveLimit / 2).ceil().clamp(
                            1,
                            effectiveLimit,
                          )).toString(),
                        ),
                      if (effectiveLimit > 0)
                        NumericKeyboardShortcut(
                          label: 'Tamami',
                          value: effectiveLimit.toString(),
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
                      if (currentQuantity > 0) ...[
                        SizedBox(width: 8.w),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red,
                              side: BorderSide(
                                color: AppColors.red.withValues(alpha: 0.5),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            ),
                            onPressed: () => Navigator.pop(dialogContext, 0),
                            child: Text(
                              'Kaldir',
                              style: AppTextStyles.button.standardCopyWith(
                                fontSize: AppTypography.body,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                              if (quantity <= 0 || quantity > effectiveLimit) {
                                AppSnackbar.show(
                                  dialogContext,
                                  title: 'Geçersiz Miktar',
                                  message:
                                      '1 ile $effectiveLimit arasinda bir miktar girin.',
                                  type: SnackbarType.warning,
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

      controller.dispose();

      if (result == null) return;

      modalSetState(() {
        if (result <= 0) {
          selectedQuantities.remove(slot.id);
        } else {
          selectedQuantities[slot.id] = result;
        }
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
          final selectedItems = slots
              .where((slot) => (selectedQuantities[slot.id] ?? 0) > 0)
              .map(
                (slot) => _SelectedWarehouseTransferItem(
                  slot: slot,
                  quantity: selectedQuantities[slot.id] ?? 0,
                ),
              )
              .toList();
          final selectedQuantityTotal = selectedItems.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          );
          final selectedVolume = selectedItems.fold<double>(
            0,
            (sum, item) => sum + (item.quantity * item.slot.unitVolume),
          );
          final remainingCapacity = (availableCapacity - selectedVolume).clamp(
            0.0,
            availableCapacity,
          );
          final currentUsedCapacity = capacityStatus == null
              ? 0.0
              : capacityStatus.usedCapacity + capacityStatus.reservedCapacity;
          final projectedUsedCapacity = currentUsedCapacity + selectedVolume;
          final targetTotalCapacity = capacityStatus?.totalCapacity ?? 0.0;
          final currentCapacityRatio = targetTotalCapacity <= 0
              ? 0.0
              : (currentUsedCapacity / targetTotalCapacity).clamp(0.0, 1.0);
          final projectedCapacityRatio = targetTotalCapacity <= 0
              ? 0.0
              : (projectedUsedCapacity / targetTotalCapacity).clamp(0.0, 1.0);
          final projectedCapacityColor = projectedCapacityRatio >= 0.9
              ? AppColors.red
              : projectedCapacityRatio >= 0.75
              ? AppColors.warning
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
                    'Gönderilecek Ürünleri Seçin',
                    style: AppTextStyles.h1.standardCopyWith(
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
                                        AppIcons.inventory2Rounded,
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
                                            sourceWarehouse.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.title
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize:
                                                      AppTypography.bodyLarge,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            sourceWarehouse.cityName ?? '-',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body
                                                .standardCopyWith(
                                                  color: AppColors.goldLight,
                                                  fontSize: AppTypography.label,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          SizedBox(height: 5.h),
                                          _buildMetaChip(
                                            label: 'Kaynak Depo',
                                            color: AppColors.blue,
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
                            SizedBox(width: 8.w),
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
                                            (targetWarehouse['name'] ?? 'Depo')
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.title
                                                .standardCopyWith(
                                                  color: AppColors.textPrimary,
                                                  fontSize:
                                                      AppTypography.bodyLarge,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            ((targetWarehouse['city']
                                                        as Map?)?['name'] ??
                                                    sourceWarehouse.cityName ??
                                                    '-')
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body
                                                .standardCopyWith(
                                                  color: AppColors.goldLight,
                                                  fontSize: AppTypography.label,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          SizedBox(height: 5.h),
                                          _buildMetaChip(
                                            label: 'Hedef Depo',
                                            color: AppColors.green,
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
                                'Hedef Boş: ${_formatValue(remainingCapacity)} / ${_formatValue(availableCapacity)} m3',
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
                          height: 12.h,
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
                                    ? rawAddedWidth.clamp(6.0, totalWidth)
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
                                            color: AppColors.gold,
                                            border: Border.all(
                                              color: AppFx.softOverlay(0.45),
                                              width: 0.8,
                                            ),
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
                          'Seçilen Hacim: ${_formatValue(selectedVolume)} m3',
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
                    '${selectedItems.length} ürün çeşidi | $selectedQuantityTotal adet | ${_formatValue(selectedVolume)} m3 seçildi',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.body,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: slots.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 10.h),
                      itemBuilder: (_, index) {
                        final slot = slots[index];
                        final selectedQuantity =
                            selectedQuantities[slot.id] ?? 0;
                        final isSelected = selectedQuantity > 0;
                        final maxForSlot = maxSelectableForSlot(slot);
                        final isDisabled = maxForSlot <= 0 && !isSelected;
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
                                child:
                                    slot.productIcon == null ||
                                        slot.productIcon!.isEmpty
                                    ? Icon(
                                        AppIcons.inventory2Outlined,
                                        color: AppColors.gold,
                                        size: AppIconSizes.medium,
                                      )
                                    : BrandedProductImage(
                                        fileName: slot.productIcon!,
                                        brandId: slot.brandId,
                                        brandName: _brandNameForSlot(
                                          slot,
                                          currentBrandName,
                                        ),
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
                                      (slot.productName ?? 'Ürün') +
                                          (slot.brandId != _defaultBrandId
                                              ? ' (${currentBrandName ?? 'Markali'})'
                                              : ''),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.title
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
                                            '| Stok ${slot.quantity} | Birim ${_formatValue(slot.unitVolume)} m3',
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
                                    SizedBox(height: 2.h),
                                    Text(
                                      isDisabled
                                          ? 'Kapasite dolu'
                                          : 'Bu hedef için maks: $maxForSlot',
                                      style: AppTextStyles.caption
                                          .standardCopyWith(
                                            color: isDisabled
                                                ? AppColors.red
                                                : AppColors.goldLight,
                                            fontSize: AppTypography.label,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              OutlinedButton(
                                onPressed: isDisabled
                                    ? null
                                    : () {
                                        if (!isSelected) {
                                          modalSetState(() {
                                            selectedQuantities[slot.id] =
                                                maxForSlot;
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
                                  side: BorderSide(
                                    color:
                                        (isSelected
                                                ? AppColors.green
                                                : AppColors.gold)
                                            .withValues(alpha: 0.35),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 8.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
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
                          : () {
                              Navigator.pop(sheetContext);
                              _submitWarehouseOutboundTransfer(
                                context,
                                ref,
                                sourceWarehouse,
                                selectedItems,
                                targetWarehouse,
                              );
                            },
                      icon: Icon(AppIcons.localShippingOutlined),
                      label: const Text('Transferi Başlat'),
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

  Future<void> _submitWarehouseOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    List<_SelectedWarehouseTransferItem> items,
    Map<String, dynamic> targetWarehouse, {
    String? vehicleId,
  }) async {
    final targetWarehouseId = targetWarehouse['id']?.toString() ?? '';
    final sameCity =
        (targetWarehouse['city_id']?.toString() ?? '') ==
        sourceWarehouse.cityId;

    if (targetWarehouseId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hedef Geçersiz',
        message: 'Hedef depo bilgisi okunamadı.',
        type: SnackbarType.error,
      );
      return;
    }

    if (!sameCity) {
      if (vehicleId == null || vehicleId.isEmpty) {
        await _showIntercityWarehouseTransferVehiclePicker(
          context,
          ref,
          sourceWarehouse,
          items,
          targetWarehouse,
        );
      } else {
        await _startWarehouseTransfer(
          context,
          ref,
          sourceWarehouse,
          items,
          targetWarehouse,
          vehicleId: vehicleId,
        );
      }
      return;
    }

    await _startWarehouseTransfer(
      context,
      ref,
      sourceWarehouse,
      items,
      targetWarehouse,
    );
  }

  Future<void> _startWarehouseTransfer(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    List<_SelectedWarehouseTransferItem> items,
    Map<String, dynamic> targetWarehouse, {
    String? vehicleId,
  }) async {
    final targetWarehouseId = targetWarehouse['id']?.toString() ?? '';
    final payload = items
        .map(
          (item) => <String, dynamic>{
            'source_warehouse_slot_id': item.slot.id,
            'quantity': item.quantity,
          },
        )
        .toList();
    final totalQuantity = items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: AppLoadingIndicator(color: AppColors.gold)),
    );

    final result = await ref
        .read(warehouseActionProvider)
        .startWarehouseToWarehouseTransfer(
          sourceWarehouseId: sourceWarehouse.id,
          buyerWarehouseId: targetWarehouseId,
          items: payload,
          vehicleId: vehicleId,
        );

    if (!context.mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      final isInstant = result['mode']?.toString() == 'instant';
      final slotQuantities = <String, int>{};
      for (final item in items) {
        final remaining = item.slot.quantity - item.quantity;
        slotQuantities[item.slot.id] = remaining;
      }
      ref
          .read(warehouseDetailProvider(sourceWarehouse.id).notifier)
          .patchSlotQuantities(slotQuantities);
      ref
          .read(warehouseListProvider.notifier)
          .patchSlotQuantities(
            warehouseId: sourceWarehouse.id,
            slotQuantities: slotQuantities,
          );
      ref.invalidate(warehouseDetailProvider(targetWarehouseId));
      ref.invalidate(buyerTransferMapProvider);
      ref.invalidate(buyerTransferHistoryProvider);

      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Transfer Başarılı',
        message: isInstant
            ? '${items.length} ürün çeşidi, toplam $totalQuantity adet hedef depoya aktarıldı.'
            : 'Depolar arası transfer başlatıldı. Araç yola çıktı.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Transfer Başarısız',
      message: result['message']?.toString() ?? 'Transfer baslatilamadi.',
      type: SnackbarType.error,
    );
  }

  Widget _buildQualityStars(int quality) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < quality;
        return Padding(
          padding: EdgeInsets.only(right: 1.w),
          child: Icon(
            isFilled ? AppIcons.star : AppIcons.starBorder,
            color: isFilled ? AppColors.gold : AppColors.textMuted,
            size: AppIconSizes.xSmall,
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.errorOutline,
              color: AppColors.red,
              size: AppIconSizes.displayLarge,
            ),
            SizedBox(height: 12.h),
            Text(
              'Depo detayı yüklenemedi.',
              textAlign: TextAlign.center,
              style: AppTextStyles.title.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  CityModel? _findCityById(List<CityModel> cities, String cityId) {
    for (final city in cities) {
      if (city.id == cityId) return city;
    }
    return null;
  }

  String _formatValue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
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

  Future<void> _showWarehouseUpgradeSheet(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel warehouse,
  ) async {
    await ref.read(warehouseActionProvider).completeDueWarehouseUpgrades();
    ref.invalidate(activeWarehouseUpgradeProvider(widget.warehouseId));
    ref.invalidate(anyActiveWarehouseUpgradeProvider);
    await Future<void>.delayed(Duration.zero);
    await ref.read(activeWarehouseUpgradeProvider(widget.warehouseId).future);
    await ref.read(anyActiveWarehouseUpgradeProvider.future);
    final warehouseTypes = await ref.read(warehouseTypesProvider.future);
    final mergedTypeDetail = {
      ..._findWarehouseTypeDetail(warehouse.warehouseTypeId, warehouseTypes),
      ...?warehouse.warehouseType,
    };
    final inferredBaseCapacity = warehouse.level > 0
        ? warehouse.capacity / warehouse.level
        : warehouse.capacity;
    final baseCapacity = _readMapDouble(mergedTypeDetail, 'base_capacity') > 0
        ? _readMapDouble(mergedTypeDetail, 'base_capacity')
        : inferredBaseCapacity;
    final constructionMinutes = _readMapInt(
      mergedTypeDetail,
      'construction_time_minutes',
    );
    final baseCost = _readMapDouble(mergedTypeDetail, 'cost');
    final targetLevel = warehouse.level + 1;
    final upgradeCost =
        ((baseCost * 0.30) *
                (warehouse.level <= 1 ? 1 : _pow1p1(warehouse.level - 1)))
            .ceilToDouble();
    final durationMinutes = constructionMinutes * targetLevel;

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Depo Yukseltmesi',
                style: AppTextStyles.h1.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.headline,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Her yükseltmede depo kapasitesi, tipin başlangıç kapasitesi kadar artar.',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textMuted,
                  fontSize: AppTypography.body,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppFx.softOverlay(0.03),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seviye ${warehouse.level} -> $targetLevel',
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Kapasite: ${_formatValue(warehouse.capacity)} m3 -> ${_formatValue(warehouse.capacity + baseCapacity)} m3',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Artis: +${_formatValue(baseCapacity)} m3',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Süre: $durationMinutes dk',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Maliyet: ${upgradeCost.toStringAsFixed(0)} TL',
                      style: AppTextStyles.body.standardCopyWith(
                        color: AppColors.textMuted,
                        fontSize: AppTypography.body,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          final result = await ref
                              .read(warehouseActionProvider)
                              .startWarehouseUpgrade(
                                warehouse.id,
                                syncProviders: false,
                              );

                          if (!context.mounted) return;

                          if (result['success'] == true) {
                            final newUpgrade = BuildingUpgradeModel.fromJson(result);
                            ref
                                .read(activeWarehouseUpgradeProvider(warehouse.id).notifier)
                                .setUpgrade(newUpgrade);
                            if (!context.mounted) return;
                            FloatingFeedback.show(
                              context,
                              amount: upgradeCost,
                              type: FloatingFeedbackType.cashRemove,
                            );
                            AppSnackbar.show(
                              context,
                              title: 'Başarılı',
                              message: 'Depo yükseltmesi başlatıldı.',
                              type: SnackbarType.success,
                            );
                          } else {
                            AppSnackbar.show(
                              context,
                              title: 'Hata',
                              message:
                                  result['message'] ??
                                  'Depo yukseltmesi baslatilamadi.',
                              type: SnackbarType.error,
                            );
                          }
                        },
                        icon: Icon(AppIcons.upgradeRounded),
                        label: const Text('Yükseltmeyi Başlat'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _finishWarehouseUpgradeWithGold(
    BuildingUpgradeModel upgrade,
  ) async {
    final result = await ref
        .read(warehouseActionProvider)
        .finishWarehouseUpgradeWithGold(upgrade.id, syncProviders: false);

    if (!mounted) return;

    if (result['success'] == true) {
      final targetLevel = (result['target_level'] as num?)?.toInt() ?? upgrade.targetLevel;
      final capacityIncrease = (result['capacity_increase'] as num?)?.toDouble() ?? 0.0;
      final currentWarehouse = ref.read(warehouseDetailProvider(widget.warehouseId)).value;
      final newCapacity = (currentWarehouse?.capacity ?? 0.0) + capacityIncrease;

      ref.read(activeWarehouseUpgradeProvider(widget.warehouseId).notifier).clear();
      ref
          .read(warehouseDetailProvider(widget.warehouseId).notifier)
          .patchLevelAndCapacity(level: targetLevel, capacity: newCapacity);
      ref
          .read(warehouseListProvider.notifier)
          .patchLevelAndCapacity(warehouseId: widget.warehouseId, level: targetLevel, capacity: newCapacity);

      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message: 'Depo yükseltmesi tamamlandı.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yükseltme tamamlanamadı.',
      type: SnackbarType.error,
    );
  }

  Future<void> _reduceWarehouseUpgradeTimeWithAd(
    BuildingUpgradeModel upgrade,
  ) async {
    final success = await RewardedTimeReductionFlow.run(
      context,
      rewardKind: 'upgrade_time_reduce',
      resourceId: upgrade.id,
      onApplyReduction: () => ref
          .read(warehouseActionProvider)
          .reduceWarehouseUpgradeTimeWithAd(upgrade.id, syncProviders: false),
      successMessage: 'Depo yükseltme süresi 10 dakika kısaltıldı.',
    );

    if (success) {
      ref
          .read(activeWarehouseUpgradeProvider(widget.warehouseId).notifier)
          .reduceTime(const Duration(minutes: 10));
    }
  }

  Future<void> _showIntercityWarehouseTransferVehiclePicker(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    List<_SelectedWarehouseTransferItem> items,
    Map<String, dynamic> targetWarehouse,
  ) async {
    final targetWarehouseId = targetWarehouse['id']?.toString() ?? '';
    final targetCityId = targetWarehouse['city_id']?.toString() ?? '';
    if (targetWarehouseId.isEmpty || targetCityId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hedef Geçersiz',
        message: 'Hedef depo veya şehir bilgisi okunamadı.',
        type: SnackbarType.error,
      );
      return;
    }

    final cities = await ref.read(activeCitiesProvider.future);
    final sourceCity = _findCityById(cities, sourceWarehouse.cityId);
    final targetCity = _findCityById(cities, targetCityId);

    if (sourceCity == null || targetCity == null) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Şehir Verisi Eksik',
        message: 'Mesafe hesabı için şehir verileri okunamadı.',
        type: SnackbarType.error,
      );
      return;
    }

    final totalVolume = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.slot.unitVolume),
    );
    final TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>
    vehicleResult;
    try {
      vehicleResult = await ref
          .read(warehouseActionProvider)
          .getIntercityRouteVehicleOptions(
            sourceCityId: sourceWarehouse.cityId,
            targetCityId: targetCityId,
            totalVolume: totalVolume,
          );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Araç Seçim Hatası',
        message: 'Araç seçenekleri alınamadı: ${e.toString()}',
        type: SnackbarType.error,
      );
      return;
    }
    final options = vehicleResult.options;

    if (options.isEmpty) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Araç Yok',
        message:
            vehicleResult.unavailableReason ??
            'Şehirler arası transfer için uygun araç bulunamadı.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (!context.mounted) return;
    final selectedVehicleId = await showTransferVehicleSelectionSheet(
      context: context,
      sourceCityName: sourceWarehouse.cityName ?? '-',
      targetCityName:
          (targetWarehouse['city'] as Map?)?['name']?.toString() ?? '-',
      totalVolume: totalVolume,
      options: options.map(TransferVehicleOptionItem.fromMarket).toList(),
      unavailableReason: !vehicleResult.hasSelectableOptions
          ? vehicleResult.unavailableReason
          : null,
    );

    if (selectedVehicleId != null && context.mounted) {
      _submitWarehouseOutboundTransfer(
        context,
        ref,
        sourceWarehouse,
        items,
        targetWarehouse,
        vehicleId: selectedVehicleId,
      );
    }
  }

  double _pow1p1(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 1.1;
    }
    return result;
  }

  double _readMapDouble(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _readMapInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _brandNameForSlot(WarehouseSlotModel slot, String? currentBrandName) {
    if (slot.brandId == _defaultBrandId) return null;
    return currentBrandName;
  }

  Future<void> _showSellWarehouseDialog(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel warehouse,
  ) async {
    final quote = await ref
        .read(warehouseActionProvider)
        .sellWarehouse(warehouseId: warehouse.id, confirm: false);

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
          'Depoyu Sat',
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
              '${warehouse.name} kalici olarak silinecek. Bu islem geri alinamaz.',
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
                  _buildSalesSummaryRow(
                    'Toplam Odeme',
                    totalRefund,
                    valueColor: AppColors.green,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Aktif transferler varsa satış engellenir. Satış sonrası tüm depo slotları ve stoklar silinir.',
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
              'Depoyu Sat',
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
        .read(warehouseActionProvider)
        .sellWarehouse(
          warehouseId: warehouse.id,
          confirm: true,
          syncProviders: false,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref.read(warehouseListProvider.notifier).removeWarehouse(warehouse.id);
      AppSnackbar.show(
        context,
        title: 'Başarılı',
        message:
            'Depo satildi. ${totalRefund.toStringAsFixed(1)} TL iade edildi.',
        type: SnackbarType.success,
      );
      context.go('/warehouses');
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Depo satilamadi.',
      type: SnackbarType.error,
    );
  }

  Widget _buildSalesSummaryRow(
    String label,
    double value, {
    Color? valueColor,
  }) {
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

class _SelectedWarehouseTransferItem {
  const _SelectedWarehouseTransferItem({
    required this.slot,
    required this.quantity,
  });

  final WarehouseSlotModel slot;
  final int quantity;
}

class _ActiveWarehouseUpgradeCard extends ConsumerWidget {
  const _ActiveWarehouseUpgradeCard({
    required this.upgrade,
    required this.onFinishWithGold,
    this.onReduceTimeWithAd,
    required this.calculateStarCost,
    required this.formatCountdown,
  });

  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final Future<void> Function()? onReduceTimeWithAd;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

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
                      'Depo Yukseltmesi Devam Ediyor',
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Seviye ${upgrade.currentLevel} -> ${upgrade.targetLevel} | Kapasite ${_formatCapacity(upgrade.previousCapacity)} -> ${_formatCapacity(upgrade.nextCapacity)}',
                      style: AppTextStyles.body.standardCopyWith(
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
              icon: Icon(AppIcons.starRounded),
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
                  'Bir reklam ödülü al ve depo yükseltme süresini 10 dakika kısalt.',
            ),
          ],
        ],
      ),
    );
  }

  String _formatCapacity(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
