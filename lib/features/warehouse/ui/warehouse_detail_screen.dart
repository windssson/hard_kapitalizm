import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/numeric_keyboard.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final warehouseAsync = ref.watch(
      warehouseDetailProvider(widget.warehouseId),
    );

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
                        _buildHeaderCard(warehouse),
                        SizedBox(height: 18.h),
                        _buildSectionHeader(warehouse),
                        SizedBox(height: 10.h),
                        _buildSlotList(context, ref, warehouse),
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
    ref.invalidate(warehouseDetailProvider(widget.warehouseId));
    ref.invalidate(warehouseListProvider);
    await ref.read(warehouseDetailProvider(widget.warehouseId).future);
  }

  void _showProductSelection(
    BuildContext context,
    WarehouseModel warehouse,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      final allProducts = await ref.read(allProductsProvider.future);
      final typeDetail = await ref.read(
        warehouseTypeDetailProvider(warehouse.warehouseTypeId).future,
      );

      if (context.mounted) Navigator.pop(context);

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
          subtitle: 'Birim Hacim: ${product.birimHacim} m³',
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
        title: 'Deponun Alabildiği Ürünler',
        options: options,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
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

  Widget _buildHeaderCard(WarehouseModel warehouse) {
    final filledSlots = warehouse.slots.where((slot) => !slot.isEmpty).toList();
    final listedSlots = filledSlots
        .where((slot) => slot.isAvailableForSale)
        .length;
    final totalQuantity = filledSlots.fold<int>(
      0,
      (sum, slot) => sum + slot.quantity,
    );
    final totalStock = totalQuantity.toDouble();
    final reserved = warehouse.reservedCapacity;
    final capacity = warehouse.capacity;
    final availableCapacity = (capacity - reserved).clamp(0.0, capacity);
    final averageQuality = filledSlots.isEmpty
        ? 0.0
        : filledSlots.fold<int>(0, (sum, slot) => sum + slot.qualityLevel) /
              filledSlots.length;
    final stockRatio = capacity > 0
        ? (totalStock / capacity).clamp(0.0, 1.0)
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
                _buildHeaderMetricCard(
                  label: 'Ort. Kalite',
                  value: averageQuality <= 0
                      ? '-'
                      : averageQuality.toStringAsFixed(1),
                  icon: Icons.star_outline,
                  color: AppColors.goldLight,
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  'Stok',
                  '${_formatValue(totalStock)}/${_formatValue(capacity)}',
                  AppColors.blue,
                  ratio: stockRatio,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildHeroStat(
                  'Rezerve',
                  '${_formatValue(reserved)}/${_formatValue(capacity)}',
                  AppColors.gold,
                  ratio: reserveRatio,
                  icon: Icons.lock_outline,
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
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 16.sp),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(WarehouseModel warehouse) {
    final filledSlots = warehouse.slots.where((slot) => !slot.isEmpty).toList();
    final emptyCount = warehouse.slots.length - filledSlots.length;
    return _buildSectionTitle(
      'Satis Slotlari',
      subtitle:
          'Dolu: ${filledSlots.length} | Bos: $emptyCount | Toplam: ${warehouse.slots.length}',
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

  Widget _buildSlotMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
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

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.premiumCard(
        slot.isAvailableForSale ? AppColors.green : null,
        18.r,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Icon, Name, Quality
          SizedBox(
            width: 76.w,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 58.w,
                  height: 58.w,
                  padding: EdgeInsets.all(9.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: slot.isAvailableForSale
                          ? AppColors.green.withValues(alpha: 0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: CachedAssetImage(
                    fileName: slot.productIcon ?? 'default',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  slot.productName ?? 'Urun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                _buildQualityStars(slot.qualityLevel),
              ],
            ),
          ),
          SizedBox(width: 12.w),

          // Middle Side: Chips and other elements
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTag(
                      slot.isAvailableForSale ? 'SATISTA' : 'BEKLEMEDE',
                      slot.isAvailableForSale
                          ? AppColors.green
                          : AppColors.textMuted,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 24.h,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Switch(
                              value: slot.isAvailableForSale,
                              activeColor: AppColors.green,
                              inactiveThumbColor: AppColors.textMuted,
                              inactiveTrackColor: Colors.black26,
                              onChanged: (_) =>
                                  _toggleSaleStatus(context, ref, slot),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        SizedBox(
                          height: 24.h,
                          width: 24.h,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_vert,
                              color: AppColors.textMuted,
                              size: 20.sp,
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
                              } else if (value == 'delete') {
                                _deleteWarehouseSlot(context, ref, slot);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'market',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.storefront_outlined,
                                      color: Colors.white,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Pazar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'transfer',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      color: Colors.white,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Depoya',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (slot.quantity <= 0)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: AppColors.red,
                                        size: 18.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'Sil',
                                        style: TextStyle(
                                          color: AppColors.red,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _buildSlotMetricChip(
                      icon: Icons.inventory_2,
                      label: 'Stok: ${slot.quantity}',
                      color: AppColors.blue,
                    ),
                    _buildSlotMetricChip(
                      icon: Icons.payments_outlined,
                      label: 'Maliyet ${slot.cost.toStringAsFixed(1)}',
                      color: AppColors.textMuted,
                    ),
                    GestureDetector(
                      onTap: () => _showPriceDialog(context, ref, slot),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sell_outlined,
                              color: AppColors.gold,
                              size: 12.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              slot.price > 0
                                  ? 'Fiyat ${slot.price.toStringAsFixed(1)}'
                                  : 'Fiyat yok',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.edit,
                              color: AppColors.gold,
                              size: 12.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (marginPercent != null)
                      _buildSlotMetricChip(
                        icon: Icons.trending_up,
                        label: '%${marginPercent.toStringAsFixed(0)}',
                        color: slot.price >= slot.cost
                            ? AppColors.green
                            : AppColors.red,
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

  Future<void> _showPriceDialog(
    BuildContext context,
    WidgetRef ref,
    WarehouseSlotModel slot,
  ) async {
    final controller = TextEditingController(
      text: slot.price > 0 ? slot.price.toStringAsFixed(1) : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 500.h,
            maxWidth: 400.w,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(16.w),
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
                    SizedBox(height: 8.h),
                    Text(
                      slot.productName ?? 'Urun',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: Colors.white.withValues(alpha: 0.1),
                height: 1,
              ),
              // Price Display
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Birim Satis Fiyati',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 11.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => Text(
                          value.text.isEmpty ? '0' : value.text,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Keyboard
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: NumericKeyboard(controller: controller),
              ),
              // Cost info
              if (slot.cost > 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Text(
                    'Maliyet: ${slot.cost.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              // Action Buttons
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
                          final parsed = double.tryParse(
                            controller.text.trim().replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) {
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
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
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

    if (result == null || !context.mounted) return;

    final actionResult = await ref.read(warehouseActionProvider).updateWarehouseSlotPrice(
          warehouseSlotId: slot.id,
          price: result,
        );

    if (!context.mounted) return;

    if (actionResult['success'] == true) {
      await _refreshWarehouse(ref);
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
      await _refreshWarehouse(ref);
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
    WarehouseSlotModel slot,
  ) async {
    if (slot.quantity <= 0) {
      AppSnackbar.show(
        context,
        title: 'Stok Yok',
        message: 'Gonderilecek stok bulunmuyor.',
        type: SnackbarType.warning,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    List<Map<String, dynamic>> warehouses = const [];
    try {
      warehouses = await ref
          .read(warehouseActionProvider)
          .getPlayerActiveWarehousesBasic();
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

    final candidates = warehouses
        .where((item) => item['id']?.toString() != warehouse.id)
        .toList();

    if (candidates.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hedef Depo Yok',
        message: 'Transfer icin baska aktif deponuz bulunmuyor.',
        type: SnackbarType.info,
      );
      return;
    }

    if (!context.mounted) return;
    _showWarehouseTargetPicker(context, ref, warehouse, slot, candidates);
  }

  void _showWarehouseTargetPicker(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    WarehouseSlotModel slot,
    List<Map<String, dynamic>> warehouses,
  ) {
    final options = warehouses.map((target) {
      final cityName = ((target['city'] as Map?)?['name'] ?? '-').toString();
      final sameCity = target['city_id']?.toString() == sourceWarehouse.cityId;

      return WarehouseSelectionOption(
        id: target['id'].toString(),
        title: (target['name'] ?? 'Depo').toString(),
        subtitle: '$cityName | Seviye: ${target['level'] ?? 1}',
        badgeText: sameCity ? 'Aynı Şehir' : 'Şehirler Arası',
        infoText: sameCity ? 'Anlık' : 'Lojistik',
        isHighlightBadge: sameCity,
        onTap: () {
          Navigator.pop(context);
          _showWarehouseOutboundQuantityDialog(
            context,
            ref,
            sourceWarehouse,
            slot,
            target,
            cityName,
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

  void _showWarehouseOutboundQuantityDialog(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    WarehouseSlotModel slot,
    Map<String, dynamic> targetWarehouse,
    String targetCityName,
  ) {
    final controller = TextEditingController(text: '1');
    final limit = slot.quantity;
    final isSameCity =
        (targetWarehouse['city_id']?.toString() ?? '') ==
        sourceWarehouse.cityId;

    void applyQuantity(int value, void Function(void Function()) setState) {
      final clamped = value.clamp(1, limit);
      setState(() {
        controller.text = clamped.toString();
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      });
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          insetPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 24.h),
          title: Text(
            'Miktar Girin',
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
                        slot.productName ?? 'Urun',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${sourceWarehouse.name} -> ${(targetWarehouse['name'] ?? 'Depo').toString()}',
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
                          _buildStatusPill(
                            isSameCity ? 'Ayni sehir' : 'Sehirler arasi',
                            isSameCity ? AppColors.green : AppColors.blue,
                          ),
                          _buildStatusPill(
                            'Hedef: $targetCityName',
                            AppColors.gold,
                          ),
                          _buildStatusPill(
                            'Maksimum $limit',
                            AppColors.goldLight,
                          ),
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
                  decoration: const InputDecoration(
                    labelText: 'Miktar',
                    helperText: 'Diger depoya gonderilecek urun adedi',
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
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _buildQuickQuantityButton(
                      '1/4',
                      () => applyQuantity((limit / 4).ceil(), setState),
                    ),
                    _buildQuickQuantityButton(
                      'Yari',
                      () => applyQuantity((limit / 2).ceil(), setState),
                    ),
                    _buildQuickQuantityButton(
                      'Tamami',
                      () => applyQuantity(limit, setState),
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
                  AppSnackbar.show(
                    context,
                    title: 'Gecersiz Miktar',
                    message: '1 ile $limit arasinda bir miktar girin.',
                    type: SnackbarType.warning,
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                _maybeStartWarehouseOutboundTransfer(
                  context,
                  ref,
                  sourceWarehouse,
                  slot,
                  targetWarehouse,
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
      ),
    );
  }

  Future<void> _maybeStartWarehouseOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel sourceWarehouse,
    WarehouseSlotModel slot,
    Map<String, dynamic> targetWarehouse,
    int quantity,
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

    if (sameCity) {
      await _startWarehouseOutboundTransfer(
        context,
        ref,
        slot,
        targetWarehouseId,
        quantity,
        null,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>
    vehicleResult = const TransferVehicleOptionsResult(
      options: [],
      unavailableReason: null,
    );
    try {
      vehicleResult = await ref
          .read(warehouseActionProvider)
          .getWarehouseToWarehouseVehicleOptions(
            warehouseSlotId: slot.id,
            buyerWarehouseId: targetWarehouseId,
            quantity: quantity,
          );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Araclar Alinamadi',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context);

    if (vehicleResult.options.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Arac Yok',
        message:
            vehicleResult.unavailableReason ??
            'Bu transfer icin uygun arac bulunamadi.',
        type: SnackbarType.warning,
      );
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
                color: AppColors.textPrimary,
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
                itemCount: vehicleResult.options.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, index) {
                  final option = vehicleResult.options[index];
                  final color = option.canSelect
                      ? AppColors.green
                      : AppColors.red;
                  return InkWell(
                    onTap: option.canSelect
                        ? () {
                            Navigator.pop(sheetContext);
                            _startWarehouseOutboundTransfer(
                              context,
                              ref,
                              slot,
                              targetWarehouseId,
                              quantity,
                              option.vehicleId,
                            );
                          }
                        : null,
                    borderRadius: BorderRadius.circular(14.r),
                    child: Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: color.withValues(alpha: 0.35),
                        ),
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
                                    color: AppColors.textPrimary,
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
                            'Kapasite: ${option.capacity} | Mesafe: ${option.distanceKm.toStringAsFixed(0)} km | Sure: ${_formatTransferDuration(option.estimatedDurationSeconds)}',
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

  Future<void> _startWarehouseOutboundTransfer(
    BuildContext context,
    WidgetRef ref,
    WarehouseSlotModel slot,
    String targetWarehouseId,
    int quantity,
    String? vehicleId,
  ) async {
    final result = await ref
        .read(warehouseActionProvider)
        .startWarehouseToWarehouseTransfer(
          warehouseSlotId: slot.id,
          buyerWarehouseId: targetWarehouseId,
          quantity: quantity,
          vehicleId: vehicleId,
        );

    if (!context.mounted) return;

    if (result['success'] == true) {
      await _refreshWarehouse(ref);
      ref.invalidate(warehouseListProvider);
      ref.invalidate(warehouseDetailProvider(targetWarehouseId));
      ref.invalidate(playerProvider);
      final isInstant = result['mode']?.toString() == 'instant';
      AppSnackbar.show(
        context,
        title: 'Transfer Basarili',
        message: isInstant
            ? '${slot.productName ?? 'Urun'} hedef depoya aninda ulasti.'
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
      await _refreshWarehouse(ref);
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

  String _formatValue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
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

  String _formatTransferDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${duration.inMinutes}dk';
  }
}
