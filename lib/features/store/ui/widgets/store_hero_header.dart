import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class StoreHeroHeader extends StatelessWidget {
  final StoreModel store;

  const StoreHeroHeader({super.key, required this.store});



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
                        style: AppTextStyles.h2.standardCopyWith(
                          fontSize: AppTypography.displaySmall,
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
                    Icon(AppIcons.locationOn, color: AppColors.textMuted, size: AppIconSizes.small),
                    SizedBox(width: 4.w),
                    Text(store.cityName ?? 'Bilinmiyor', style: AppTextStyles.body.standardCopyWith(fontWeight: FontWeight.w500)),
                    SizedBox(width: 16.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Text('Seviye ${store.level}', style: AppTextStyles.body.standardCopyWith(color: AppColors.gold, fontSize: AppTypography.label, fontWeight: FontWeight.bold)),
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
        children: [
          _buildCompactMetricCol(
            title: 'Doluluk',
            value: '%${(store.summary.usedCapacityRatio * 100).toInt()}',
            icon: AppIcons.pieChart,
            color: AppColors.goldDark,
          ),
          _buildCompactMetricCol(
            title: 'Stok',
            value: '${store.summary.totalQuantity}/${store.summary.totalCapacity}',
            icon: AppIcons.inventory2,
            color: AppColors.blue,
          ),
          _buildCompactMetricCol(
            title: 'Stok Degeri',
            value: AppMoney.compact(store.summary.totalStockSaleValue ?? 0),
            icon: AppIcons.trendingUp,
            color: AppColors.green,
          ),
          _buildCompactMetricCol(
            title: 'Raf',
            value: '${store.slots.length}/${store.maxSlotCount}',
            icon: AppIcons.gridView,
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
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppIconSizes.medium),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: AppTypography.bodySmall,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: AppTextStyles.body.standardCopyWith(
              color: AppColors.textMuted,
              fontSize: AppTypography.caption,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
