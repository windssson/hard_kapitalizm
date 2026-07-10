import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

/// Oyun genelinde tutarlı "X ⭐ ile Bitir" butonu.
/// Tüm inşaat ve araştırma ekranlarında kullanılır.
class GoldFinishButton extends StatelessWidget {
  final int starCost;
  final VoidCallback? onPressed;

  const GoldFinishButton({super.key, required this.starCost, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: AppButtonStyles.primary(
          backgroundColor: AppColors.goldDark,
          foregroundColor: AppColors.white,
          borderColor: AppColors.gold.withValues(alpha: 0.6),
        ),
        icon: Icon(
          AppIcons.starRounded,
          size: AppIconSizes.regular,
          color: AppColors.gold,
        ),
        label: Text(
          '$starCost ile Bitir',
          style: AppTextStyles.button.standardCopyWith(
            fontSize: AppTypography.bodyLarge,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnAccent,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
