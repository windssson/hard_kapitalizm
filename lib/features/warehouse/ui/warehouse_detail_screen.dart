import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/models/warehouse_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/widgets/product_selection_dialog.dart';

class WarehouseDetailScreen extends ConsumerWidget {
  final String warehouseId;

  const WarehouseDetailScreen({super.key, required this.warehouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouseAsync = ref.watch(warehouseDetailProvider(warehouseId));
    final playerAsync = ref.watch(playerStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: warehouseAsync.maybeWhen(
        data: (warehouse) => FloatingActionButton.extended(
          onPressed: () => _showProductSelection(context, warehouse),
          backgroundColor: AppColors.gold,
          icon: const Icon(Icons.add_shopping_cart, color: Colors.black),
          label: const Text('Ürün Ekle', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
        orElse: () => null,
      ),
      body: SafeArea(
        child: warehouseAsync.when(
          data: (warehouse) => Column(
            children: [
              SecondaryTopBar(title: '${warehouse.name} Yönetimi'),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(warehouseDetailProvider(warehouseId).future),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
                        _buildMainStats(warehouse),
                        SizedBox(height: 24.h),
                        _buildSlotGrid(warehouse),
                        SizedBox(height: 80.h), // FAB için boşluk
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          error: (error, stack) => Center(child: Text('Hata: $error', style: TextStyle(color: AppColors.red))),
        ),
      ),
    );
  }

  void _showProductSelection(BuildContext context, WarehouseModel warehouse) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSelectionDialog(warehouse: warehouse),
    );
  }

  Widget _buildMainStats(WarehouseModel warehouse) {
    final double ratio = warehouse.capacity > 0 
        ? (warehouse.reservedCapacity / warehouse.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70.w,
                height: 70.w,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(15.r),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                child: CachedAssetImage(
                  fileName: warehouse.typeIcon ?? 'warehouse.webp', 
                  fit: BoxFit.contain
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBox('Şehir', warehouse.cityName ?? '-', Icons.location_city, Colors.blueAccent),
                    _buildStatBox('Seviye', warehouse.level.toString(), Icons.trending_up, AppColors.gold),
                    _buildStatBox('Durum', warehouse.isActive ? 'Aktif' : 'Pasif', Icons.power, AppColors.green),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildCapacityIndicator(ratio, warehouse.reservedCapacity, warehouse.capacity),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.7), size: 18.sp),
        SizedBox(height: 4.h),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 9.sp)),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCapacityIndicator(double ratio, double used, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Depo Doluluğu', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w500)),
            Text('${_formatValue(used)} / ${_formatValue(total)} m³', 
              style: TextStyle(color: AppColors.gold, fontSize: 12.sp, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 8.h),
        Stack(
          children: [
            Container(
              height: 12.h,
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6.r)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 12.h,
              width: (1.sw - 64.w) * ratio,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gold, AppColors.gold.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(6.r),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 4)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSlotGrid(WarehouseModel warehouse) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
      ),
      itemCount: warehouse.slots.length,
      itemBuilder: (context, index) {
        final slot = warehouse.slots[index];
        return _buildSlotCard(slot);
      },
    );
  }

  Widget _buildSlotCard(WarehouseSlotModel slot) {
    if (slot.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.3), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.textMuted.withValues(alpha: 0.5), size: 32.sp),
            SizedBox(height: 8.h),
            Text('Boş Slot', style: TextStyle(color: AppColors.textMuted, fontSize: 12.sp)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(12.w),
              child: Center(
                child: CachedAssetImage(fileName: slot.productIcon ?? 'default', fit: BoxFit.contain),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQualityStars(slot.qualityLevel),
                    Text('${slot.quantity}', style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('Stok Miktarı', style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityStars(int quality) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < quality;
        return Icon(
          isFilled ? Icons.star : Icons.star_border,
          color: isFilled ? AppColors.gold : AppColors.textMuted,
          size: 10.sp,
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
