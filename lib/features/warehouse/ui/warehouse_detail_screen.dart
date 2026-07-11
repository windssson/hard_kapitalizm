import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:hard_kapitalizm/core/widgets/price_sparkline.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
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
          icon: Icon(
            AppIcons.addShoppingCart,
            color: AppColors.textOnAccent,
          ),
          label: Text(
            'Urun Ekle',
            style: AppTextStyles.button.standardCopyWith(fontWeight: FontWeight.bold),
          ),
        ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: warehouseAsync.when(
          data: (warehouse) => Column(
            children: [
              SecondaryTopBar(title: '${warehouse.name} Yonetimi'),
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
          loading: () => Center(
            child: AppLoadingIndicator(color: AppColors.gold),
          ),
          error: (error, stack) => _buildErrorState(error),
        ),
      ),
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

  Future<void> _refreshWarehouseEcosystem({bool refreshPlayer = true}) async {
    await ref.read(warehouseActionProvider).completeDueWarehouseUpgrades();
    ref.invalidate(warehouseDetailProvider(widget.warehouseId));
    ref.invalidate(activeWarehouseUpgradeProvider(widget.warehouseId));
    ref.invalidate(anyActiveWarehouseUpgradeProvider);
    ref.invalidate(warehouseListProvider);
    if (refreshPlayer) {
      ref.invalidate(playerProvider);
    }
    await ref.read(warehouseDetailProvider(widget.warehouseId).future);
    await ref.read(activeWarehouseUpgradeProvider(widget.warehouseId).future);
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
        title: 'Deponun Alabildigi Urunler',
        options: options,
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: 'Urun listesi yuklenemedi: $e',
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
        title: 'Urun Yok',
        message: 'Bu slot icin pazar acilamadi.',
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
                    padding: EdgeInsets.all(5.w),
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
                      fit: BoxFit.contain,
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
                                      style: AppTextStyles.body.standardCopyWith(
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
                      : () => _showWarehouseUpgradeSheet(
                            context,
                            ref,
                            warehouse,
                          ),
                  icon: AppIcons.upgradeRounded,
                  label: activeUpgrade != null
                      ? 'Devam Ediyor'
                      : hasAnotherActiveUpgrade
                      ? 'Baska Yukseltme Var'
                      : 'Yukselt',
                  color: activeUpgrade != null || hasAnotherActiveUpgrade
                      ? AppColors.textMuted
                      : AppColors.green,
                  isEnabled: activeUpgrade == null && !hasAnotherActiveUpgrade,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildMinimalActionButton(
                  onPressed: () => context.push('/warehouses/${warehouse.id}/history'),
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
          side: BorderSide(
            color: accent.withValues(alpha: 0.18),
          ),
        ),
        textStyle: AppTextStyles.label.standardCopyWith(
          fontSize: AppTypography.bodySmall,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: Icon(icon, size: AppIconSizes.compact),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
              Icon(AppIcons.straighten, color: AppColors.gold, size: AppIconSizes.small),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Kapasite Dagilimi',
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
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _buildCapacityLegend(
                'Stok',
                formatVolume(usedCapacity),
                AppColors.blue,
              ),
              _buildCapacityLegend(
                'Yolda',
                formatVolume(reservedCapacity),
                AppColors.gold,
              ),
              _buildCapacityLegend(
                'Bos',
                formatVolume(availableCapacity),
                AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapacityLegend(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.w,
          height: 7.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          '$label: $value',
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textSecondary,
            fontSize: AppTypography.caption,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      if (a.isAvailableForSale != b.isAvailableForSale) {
        return a.isAvailableForSale ? -1 : 1;
      }
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
            Text('Bu depoda henuz urun yok.', style: AppTextStyles.body),
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
        return _buildSlotCard(context, ref, warehouse, slot, company, companyProducts);
      },
    );
  }

  Widget _buildSlotValueTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? suffix,
    Color? suffixColor,
  }) {
    final content = Container(
      constraints: BoxConstraints(minHeight: 48.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppFx.softOverlay(0.035),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppFx.softOverlay(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color.withValues(alpha: 0.82),
            size: AppIconSizes.small,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.standardCopyWith(
                    color: AppColors.textMuted,
                    fontSize: AppTypography.micro,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodySmall,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (suffix != null) ...[
                      SizedBox(width: 4.w),
                      Text(
                        suffix,
                        style: AppTextStyles.caption.standardCopyWith(
                          color: (suffixColor ?? color).withValues(alpha: 0.9),
                          fontSize: AppTypography.micro,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildSaleToggleChip({
    required bool isActive,
    required ValueChanged<bool> onChanged,
  }) {
    final color = isActive ? AppColors.green : AppColors.textMuted;

    return Container(
      height: 30.h,
      padding: EdgeInsets.only(left: 8.w, right: 2.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isActive ? 'Satisa Acik' : 'Satisa Kapali',
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 4.w),
          SizedBox(
            height: 24.h,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: isActive,
                activeThumbColor: AppColors.green,
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppFx.panelWash(0.26),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required String label,
    required Color color,
  }) {
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
              width: 58.w,
              height: 58.w,
              padding: EdgeInsets.all(9.w),
              decoration: BoxDecoration(
                color: AppFx.panelWash(0.3),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppFx.softOverlay(0.10)),
              ),
              child: Icon(
                AppIcons.addCircleOutline,
                color: AppColors.textMuted,
                size: AppIconSizes.large,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bos Slot',
                    style: AppTextStyles.title.standardCopyWith(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.titleLarge,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Bu slot su an bos. Urun ekleyebilirsiniz.',
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
                label: 'Urun Ekle',
                icon: AppIcons.addShoppingCartOutlined,
                onPressed: () => _showProductSelection(context, warehouse),
                filled: true,
              ),
            ),
          ],
        ),
      );
    }

    final marginPercent = (slot.price > 0 && slot.cost > 0)
        ? ((slot.price - slot.cost) / slot.cost) * 100
        : null;
    final marginColor = marginPercent == null
        ? AppColors.textMuted
        : marginPercent >= 0
        ? AppColors.green
        : AppColors.red;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(13.w),
      decoration: AppDecorations.premiumCard(
        slot.isAvailableForSale ? AppColors.green : null,
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
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: AppFx.panelWash(0.24),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: slot.isAvailableForSale
                        ? AppColors.green.withValues(alpha: 0.32)
                        : AppFx.softOverlay(0.10),
                  ),
                ),
                child: BrandedProductImage(
                  fileName: slot.productIcon ?? 'default.webp',
                  brandId: slot.brandId,
                  brandName: _brandNameForSlot(slot, currentBrandName),
                  productId: slot.productId,
                  fit: BoxFit.contain,
                  showFrame: false,
                  company: company,
                  companyProducts: companyProducts,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (slot.productName ?? 'Urun') +
                          (slot.brandId != _defaultBrandId
                              ? ' (${currentBrandName ?? 'Markali'})'
                              : ''),
                      style: AppTextStyles.title.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.titleLarge,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        _buildQualityStars(slot.qualityLevel),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSaleToggleChip(
                    isActive: slot.isAvailableForSale,
                    onChanged: (_) => _toggleSaleStatus(context, ref, slot),
                  ),
                  SizedBox(width: 4.w),
                  SizedBox(
                    height: 30.h,
                    width: 30.h,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        AppIcons.moreVert,
                        color: AppColors.textMuted,
                        size: AppIconSizes.mediumLarge,
                      ),
                      color: AppColors.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.2),
                        ),
                      ),
                      onSelected: (value) {
                        if (value == 'price') {
                          _showPriceDialog(context, ref, slot);
                        } else if (value == 'market') {
                          _openMarketForSlot(context, warehouse, slot);
                        } else if (value == 'transfer') {
                          _startWarehouseOutboundFlow(
                            context,
                            ref,
                            warehouse,
                            slot,
                          );
                        } else if (value == 'delete') {
                          _deleteWarehouseSlot(context, ref, slot);
                        }
                      },
                      itemBuilder: (context) => [
                        _buildSlotMenuItem(
                          value: 'price',
                          icon: AppIcons.sellOutlined,
                          label: 'Fiyat Duzenle',
                          color: AppColors.gold,
                        ),
                        _buildSlotMenuItem(
                          value: 'market',
                          icon: AppIcons.storefrontOutlined,
                          label: 'Pazardan Al',
                          color: AppColors.textPrimary,
                        ),
                        _buildSlotMenuItem(
                          value: 'transfer',
                          icon: AppIcons.localShippingOutlined,
                          label: 'Baska Depoya Gonder',
                          color: AppColors.textPrimary,
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
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildSlotValueTile(
                  label: 'Stok',
                  value: slot.quantity.toString(),
                  icon: AppIcons.inventory2Outlined,
                  color: AppColors.blue,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSlotValueTile(
                  label: 'Maliyet',
                  value: slot.cost > 0 ? AppMoney.compact(slot.cost) : '-',
                  icon: AppIcons.paymentsOutlined,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSlotValueTile(
                  label: 'Satis',
                  value: slot.price > 0 ? AppMoney.compact(slot.price) : '-',
                  suffix: marginPercent != null
                      ? '%${marginPercent.toStringAsFixed(0)}'
                      : null,
                  suffixColor: marginColor,
                  icon: AppIcons.sellOutlined,
                  color: AppColors.gold,
                  onTap: () => _showPriceDialog(context, ref, slot),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPriceDialog(
    BuildContext context,
    WidgetRef ref,
    WarehouseSlotModel slot,
  ) async {
    final currentBrandName = ref.read(playerBrandCompanyProvider).value?.brandName;
    String priceShortcut(double value) {
      if (value <= 0) return '';
      return value.toStringAsFixed(1);
    }

    double parsePrice(String value) {
      return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    }

    final controller = TextEditingController(
      text: slot.price > 0 ? slot.price.toStringAsFixed(1) : '',
    );
    final shortcuts = <NumericKeyboardShortcut>[
      if (slot.price > 0)
        NumericKeyboardShortcut(
          label: 'Mevcut',
          value: priceShortcut(slot.price),
        ),
      if (slot.cost > 0)
        NumericKeyboardShortcut(
          label: 'Maliyet',
          value: priceShortcut(slot.cost),
        ),
    ];

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardBg,
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
            maxWidth: 400.w,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
                child: Row(
                  children: [
                    Container(
                      width: 46.w,
                      height: 46.w,
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AppFx.panelWash(0.28),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: BrandedProductImage(
                        fileName: slot.productIcon ?? 'default.webp',
                        brandId: slot.brandId,
                        brandName: _brandNameForSlot(slot, currentBrandName),
                        productId: slot.productId,
                        fit: BoxFit.contain,
                        showFrame: false,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Satis Fiyati',
                                  style: AppTextStyles.h1.standardCopyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: AppTypography.headline,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  (slot.productName ?? 'Urun') +
                                      (slot.brandId != _defaultBrandId
                                          ? ' (${currentBrandName ?? 'Markali'})'
                                          : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body.standardCopyWith(
                                    color: AppColors.textMuted,
                                    fontSize: AppTypography.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Consumer(
                            builder: (context, ref, _) {
                              final historyAsync = ref.watch(
                                productPriceHistoryProvider(
                                  slot.productId ?? '',
                                ),
                              );
                              return historyAsync.maybeWhen(
                                data: (history) {
                                  if (history == null ||
                                      history.prices.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final priceList = history.prices
                                      .map((p) => '₺${p.toStringAsFixed(1)}')
                                      .join(' ➔ ');
                                  return Tooltip(
                                    message: '5 Günlük Fiyat Seyri:\n$priceList',
                                    child: PriceSparkline(
                                      prices: history.prices,
                                      width: 104.w,
                                      height: 36.h,
                                    ),
                                  );
                                },
                                orElse: () => const SizedBox.shrink(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: AppFx.softOverlay(0.1), height: 1),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final price = parsePrice(value.text);
                    final profit = slot.cost > 0 ? price - slot.cost : 0.0;
                    final profitPercent = slot.cost > 0
                        ? (profit / slot.cost) * 100
                        : 0.0;
                    final profitColor = slot.cost <= 0
                        ? AppColors.textMuted
                        : profit >= 0
                        ? AppColors.green
                        : AppColors.red;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppFx.panelWash(0.3),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Birim satis fiyati',
                                style: AppTextStyles.body.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: AppTypography.bodySmall,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                value.text.isEmpty ? '0.0' : value.text,
                                style: AppTextStyles.largeTitle.standardCopyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: AppTypography.display,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPriceInfoTile(
                                'Maliyet',
                                slot.cost > 0
                                    ? slot.cost.toStringAsFixed(1)
                                    : '-',
                                AppColors.textMuted,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: _buildPriceInfoTile(
                                'Kar',
                                slot.cost > 0
                                    ? '${profit.toStringAsFixed(1)} (${profitPercent.toStringAsFixed(0)}%)'
                                    : '-',
                                profitColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: NumericKeyboard(
                  controller: controller,
                  allowDecimal: true,
                  shortcuts: shortcuts,
                  buttonHeight: 44.h,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text(
                          'Iptal',
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.body,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final parsed = parsePrice(controller.text);
                          if (parsed <= 0) {
                            Navigator.pop(dialogContext);
                            AppSnackbar.show(
                              context,
                              title: 'Gecersiz Fiyat',
                              message: 'Satis fiyati 0 buyuk olmali.',
                              type: SnackbarType.error,
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, parsed);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.textOnAccent,
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text(
                          'Kaydet',
                          style: AppTextStyles.button.standardCopyWith(
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
    );

    controller.dispose();

    if (result == null || !context.mounted) return;

    final actionResult = await ref
        .read(warehouseActionProvider)
        .updateWarehouseSlotPrice(warehouseSlotId: slot.id, price: result);

    if (!context.mounted) return;

    if (actionResult['success'] == true) {
      final nextPrice = (actionResult['price'] as num?)?.toDouble() ?? result;
      ref
          .read(warehouseDetailProvider(widget.warehouseId).notifier)
          .patchSlotPrice(slotId: slot.id, price: nextPrice);
      ref
          .read(warehouseListProvider.notifier)
          .patchSlotPrice(
            warehouseId: widget.warehouseId,
            slotId: slot.id,
            price: nextPrice,
          );
      final productName = (slot.productName ?? 'Urun') + (slot.brandId != _defaultBrandId ? ' (${currentBrandName ?? 'Markali'})' : '');
      AppSnackbar.show(
        context,
        title: 'Fiyat Guncellendi',
        message: '$productName icin satis fiyati kaydedildi.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Islem Basarisiz',
        message: actionResult['message']?.toString() ?? 'Fiyat kaydedilemedi.',
        type: SnackbarType.error,
      );
    }
  }

  Widget _buildPriceInfoTile(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.standardCopyWith(
              color: color,
              fontSize: AppTypography.body,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
          'Bu bos depo slotunu silmek istediginize emin misiniz?',
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Iptal'),
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
        message: 'Depo slotu basariyla silindi.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Islem Basarisiz',
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
      builder: (_) =>
          Center(child: AppLoadingIndicator(color: AppColors.gold)),
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
        title: 'Urun Yok',
        message: 'Secili slotta gecerli urun bilgisi yok.',
        type: SnackbarType.warning,
      );
      return;
    }

    final candidates = warehouses
        .where((item) {
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
        })
        .toList();

    if (candidates.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hedef Depo Yok',
        message:
            'Secilen urunu kabul eden baska aktif deponuz bulunmuyor.',
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
      final sameCity = (target['city_id']?.toString() ?? '') == sourceWarehouse.cityId;
      final totalCapacity =
          (target['capacity'] as num?)?.toDouble() ?? 0;
      final reservedCapacity =
          (target['reserved_capacity'] as num?)?.toDouble() ?? 0;
      final roughAvailable = (totalCapacity - reservedCapacity).clamp(
        0.0,
        totalCapacity,
      );

      return WarehouseSelectionOption(
        id: target['id'].toString(),
        title: (target['name'] ?? 'Depo').toString(),
        subtitle: '$cityName | Seviye: ${target['level'] ?? 1}',
        badgeText: sameCity ? 'Ayni Sehir' : 'Sehirler Arasi',
        infoText: '~${_formatValue(roughAvailable)} m3 bos',
        isHighlightBadge: sameCity,
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
      title: 'Hedef Depo Secin',
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
        title: 'Hedef Gecersiz',
        message: 'Hedef depo bilgisi okunamadi.',
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
        title: 'Kapasite Alinamadi',
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
        title: 'Uygun Urun Yok',
        message: 'Bu hedef depo kaynak depodaki uygun urunleri kabul etmiyor.',
        type: SnackbarType.info,
      );
      return;
    }

    final normalizedInitialSlot = transferableSlots.any(
          (slot) => slot.id == initialSlot.id,
        )
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
    final currentBrandName = ref.read(playerBrandCompanyProvider).value?.brandName;
    final availableCapacity = capacityStatus?.availableCapacity ?? 0.0;
    final initialFits =
        initialSlot.unitVolume <= 0 || initialSlot.unitVolume <= availableCapacity;
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
        title: 'Bos Kapasite Yok',
        message: 'Hedef depoda secilebilir urunler icin yeterli bos kapasite yok.',
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
          title: 'Bos Kapasite Yok',
          message: 'Hedef depoda bu urun icin yeterli bos kapasite kalmadi.',
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
                    (slot.productName ?? 'Urun') +
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
                      child: slot.productIcon == null || slot.productIcon!.isEmpty
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
                          value: ((effectiveLimit / 4).ceil().clamp(1, effectiveLimit))
                              .toString(),
                        ),
                      if (effectiveLimit > 0)
                        NumericKeyboardShortcut(
                          label: 'Yari',
                          value: ((effectiveLimit / 2).ceil().clamp(1, effectiveLimit))
                              .toString(),
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
                            'Iptal',
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
                              side: BorderSide(color: AppColors.red.withValues(alpha: 0.5)),
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
                              final quantity = int.tryParse(controller.text) ?? 0;
                              if (quantity <= 0 || quantity > effectiveLimit) {
                                AppSnackbar.show(
                                  dialogContext,
                                  title: 'Gecersiz Miktar',
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
                    'Gonderilecek Urunleri Secin',
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
                        color: AppColors.borderGoldLight.withValues(alpha: 0.12),
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
                                    color: AppColors.blue.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30.w,
                                      height: 30.w,
                                      decoration: BoxDecoration(
                                        color: AppFx.panelWash(0.22),
                                        borderRadius: BorderRadius.circular(12.r),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            sourceWarehouse.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.title.standardCopyWith(
                                              color: AppColors.textPrimary,
                                              fontSize: AppTypography.bodyLarge,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            sourceWarehouse.cityName ?? '-',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body.standardCopyWith(
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
                                  color: AppColors.borderGoldLight.withValues(alpha: 0.12),
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
                                    color: AppColors.green.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30.w,
                                      height: 30.w,
                                      decoration: BoxDecoration(
                                        color: AppFx.panelWash(0.22),
                                        borderRadius: BorderRadius.circular(12.r),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            (targetWarehouse['name'] ?? 'Depo').toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.title.standardCopyWith(
                                              color: AppColors.textPrimary,
                                              fontSize: AppTypography.bodyLarge,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            ((targetWarehouse['city'] as Map?)?['name'] ??
                                                    sourceWarehouse.cityName ??
                                                    '-')
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.body.standardCopyWith(
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
                                'Hedef Bos: ${_formatValue(remainingCapacity)} / ${_formatValue(availableCapacity)} m3',
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
                                final baseWidth =
                                    currentWidth.clamp(0.0, totalWidth - addedWidth);

                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (baseWidth > 0)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: baseWidth,
                                          decoration: BoxDecoration(
                                            color: projectedCapacityColor.withValues(
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
                          'Secilen Hacim: ${_formatValue(selectedVolume)} m3',
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
                    '${selectedItems.length} urun cesidi | $selectedQuantityTotal adet | ${_formatValue(selectedVolume)} m3 secildi',
                    style: AppTextStyles.body.standardCopyWith(
                      color: AppColors.textMuted,
                      fontSize: AppTypography.body,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.separated(
                      itemCount: slots.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10.h),
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
                              color: (isSelected
                                      ? AppColors.green
                                      : AppColors.borderGoldLight)
                                  .withValues(alpha: isSelected ? 0.35 : 0.15),
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
                                    color: (isSelected
                                            ? AppColors.green
                                            : AppFx.softOverlay(0.10))
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: slot.productIcon == null ||
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
                                      (slot.productName ?? 'Urun') +
                                          (slot.brandId != _defaultBrandId
                                              ? ' (${currentBrandName ?? 'Markali'})'
                                              : ''),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.title.standardCopyWith(
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
                                            style: AppTextStyles.caption.standardCopyWith(
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
                                          : 'Bu hedef icin max: $maxForSlot',
                                      style: AppTextStyles.caption.standardCopyWith(
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
                                    : () => openQuantityEditor(
                                          sheetContext,
                                          modalSetState,
                                          slot,
                                        ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isSelected
                                      ? AppColors.green
                                      : AppColors.goldLight,
                                  side: BorderSide(
                                    color: (isSelected
                                            ? AppColors.green
                                            : AppColors.gold)
                                        .withValues(alpha: 0.35),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: Text(
                                  isSelected
                                      ? 'Adet: $selectedQuantity'
                                      : 'Ekle',
                                  style: AppTextStyles.button.standardCopyWith(
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

  Future<void> _submitWarehouseOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    List<_SelectedWarehouseTransferItem> items,
    Map<String, dynamic> targetWarehouse,
    {
    String? vehicleId,
  }
  ) async {
    final targetWarehouseId = targetWarehouse['id']?.toString() ?? '';
    final sameCity =
        (targetWarehouse['city_id']?.toString() ?? '') ==
        sourceWarehouse.cityId;

    if (targetWarehouseId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hedef Gecersiz',
        message: 'Hedef depo bilgisi okunamadi.',
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
    final totalQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Center(child: AppLoadingIndicator(color: AppColors.gold)),
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
      final transferId = result['transfer_id']?.toString();
      final isInstant = result['mode']?.toString() == 'instant';

      if (isInstant && transferId != null && transferId.isNotEmpty) {
        final completionResult = await ref
            .read(warehouseActionProvider)
            .completeLogisticsTransfer(transferId);

        if (completionResult['success'] != true) {
          await _refreshWarehouseEcosystem();
          ref.invalidate(warehouseDetailProvider(targetWarehouseId));
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            title: 'Transfer Baslatildi',
            message:
                'Transfer kaydi olustu ama otomatik tamamlama sirasinda hata alindi: ${completionResult['message'] ?? 'Bilinmeyen hata'}',
            type: SnackbarType.warning,
          );
          return;
        }
      }

      await _refreshWarehouseEcosystem();
      ref.invalidate(warehouseDetailProvider(targetWarehouseId));
      await ref.read(warehouseDetailProvider(targetWarehouseId).future);

      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Transfer Basarili',
        message: isInstant
            ? '${items.length} urun cesidi, toplam $totalQuantity adet hedef depoya aktarildi.'
            : 'Depolar arasi transfer baslatildi. Arac yola cikti.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Transfer Basarisiz',
      message: result['message']?.toString() ?? 'Transfer baslatilamadi.',
      type: SnackbarType.error,
    );
  }

  Future<void> _toggleSaleStatus(
    BuildContext context,
    WidgetRef ref,
    WarehouseSlotModel slot,
  ) async {
    if (!slot.isAvailableForSale && slot.price <= 0) {
      AppSnackbar.show(
        context,
        title: 'Fiyat Gerekli',
        message: 'Once bu slot icin satis fiyati belirleyin.',
        type: SnackbarType.warning,
      );
      return;
    }

    final result = await ref
        .read(warehouseActionProvider)
        .setWarehouseSlotSaleStatus(
          warehouseSlotId: slot.id,
          isAvailableForSale: !slot.isAvailableForSale,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      ref
          .read(warehouseDetailProvider(widget.warehouseId).notifier)
          .patchSlotSaleStatus(
            slotId: slot.id,
            isAvailableForSale: !slot.isAvailableForSale,
          );
      ref
          .read(warehouseListProvider.notifier)
          .patchSlotSaleStatus(
            warehouseId: widget.warehouseId,
            slotId: slot.id,
            isAvailableForSale: !slot.isAvailableForSale,
          );
      final currentBrandName = ref.read(playerBrandCompanyProvider).value?.brandName;
      final productName = (slot.productName ?? 'Urun') + (slot.brandId != _defaultBrandId ? ' (${currentBrandName ?? 'Markali'})' : '');
      AppSnackbar.show(
        context,
        title: slot.isAvailableForSale ? 'Satis Kapatildi' : 'Satisa Acildi',
        message: slot.isAvailableForSale
            ? '$productName marketten kaldirildi.'
            : '$productName markette listeleniyor.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        title: 'Islem Basarisiz',
        message: result['message']?.toString() ?? 'Slot guncellenemedi.',
        type: SnackbarType.error,
      );
    }
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
            Icon(AppIcons.errorOutline, color: AppColors.red, size: AppIconSizes.displayLarge),
            SizedBox(height: 12.h),
            Text(
              'Depo detayi yuklenemedi.',
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

  String _formatTransferDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
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
    final upgradeCost = ((baseCost * 0.30) *
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
                'Her yukseltmede depo kapasitesi, tipin baslangic kapasitesi kadar artar.',
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
                      'Sure: $durationMinutes dk',
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
                            await _refreshWarehouseEcosystem();
                            if (!context.mounted) return;
                            FloatingFeedback.show(
                              context,
                              amount: upgradeCost,
                              type: FloatingFeedbackType.cashRemove,
                            );
                            AppSnackbar.show(
                              context,
                              title: 'Basarili',
                              message: 'Depo yukseltmesi baslatildi.',
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
                        label: const Text('Yukseltmeyi Baslat'),
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
      await _refreshWarehouseEcosystem();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Basarili',
        message: 'Depo yukseltmesi tamamlandi.',
        type: SnackbarType.success,
      );
      return;
    }

    AppSnackbar.show(
      context,
      title: 'Hata',
      message: result['message'] ?? 'Yukseltme tamamlanamadi.',
      type: SnackbarType.error,
    );
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
        title: 'Hedef Gecersiz',
        message: 'Hedef depo veya sehir bilgisi okunamadi.',
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
        title: 'Sehir Verisi Eksik',
        message: 'Mesafe hesabi icin sehir verileri okunamadi.',
        type: SnackbarType.error,
      );
      return;
    }

    final totalVolume = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.slot.unitVolume),
    );
    final TransferVehicleOptionsResult<MarketTransferVehicleOptionModel> vehicleResult;
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
        title: 'Arac Secim Hatasi',
        message: 'Arac secenekleri alinamadi: ${e.toString()}',
        type: SnackbarType.error,
      );
      return;
    }
    final options = vehicleResult.options;

    if (options.isEmpty) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        title: 'Arac Yok',
        message:
            vehicleResult.unavailableReason ??
            'Sehirler arasi transfer icin uygun arac bulunamadi.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Arac Secin',
              style: AppTextStyles.h1.standardCopyWith(
                color: AppColors.textPrimary,
                fontSize: AppTypography.headline,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '${sourceWarehouse.cityName ?? '-'} -> ${(targetWarehouse['city'] as Map?)?['name']?.toString() ?? '-'} | ${_formatValue(totalVolume)} m3',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodyLarge,
              ),
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
                    speedKmh: option.speedKmh,
                    distanceKm: option.distanceKm,
                    durationLabel: _formatTransferDuration(
                      option.estimatedDurationSeconds,
                    ),
                    transportCost: option.transportCost,
                    rentalCost: option.rentalCost,
                    fuelCost: option.fuelCost,
                    fuelNeeded: option.fuelNeeded,
                    conditionNeeded: option.conditionNeeded,
                    canSelect: option.canSelect,
                    isSelected: false,
                    disabledReason: option.disabledReason,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _submitWarehouseOutboundTransfer(
                        context,
                        ref,
                        sourceWarehouse,
                        items,
                        targetWarehouse,
                        vehicleId: option.vehicleId,
                      );
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
    required this.calculateStarCost,
    required this.formatCountdown,
  });

  final BuildingUpgradeModel upgrade;
  final Future<void> Function() onFinishWithGold;
  final int Function(DateTime finishAt) calculateStarCost;
  final String Function(Duration remaining) formatCountdown;

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
                side: BorderSide(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
                foregroundColor: AppColors.goldLight,
              ),
              onPressed: onFinishWithGold,
              icon: Icon(AppIcons.starRounded),
              label: Text(
                '${calculateStarCost(upgrade.finishAt)} yildiz ile bitir',
              ),
            ),
          ),
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
