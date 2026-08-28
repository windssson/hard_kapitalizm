import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

class RewardedTimeReduceButton extends StatelessWidget {
  const RewardedTimeReduceButton({
    super.key,
    required this.onPressed,
    this.label = 'Reklam İzle -10 Dk',
    this.caption = 'Bir reklam ödülü al ve süreyi 10 dakika kısalt.',
    this.compact = false,
  });

  final VoidCallback onPressed;
  final String label;
  final String caption;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: compact ? null : double.infinity,
      height: 44.h,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
          backgroundColor: AppColors.gold.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        icon: Icon(
          AppIcons.playCircleFill,
          size: AppIconSizes.regular,
        ),
        label: Text(
          label,
          style: AppTextStyles.button.standardCopyWith(
            color: AppColors.gold,
            fontSize: AppTypography.bodyLarge,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    if (compact) {
      return button;
    }

    return Column(
      children: [
        button,
        SizedBox(height: 8.h),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.bodySmall,
          ),
        ),
      ],
    );
  }
}
