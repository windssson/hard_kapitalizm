import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';

enum SnackbarType { success, error, info, warning }

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Varsa eski snackbar'ı kapat
    scaffoldMessenger.hideCurrentSnackBar();

    Color mainColor;
    IconData icon;

    switch (type) {
      case SnackbarType.success:
        mainColor = AppColors.green;
        icon = Icons.check_circle_outline;
        break;
      case SnackbarType.error:
        mainColor = AppColors.red;
        icon = Icons.error_outline;
        break;
      case SnackbarType.warning:
        mainColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case SnackbarType.info:
      default:
        mainColor = AppColors.gold;
        icon = Icons.info_outline;
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        content: Container(
          margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: mainColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: mainColor.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Sol renk çubuğu
                  Container(
                    width: 6.w,
                    decoration: BoxDecoration(
                      color: mainColor,
                      boxShadow: [
                        BoxShadow(color: mainColor, blurRadius: 10, spreadRadius: 1),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // İkon
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: mainColor, size: 24.sp),
                  ),
                  SizedBox(width: 16.w),
                  // Metin alanı
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title.toUpperCase(),
                              style: TextStyle(
                                color: mainColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          Text(
                            message,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Kapat butonu
                  IconButton(
                    onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
                    icon: Icon(Icons.close, color: Colors.white24, size: 18.sp),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
