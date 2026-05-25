import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class StoreHeroHeader extends StatelessWidget {
  final StoreModel store;

  const StoreHeroHeader({super.key, required this.store});

  String _formatValue(dynamic amount) {
    if (amount == null) return '0';
    double val = double.parse(amount.toString());
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImmersiveHeader(),
        SizedBox(height: 16.h),
        _buildMetricsGrid(),
      ],
    );
  }

  Widget _buildImmersiveHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.background.withValues(alpha: 0.8),
            AppColors.navBg.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 2.w),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CachedAssetImage(fileName: store.storeType.icon, fit: BoxFit.contain),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        store.name,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: store.isActive ? AppColors.green : AppColors.red,
                        boxShadow: [
                          BoxShadow(
                            color: (store.isActive ? AppColors.green : AppColors.red).withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.textMuted, size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(store.cityName ?? 'Bilinmiyor', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                    SizedBox(width: 16.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('Seviye ${store.level}', style: AppTextStyles.body.copyWith(color: AppColors.gold, fontSize: 10.sp, fontWeight: FontWeight.bold)),
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

  Widget _buildMetricsGrid() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCompactMetricCol(
            title: 'Doluluk',
            value: '%${(store.summary.usedCapacityRatio * 100).toInt()}',
            icon: Icons.pie_chart,
            color: AppColors.goldDark,
          ),
          _buildCompactMetricCol(
            title: 'Stok',
            value: '${store.summary.totalQuantity}/${store.summary.totalCapacity}',
            icon: Icons.inventory_2,
            color: AppColors.blue,
          ),
          _buildCompactMetricCol(
            title: 'Kar',
            value: '+TL ${_formatValue(store.summary.totalStockSaleValue ?? 0)}',
            icon: Icons.trending_up,
            color: AppColors.green,
          ),
          _buildCompactMetricCol(
            title: 'Slot',
            value: '${store.slots.length}/${store.maxSlotCount}',
            icon: Icons.grid_view,
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricCol({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(height: 6.h),
        Text(value, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold), maxLines: 1),
        SizedBox(height: 2.h),
        Text(title, style: AppTextStyles.body.copyWith(color: AppColors.textMuted, fontSize: 9.sp), maxLines: 1),
      ],
    );
  }
}
