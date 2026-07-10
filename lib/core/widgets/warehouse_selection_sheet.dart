import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class WarehouseSelectionOption {
  final String id;
  final String title;
  final String subtitle;
  final String? badgeText;
  final String? infoText;
  final bool isHighlightBadge;
  final VoidCallback onTap;

  WarehouseSelectionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.infoText,
    this.isHighlightBadge = false,
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
                // Options List
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
                            onTap: option.onTap,
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
                                        SizedBox(height: 5.h),
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
}
