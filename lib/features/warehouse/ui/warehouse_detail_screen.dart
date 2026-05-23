import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/widgets/product_selection_dialog.dart';

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
    _refreshOnEntry();
  }

  void _refreshOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(warehouseDetailProvider(widget.warehouseId));
      ref.read(warehouseDetailProvider(widget.warehouseId).future);
    });
  }

  @override
  Widget build(BuildContext context) {
    final warehouseAsync = ref.watch(warehouseDetailProvider(widget.warehouseId));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: warehouseAsync.maybeWhen(
        data: (warehouse) => FloatingActionButton.extended(
          onPressed: () => _showProductSelection(context, warehouse),
          backgroundColor: AppColors.gold,
          icon: const Icon(Icons.add_shopping_cart, color: Colors.black),
          label: const Text(
            'Urun Ekle',
            style: TextStyle(
              color: Colors.black,
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
              SecondaryTopBar(title: '${warehouse.name} Yonetimi'),
              Expanded(
                child: RefreshIndicator(
          onRefresh: () => _refreshWarehouse(ref),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 96.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(warehouse),
                        SizedBox(height: 18.h),
                        _buildSectionTitle('Satis Slotlari'),
                        SizedBox(height: 10.h),
                        _buildSlotGrid(context, ref, warehouse),
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
          error: (error, stack) => Center(
            child: Text(
              'Hata: $error',
              style: const TextStyle(color: AppColors.red),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshWarehouse(WidgetRef ref) async {
    ref.invalidate(warehouseDetailProvider(widget.warehouseId));
    ref.invalidate(warehouseListProvider);
    await ref.read(warehouseDetailProvider(widget.warehouseId).future);
  }

  void _showProductSelection(BuildContext context, WarehouseModel warehouse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSelectionDialog(warehouse: warehouse),
    );
  }

  Widget _buildHeaderCard(WarehouseModel warehouse) {
    final double totalStock = warehouse.slots.fold(0.0, (sum, slot) => sum + slot.quantity);
    final double reserved = warehouse.reservedCapacity;
    final double capacity = warehouse.capacity;

    final double stockRatio = capacity > 0 ? (totalStock / capacity).clamp(0.0, 1.0) : 0.0;
    final double usedRatio = capacity > 0 ? ((totalStock + reserved) / capacity).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBg.withValues(alpha: 0.8),
            AppColors.background.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.borderGoldLight.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80.w,
                height: 80.w,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: CachedAssetImage(
                  fileName: warehouse.typeIcon ?? 'warehouse.webp',
                  fit: BoxFit.contain,
                  errorWidget: Icon(
                    Icons.store,
                    color: AppColors.green,
                    size: 36.sp,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
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
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.gold, size: 14.sp),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            '${warehouse.cityName ?? '-'} | Seviye ${warehouse.level}',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _buildTag(
                          warehouse.isActive ? 'AKTIF' : 'PASIF',
                          warehouse.isActive ? AppColors.green : AppColors.red,
                        ),
                        _buildTag(
                          'KAPASİTE: ${_formatValue(warehouse.capacity)}',
                          AppColors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Stok',
                          style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                        ),
                        SizedBox(width: 12.w),
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Rezerve',
                          style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                        ),
                      ],
                    ),
                    Text(
                      '${_formatValue(totalStock + reserved)} / ${_formatValue(capacity)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Container(
                  height: 12.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: usedRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(999.r),
                            boxShadow: [
                              BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 4)
                            ],
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: stockRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            borderRadius: BorderRadius.circular(999.r),
                            boxShadow: [
                              BoxShadow(color: AppColors.blue.withValues(alpha: 0.5), blurRadius: 4)
                            ],
                          ),
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
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSlotGrid(
    BuildContext context,
    WidgetRef ref,
    WarehouseModel warehouse,
  ) {
    if (warehouse.slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 42.sp),
            SizedBox(height: 12.h),
            Text(
              'Bu depoda henuz urun yok.',
              style: AppTextStyles.body,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: warehouse.slots.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final slot = warehouse.slots[index];
        return _buildSlotCard(context, ref, slot);
      },
    );
  }

  Widget _buildSlotCard(
    BuildContext context,
    WidgetRef ref,
    WarehouseSlotModel slot,
  ) {
    if (slot.isEmpty) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMuted.withValues(alpha: 0.6),
              size: 28.sp,
            ),
            SizedBox(width: 12.w),
            Text(
              'Bos Slot',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: slot.isAvailableForSale
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.3),
        ),
        boxShadow: slot.isAvailableForSale ? [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ] : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12.r),
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
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.productName ?? 'Urun',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          _buildQualityStars(slot.qualityLevel),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2, color: AppColors.blue, size: 14.sp),
                          SizedBox(width: 4.w),
                          Text(
                            '${slot.quantity}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Maliyet: ${slot.cost.toStringAsFixed(1)}₺',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
                    ),
                    InkWell(
                      onTap: () => _showPriceDialog(context, ref, slot),
                      borderRadius: BorderRadius.circular(6.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (slot.price > 0 && slot.cost > 0) ...[
                              Text(
                                '%${(((slot.price - slot.cost) / slot.cost) * 100).toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: slot.price >= slot.cost ? AppColors.green : AppColors.red,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                width: 1.w,
                                height: 12.h,
                                color: AppColors.gold.withValues(alpha: 0.3),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Text(
                              slot.price > 0 ? '${slot.price.toStringAsFixed(1)}₺' : 'Fiyat Yok',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(Icons.edit, color: AppColors.gold, size: 12.sp),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Satis Durumu',
                      style: TextStyle(
                        color: slot.isAvailableForSale ? AppColors.green : AppColors.textMuted,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    SizedBox(
                      height: 24.h,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Switch(
                          value: slot.isAvailableForSale,
                          activeColor: AppColors.green,
                          inactiveThumbColor: AppColors.textMuted,
                          inactiveTrackColor: Colors.black26,
                          onChanged: (val) => _toggleSaleStatus(context, ref, slot),
                        ),
                      ),
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: Text(
          'Satis Fiyati',
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.productName ?? 'Urun',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Birim satis fiyati',
                labelStyle: const TextStyle(color: AppColors.gold),
                hintText: slot.cost > 0
                    ? 'Maliyet: ${slot.cost.toStringAsFixed(1)}'
                    : null,
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (parsed == null || parsed <= 0) {
                AppSnackbar.show(
                  dialogContext,
                  title: 'Gecersiz Fiyat',
                  message: 'Satis fiyati 0 buyuk olmali.',
                  type: SnackbarType.error,
                );
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Kaydet'),
          ),
        ],
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

    final result = await ref.read(warehouseActionProvider).setWarehouseSlotSaleStatus(
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

  String _formatValue(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }
}
