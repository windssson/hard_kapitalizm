import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color? accentColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 18.h,
          decoration: BoxDecoration(
            color: accentColor ?? AppColors.gold,
            borderRadius: BorderRadius.circular(999.r),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleBold.standardCopyWith(fontSize: AppTypography.title),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle!,
                  style: AppTextStyles.caption.standardCopyWith(fontSize: AppTypography.label),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: 8.w),
          trailing!,
        ],
      ],
    );
  }
}

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: AppIconSizes.xSmall),
            SizedBox(width: 4.w),
          ],
          Text(
            text,
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class AppMetricTile extends StatelessWidget {
  const AppMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final metricColor = color ?? AppColors.gold;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: metricColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.16),
            blurRadius: 4.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.overline,
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.h2.standardCopyWith(
              color: metricColor,
              fontSize: AppTypography.titleLarge,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class AppEmptyStateCard extends StatelessWidget {
  const AppEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: AppDecorations.premiumCard(accentColor ?? AppColors.border, 16.r),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: AppIconSizes.xLarge),
          SizedBox(height: 10.h),
          Text(
            title,
            style: AppTextStyles.titleBold.standardCopyWith(fontSize: AppTypography.bodyLarge),
          ),
          SizedBox(height: 4.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.bodySmall),
          ),
        ],
      ),
    );
  }
}
