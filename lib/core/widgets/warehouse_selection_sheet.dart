import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';

class WarehouseSelectionProductPreview {
  final String icon;
  final double quantity;
  final int quality;

  WarehouseSelectionProductPreview({
    required this.icon,
    required this.quantity,
    required this.quality,
  });
}

class WarehouseSelectionOption {
  final String id;
  final String title;
  final String subtitle;
  final String? badgeText;
  final String? infoText;
  final bool isHighlightBadge;
  final double? capacityRatio;
  final String? capacityLabel;
  final String? distanceLabel;
  final String? durationLabel;
  final List<WarehouseSelectionProductPreview>? productPreviews;
  final VoidCallback onTap;

  WarehouseSelectionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.infoText,
    this.isHighlightBadge = false,
    this.capacityRatio,
    this.capacityLabel,
    this.distanceLabel,
    this.durationLabel,
    this.productPreviews,
    required this.onTap,
  });
}

class WarehouseSelectionSheet extends StatelessWidget {
  final String title;
  final List<WarehouseSelectionOption> options;

  const WarehouseSelectionSheet({
    super.key,
    required this.title,
    required this.options,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<WarehouseSelectionOption> options,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      barrierColor: AppFx.scrim(),
      builder: (sheetContext) => WarehouseSelectionSheet(
        title: title,
        options: options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: AppDecorations.panelGlass(24.r),
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notch Indicator
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.15),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.goldLight,
                        fontSize: AppTypography.headline,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(AppIcons.close, color: AppColors.textMuted),
                      style: IconButton.styleFrom(
                        backgroundColor: AppFx.softOverlay(0.05),
                        padding: EdgeInsets.all(6.w),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                if (options.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: AppFx.softOverlay(0.04),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: AppColors.borderGoldLight.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AppIcons.warehouseOutlined,
                            color: AppColors.gold,
                            size: 36.r,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Uygun Depo Bulunamadı',
                          style: AppTextStyles.title.standardCopyWith(
                            color: AppColors.white,
                            fontSize: AppTypography.title,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Bu işlem için uygun veya aktif bir deponuz bulunmuyor. Depo satın almak veya inşa etmek için Depolar ekranına gidebilirsiniz.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.bodySmall,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.black,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              context.go('/warehouses');
                            },
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('Depolara Git'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        
                        // Staggered Entrance Animation
                        return TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: Duration(milliseconds: 260 + (index * 45)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, (1 - value) * 20.h),
                              child: Opacity(
                                opacity: value.clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: Material(
                            color: AppColors.transparent,
                            child: InkWell(
                              onTap: () {
                                AppHaptic.light();
                                option.onTap();
                              },
                              borderRadius: BorderRadius.circular(16.r),
                              child: Container(
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: option.isHighlightBadge
                                        ? [
                                            AppColors.green.withValues(alpha: 0.08),
                                            AppFx.softOverlay(0.01),
                                          ]
                                        : [
                                            AppFx.softOverlay(0.04),
                                            AppFx.softOverlay(0.01),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: option.isHighlightBadge
                                        ? AppColors.green.withValues(alpha: 0.45)
                                        : AppColors.borderGoldLight.withValues(alpha: 0.15),
                                    width: 1.2.w,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: option.isHighlightBadge
                                          ? AppColors.green.withValues(alpha: 0.05)
                                          : AppFx.shadow(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Warehouse Icon Container
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: AppFx.panelWash(0.45),
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(
                                          color: (option.isHighlightBadge ? AppColors.green : AppColors.gold)
                                              .withValues(alpha: 0.35),
                                          width: 1.2.w,
                                        ),
                                      ),
                                      child: Icon(
                                        AppIcons.warehouseOutlined,
                                        color: option.isHighlightBadge ? AppColors.green : AppColors.gold,
                                        size: AppIconSizes.medium,
                                      ),
                                    ),
                                    SizedBox(width: 14.w),
                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            option.title,
                                            style: AppTextStyles.title.standardCopyWith(
                                              color: AppColors.white,
                                              fontSize: AppTypography.bodyLarge,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              Icon(
                                                AppIcons.locationOnOutlined,
                                                color: AppColors.textMuted,
                                                size: AppIconSizes.xSmall,
                                              ),
                                              SizedBox(width: 4.w),
                                              Expanded(
                                                child: Text(
                                                  option.subtitle,
                                                  style: AppTextStyles.body.standardCopyWith(
                                                    color: AppColors.textMuted,
                                                    fontSize: AppTypography.bodySmall,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // 2. Capacity Status Bar (Doluluk Oranı)
                                          if (option.capacityRatio != null) ...[
                                            SizedBox(height: 8.h),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(999.r),
                                                    child: LinearProgressIndicator(
                                                      value: option.capacityRatio!.clamp(0.0, 1.0),
                                                      minHeight: 3.h,
                                                      backgroundColor: AppFx.softOverlay(0.08),
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        option.capacityRatio! > 0.85
                                                            ? AppColors.danger
                                                            : option.capacityRatio! > 0.65
                                                                ? AppColors.warning
                                                                : AppColors.green,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 8.w),
                                                Text(
                                                  option.capacityLabel ??
                                                      '${(option.capacityRatio! * 100).toStringAsFixed(0)}%',
                                                  style: AppTextStyles.caption.standardCopyWith(
                                                    color: option.capacityRatio! > 0.85
                                                        ? AppColors.danger
                                                        : AppColors.textMuted,
                                                    fontSize: 9.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          // 2.5 Product Previews (Ürün Önizlemeleri)
                                          if (option.productPreviews != null && option.productPreviews!.isNotEmpty) ...[
                                            SizedBox(height: 8.h),
                                            SizedBox(
                                              height: 22.h,
                                              child: ListView.separated(
                                                scrollDirection: Axis.horizontal,
                                                shrinkWrap: true,
                                                itemCount: option.productPreviews!.length,
                                                separatorBuilder: (context, index) => SizedBox(width: 6.w),
                                                itemBuilder: (context, idx) {
                                                  final preview = option.productPreviews![idx];
                                                  return Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                    decoration: BoxDecoration(
                                                      color: AppFx.softOverlay(0.06),
                                                      borderRadius: BorderRadius.circular(6.r),
                                                      border: Border.all(
                                                        color: AppColors.borderGoldLight.withValues(alpha: 0.15),
                                                        width: 0.8.w,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        CachedAssetImage(
                                                          fileName: preview.icon.isNotEmpty ? preview.icon : 'default.webp',
                                                          width: 12.w,
                                                          height: 12.w,
                                                          fit: BoxFit.contain,
                                                        ),
                                                        SizedBox(width: 4.w),
                                                        Text(
                                                          _formatPreviewQuantity(preview.quantity),
                                                          style: AppTextStyles.caption.standardCopyWith(
                                                            color: AppColors.white,
                                                            fontSize: 8.sp,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        if (preview.quality > 0) ...[
                                                          SizedBox(width: 2.w),
                                                          Text(
                                                            '⭐${preview.quality}',
                                                            style: AppTextStyles.caption.standardCopyWith(
                                                              color: AppColors.gold,
                                                              fontSize: 7.sp,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                          // 3. Logistics and Distance details (Lojistik/Mesafe İkonları)
                                          if (option.distanceLabel != null || option.durationLabel != null) ...[
                                            SizedBox(height: 6.h),
                                            Row(
                                              children: [
                                                if (option.distanceLabel != null) ...[
                                                  Icon(
                                                    AppIcons.localShippingRounded,
                                                    size: 11.sp,
                                                    color: AppColors.goldLight.withValues(alpha: 0.7),
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    option.distanceLabel!,
                                                    style: AppTextStyles.caption.standardCopyWith(
                                                      color: AppColors.textMuted,
                                                      fontSize: 9.sp,
                                                    ),
                                                  ),
                                                  if (option.durationLabel != null) SizedBox(width: 10.w),
                                                ],
                                                if (option.durationLabel != null) ...[
                                                  Icon(
                                                    AppIcons.accessTime,
                                                    size: 11.sp,
                                                    color: AppColors.goldLight.withValues(alpha: 0.7),
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    option.durationLabel!,
                                                    style: AppTextStyles.caption.standardCopyWith(
                                                      color: AppColors.textMuted,
                                                      fontSize: 9.sp,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    // Badge / Info Text
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (option.badgeText != null)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: (option.isHighlightBadge ? AppColors.green : AppColors.gold)
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8.r),
                                              border: Border.all(
                                                color: (option.isHighlightBadge ? AppColors.green : AppColors.gold)
                                                    .withValues(alpha: 0.35),
                                                width: 1.w,
                                              ),
                                            ),
                                            child: Text(
                                              option.badgeText!,
                                              style: AppTextStyles.label.standardCopyWith(
                                                color: option.isHighlightBadge ? AppColors.green : AppColors.goldLight,
                                                fontSize: AppTypography.label,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (option.infoText != null) ...[
                                          if (option.badgeText != null) SizedBox(height: 6.h),
                                          ConstrainedBox(
                                            constraints: BoxConstraints(maxWidth: 120.w),
                                            child: Text(
                                              option.infoText!,
                                              textAlign: TextAlign.end,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.caption.standardCopyWith(
                                                color: AppColors.goldLight,
                                                fontSize: AppTypography.label,
                                                fontWeight: FontWeight.w700,
                                                height: 1.15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPreviewQuantity(double qty) {
    if (qty >= 1000000) {
      return '${(qty / 1000000).toStringAsFixed(1)}M';
    } else if (qty >= 1000) {
      return '${(qty / 1000).toStringAsFixed(1)}k';
    } else {
      return qty.toStringAsFixed(0);
    }
  }
}
