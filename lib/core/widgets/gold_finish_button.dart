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
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB8860B),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(
              color: AppColors.gold.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
        ),
        icon: Icon(Icons.star_rounded, size: 18.sp, color: AppColors.gold),
        label: Text(
          '$starCost ile Bitir',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
