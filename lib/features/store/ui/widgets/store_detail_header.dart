import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/store/models/store_model.dart';

class StoreDetailHeader extends StatelessWidget {
  final StoreModel store;
  final VoidCallback? onToggleActiveTap;
  final VoidCallback? onReportTap;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onSellTap;

  const StoreDetailHeader({
    super.key,
    required this.store,
    this.onToggleActiveTap,
    this.onReportTap,
    this.onHistoryTap,
    this.onSellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: AppDecorations.premiumCard(null, 24.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.cardBgLight.withValues(alpha: 0.6),
                  AppColors.cardBg,
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 2.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CachedAssetImage(
              fileName: store.storeType.icon,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: AppTextStyles.h2.standardCopyWith(
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.headline,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(
                      AppIcons.locationOn,
                      color: AppColors.textMuted,
                      size: AppIconSizes.small,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        store.cityName ?? 'Bilinmiyor',
                        style: AppTextStyles.body.standardCopyWith(
                          color: AppColors.textMuted,
                          fontSize: AppTypography.body,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Seviye ${store.level}',
                    style: AppTextStyles.caption.standardCopyWith(
                      color: AppColors.gold,
                      fontSize: AppTypography.label,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                  if (value == 'toggle_active') {
                    onToggleActiveTap?.call();
                  } else if (value == 'report') {
                    onReportTap?.call();
                  } else if (value == 'history') {
                    onHistoryTap?.call();
                  } else if (value == 'sell') {
                    onSellTap?.call();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'toggle_active',
                    child: _HeaderMenuItem(
                      icon: store.isActive
                          ? AppIcons.pauseCircleOutline
                          : AppIcons.playCircleOutline,
                      iconColor:
                          store.isActive ? AppColors.red : AppColors.green,
                      label: store.isActive ? 'Pasif Yap' : 'Aktif Yap',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'report',
                    child: _HeaderMenuItem(
                      icon: AppIcons.analyticsOutlined,
                      iconColor: AppColors.blue,
                      label: 'Raporu Ac',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'history',
                    child: _HeaderMenuItem(
                      icon: AppIcons.historyOutlined,
                      iconColor: AppColors.gold,
                      label: 'Gecmisi Ac',
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'sell',
                    child: _HeaderMenuItem(
                      icon: AppIcons.sellOutlined,
                      iconColor: AppColors.red,
                      label: 'Magazayi Sat',
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
              SizedBox(height: 12.h),
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: store.isActive ? AppColors.green : AppColors.red,
                  boxShadow: [
                    BoxShadow(
                      color: (store.isActive ? AppColors.green : AppColors.red)
                          .withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _HeaderMenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: AppIconSizes.regular),
        SizedBox(width: 8.w),
        Text(
          label,
          style: AppTextStyles.body.standardCopyWith(
            color: AppColors.textPrimary,
            fontSize: AppTypography.body,
          ),
        ),
      ],
    );
  }
}
