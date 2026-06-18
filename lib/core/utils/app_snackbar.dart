import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_error_message.dart';

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
    final displayMessage =
        type == SnackbarType.error ? sanitizeUserFacingError(message) : message;

    _debugLog(
      type: type,
      title: title,
      rawMessage: message,
      displayMessage: displayMessage,
    );

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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardBg.withValues(alpha: 0.95),
                AppColors.cardBgLight.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: mainColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: mainColor.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 6.w,
                    decoration: BoxDecoration(
                      color: mainColor,
                      boxShadow: [
                        BoxShadow(
                          color: mainColor,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: mainColor, size: 24.sp),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 4.w,
                      ),
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
                            displayMessage,
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
                  IconButton(
                    onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white24,
                      size: 18.sp,
                    ),
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

  static void _debugLog({
    required SnackbarType type,
    required String rawMessage,
    required String displayMessage,
    String? title,
  }) {
    final typeLabel = type.name.toUpperCase();
    final titleLabel = title == null || title.trim().isEmpty
        ? ''
        : ' [$title]';

    debugPrint('[SNACKBAR][$typeLabel]$titleLabel shown="$displayMessage"');

    if (rawMessage != displayMessage) {
      debugPrint('[SNACKBAR][$typeLabel]$titleLabel raw="$rawMessage"');
    }
  }
}
