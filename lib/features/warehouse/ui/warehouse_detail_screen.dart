import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/models/building_upgrade_model.dart';
import 'package:hard_kapitalizm/core/providers/time_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/branded_product_image.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/transfer_vehicle_option_card.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/market/data/market_provider.dart'
    show warehouseCapacityStatusProvider;
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/market/models/warehouse_capacity_status_model.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/widgets/warehouse_selection_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/product_selection_sheet.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';

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
    final currentBrandName = ref.watch(playerBrandCompanyProvider).value?.brandName;
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
      backgroundColor: Colors.transparent,
      floatingActionButton: warehouseAsync.maybeWhen(
        data: (warehouse) => FloatingActionButton.extended(
          onPressed: () => _showProductSelection(context, warehouse),
          backgroundColor: AppColors.gold,
          icon: const Icon(Icons.add_shopping_cart, color: Colors.black),
          label: const Text(
            'Urun Ekle',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
                          currentBrandName,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
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
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 11.sp,
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
    final listedSlots = filledSlots
        .where((slot) => slot.isAvailableForSale)
        .length;
    final totalQuantity = filledSlots.fold<int>(
      0,
      (sum, slot) => sum + slot.quantity,
    );
    final totalStock = totalQuantity.toDouble();
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
                      fileName: warehouse.typeIcon ?? 'warehouse.webp',
                      fit: BoxFit.contain,
                      errorWidget: Icon(
                        Icons.warehouse_outlined,
                        color: AppColors.gold,
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
                                warehouse.name,
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
                                'Depo / Lojistik',
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
                                      warehouse.cityName ?? '-',
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
          SizedBox(
            height: 74.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildHeaderMetricCard(
                  label: 'Dolu Slot',
                  value: filledSlots.length.toString(),
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.blue,
                ),
                _buildHeaderMetricCard(
                  label: 'Satistaki',
                  value: listedSlots.toString(),
                  icon: Icons.sell_outlined,
                  color: AppColors.green,
                ),
                _buildHeaderMetricCard(
                  label: 'Toplam Adet',
                  value: _formatValue(totalStock),
                  icon: Icons.layers_outlined,
                  color: AppColors.gold,
                ),
                _buildHeaderMetricCard(
                  label: 'Bos Kapasite',
                  value: _formatValue(availableCapacity),
                  icon: Icons.straighten,
                  color: AppColors.red,
                ),
              ],
            ),
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
                child: OutlinedButton.icon(
                  onPressed: activeUpgrade != null || hasAnotherActiveUpgrade
                      ? null
                      : () => _showWarehouseUpgradeSheet(
                            context,
                            ref,
                            warehouse,
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: activeUpgrade != null || hasAnotherActiveUpgrade
                        ? AppColors.textMuted
                        : AppColors.green,
                    side: BorderSide(
                      color: ((activeUpgrade != null || hasAnotherActiveUpgrade)
                              ? AppColors.textMuted
                              : AppColors.green)
                          .withValues(alpha: 0.35),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: const Icon(Icons.upgrade_rounded),
                  label: Text(
                    activeUpgrade != null
                        ? 'Devam Ediyor'
                        : hasAnotherActiveUpgrade
                        ? 'Baska Yukseltme Var'
                        : 'Yukselt',
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/warehouses/${warehouse.id}/history'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Kayitlar'),
                ),
              ),
            ],
          ),
        ],
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
        color: Colors.black.withValues(alpha: 0.16),
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
              Icon(Icons.straighten, color: AppColors.gold, size: 14.sp),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Kapasite Dagilimi',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${formatVolume(usedCapacity + reservedCapacity)}/${formatVolume(totalCapacity)}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.sp,
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
              color: Colors.white.withValues(alpha: 0.15),
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
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9.sp,
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
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeaderMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 110.w,
      margin: EdgeInsets.only(right: 10.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14.sp),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
    String? currentBrandName,
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
              Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 42.sp,
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
        return _buildSlotCard(context, ref, warehouse, slot);
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
      constraints: BoxConstraints(minHeight: 58.h),
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12.sp),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
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
                  style: TextStyle(
                    color: suffixColor ?? color,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
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
            style: TextStyle(
              color: color,
              fontSize: 9.sp,
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
                inactiveTrackColor: Colors.black26,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
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
          Icon(icon, color: color, size: 18.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13.sp,
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
        Icon(icon, size: 15.sp),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );

    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
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
  ) {
    final currentBrandName = ref.watch(playerBrandCompanyProvider).value?.brandName;
    if (slot.isEmpty) {
      return Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
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
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(
                Icons.add_circle_outline,
                color: AppColors.textMuted,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bos Slot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Bu slot su an bos. Urun ekleyebilirsiniz.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.sp,
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
                icon: Icons.add_shopping_cart_outlined,
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
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: slot.isAvailableForSale
                        ? AppColors.green.withValues(alpha: 0.32)
                        : Colors.white10,
                  ),
                ),
                child: BrandedProductImage(
                  fileName: slot.productIcon ?? 'default.webp',
                  brandName: _brandNameForSlot(slot, currentBrandName),
                  fit: BoxFit.contain,
                  showFrame: false,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.productName ?? 'Urun',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
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
                        Icons.more_vert,
                        color: AppColors.textMuted,
                        size: 22.sp,
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
                          icon: Icons.sell_outlined,
                          label: 'Fiyat Duzenle',
                          color: AppColors.gold,
                        ),
                        _buildSlotMenuItem(
                          value: 'market',
                          icon: Icons.storefront_outlined,
                          label: 'Pazardan Al',
                          color: Colors.white,
                        ),
                        _buildSlotMenuItem(
                          value: 'transfer',
                          icon: Icons.local_shipping_outlined,
                          label: 'Baska Depoya Gonder',
                          color: Colors.white,
                        ),
                        if (slot.quantity <= 0)
                          _buildSlotMenuItem(
                            value: 'delete',
                            icon: Icons.delete_outline,
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
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.blue,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSlotValueTile(
                  label: 'Maliyet',
                  value: slot.cost > 0 ? slot.cost.toStringAsFixed(1) : '-',
                  icon: Icons.payments_outlined,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildSlotValueTile(
                  label: 'Satis',
                  value: slot.price > 0 ? slot.price.toStringAsFixed(1) : '-',
                  suffix: marginPercent != null
                      ? '%${marginPercent.toStringAsFixed(0)}'
                      : null,
                  suffixColor: marginColor,
                  icon: Icons.sell_outlined,
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
      if (slot.cost > 0) ...[
        NumericKeyboardShortcut(
          label: 'Maliyet',
          value: priceShortcut(slot.cost),
        ),
        NumericKeyboardShortcut(
          label: 'Kar +%25',
          value: priceShortcut(slot.cost * 1.25),
        ),
        NumericKeyboardShortcut(
          label: 'Kar +%50',
          value: priceShortcut(slot.cost * 1.5),
        ),
      ],
    ];

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 680.h, maxWidth: 400.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Container(
                      width: 46.w,
                      height: 46.w,
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25),
                        ),
                      ),
                      child: BrandedProductImage(
                        fileName: slot.productIcon ?? 'default.webp',
                        brandName: _brandNameForSlot(slot, currentBrandName),
                        fit: BoxFit.contain,
                        showFrame: false,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satis Fiyati',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            slot.productName ?? 'Urun',
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
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              Padding(
                padding: EdgeInsets.all(16.w),
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
                            color: Colors.black.withValues(alpha: 0.3),
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
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                value.text.isEmpty ? '0.0' : value.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24.sp,
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
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: NumericKeyboard(
                  controller: controller,
                  allowDecimal: true,
                  shortcuts: shortcuts,
                  buttonHeight: 44.h,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16.w),
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
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.sp,
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
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 12.sp,
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
      AppSnackbar.show(
        context,
        title: 'Fiyat Guncellendi',
        message: '${slot.productName ?? 'Urun'} icin satis fiyati kaydedildi.',
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
            style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
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
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Text(
          'Bu bos depo slotunu silmek istediginize emin misiniz?',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14.sp),
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
              foregroundColor: Colors.white,
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
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
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
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: Text(
            slot.productName ?? 'Urun',
            style: TextStyle(color: Colors.white, fontSize: 16.sp),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kalite ${slot.qualityLevel} | Stok: ${slot.quantity}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Bu hedef icin maksimum: $effectiveLimit',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: controller,
                readOnly: true,
                showCursor: true,
                enableInteractiveSelection: false,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Miktar',
                  labelStyle: TextStyle(color: AppColors.gold),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.textMuted),
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
                      value:
                          ((effectiveLimit / 4).ceil().clamp(1, effectiveLimit))
                              .toString(),
                    ),
                  if (effectiveLimit > 0)
                    NumericKeyboardShortcut(
                      label: 'Yari',
                      value:
                          ((effectiveLimit / 2).ceil().clamp(1, effectiveLimit))
                              .toString(),
                    ),
                  if (effectiveLimit > 0)
                    NumericKeyboardShortcut(
                      label: 'Tamami',
                      value: effectiveLimit.toString(),
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
            if (currentQuantity > 0)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 0),
                child: const Text('Kaldir'),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
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
              child: const Text(
                'Kaydet',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
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
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${(targetWarehouse['name'] ?? 'Depo').toString()} | Bos: ${_formatValue(remainingCapacity)} / ${_formatValue(availableCapacity)} m3',
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${selectedItems.length} urun cesidi | $selectedQuantityTotal adet | ${_formatValue(selectedVolume)} m3 secildi',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.sp,
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
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
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
                                width: 48.w,
                                height: 48.w,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: slot.productIcon == null ||
                                        slot.productIcon!.isEmpty
                                    ? Icon(
                                        Icons.inventory_2_outlined,
                                        color: AppColors.gold,
                                        size: 22.sp,
                                      )
                                    : BrandedProductImage(
                                        fileName: slot.productIcon!,
                                        brandName: _brandNameForSlot(
                                          slot,
                                          currentBrandName,
                                        ),
                                        fit: BoxFit.contain,
                                        showFrame: false,
                                      ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot.productName ?? 'Urun',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Kalite ${slot.qualityLevel} | Stok ${slot.quantity} | Birim ${_formatValue(slot.unitVolume)} m3',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      isDisabled
                                          ? 'Kapasite dolu'
                                          : 'Bu hedef icin max: $maxForSlot',
                                      style: TextStyle(
                                        color: isDisabled
                                            ? AppColors.red
                                            : AppColors.goldLight,
                                        fontSize: 10.sp,
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
                        foregroundColor: Colors.black,
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
                      icon: const Icon(Icons.local_shipping_outlined),
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
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
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
      AppSnackbar.show(
        context,
        title: slot.isAvailableForSale ? 'Satis Kapatildi' : 'Satisa Acildi',
        message: slot.isAvailableForSale
            ? '${slot.productName ?? 'Urun'} marketten kaldirildi.'
            : '${slot.productName ?? 'Urun'} markette listeleniyor.',
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
            isFilled ? Icons.star : Icons.star_border,
            color: isFilled ? AppColors.gold : AppColors.textMuted,
            size: 11.sp,
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
            Icon(Icons.error_outline, color: AppColors.red, size: 42.sp),
            SizedBox(height: 12.h),
            Text(
              'Depo detayi yuklenemedi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
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
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Her yukseltmede depo kapasitesi, tipin baslangic kapasitesi kadar artar.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.sp,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 16.h),
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
                      'Seviye ${warehouse.level} -> $targetLevel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Kapasite: ${_formatValue(warehouse.capacity)} -> ${_formatValue(warehouse.capacity + baseCapacity)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Artis: +${_formatValue(baseCapacity)} m3',
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
                      'Maliyet: ${upgradeCost.toStringAsFixed(0)} TL',
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
                              .read(warehouseActionProvider)
                              .startWarehouseUpgrade(
                                warehouse.id,
                                syncProviders: false,
                              );

                          if (!context.mounted) return;

                          if (result['success'] == true) {
                            await _refreshWarehouseEcosystem();
                            if (!context.mounted) return;
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
                        icon: const Icon(Icons.upgrade_rounded),
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
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '${sourceWarehouse.cityName ?? '-'} -> ${(targetWarehouse['city'] as Map?)?['name']?.toString() ?? '-'} | ${_formatValue(totalVolume)} m3',
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
                      'Depo Yukseltmesi Devam Ediyor',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Seviye ${upgrade.currentLevel} -> ${upgrade.targetLevel} | Kapasite ${_formatCapacity(upgrade.previousCapacity)} -> ${_formatCapacity(upgrade.nextCapacity)}',
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

  String _formatCapacity(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
