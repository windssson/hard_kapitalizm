import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_error_message.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';

enum SnackbarType { success, error, info, warning }

class AppSnackbar {
  /// Genel snackbar gösterimi
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    IconData? customIcon,
    bool playHaptic = true,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final displayMessage =
        type == SnackbarType.error ? sanitizeUserFacingError(message) : message;

    if (playHaptic) {
      switch (type) {
        case SnackbarType.success:
          AppHaptic.medium();
          break;
        case SnackbarType.error:
          AppHaptic.heavy();
          break;
        case SnackbarType.warning:
          AppHaptic.medium();
          break;
        case SnackbarType.info:
          AppHaptic.light();
          break;
      }
    }

    _debugLog(
      type: type,
      title: title,
      rawMessage: message,
      displayMessage: displayMessage,
    );

    scaffoldMessenger.hideCurrentSnackBar();

    Color mainColor;
    IconData defaultIcon;
    String defaultTitle;

    switch (type) {
      case SnackbarType.success:
        mainColor = AppColors.green;
        defaultIcon = AppIcons.checkCircleOutline;
        defaultTitle = 'BAŞARILI';
        break;
      case SnackbarType.error:
        mainColor = AppColors.red;
        defaultIcon = AppIcons.errorOutline;
        defaultTitle = 'HATA';
        break;
      case SnackbarType.warning:
        mainColor = AppColors.warning;
        defaultIcon = AppIcons.warningAmberRounded;
        defaultTitle = 'UYARI';
        break;
      case SnackbarType.info:
        mainColor = AppColors.gold;
        defaultIcon = AppIcons.infoOutline;
        defaultTitle = 'BİLGİ';
        break;
    }

    final effectiveIcon = customIcon ?? defaultIcon;
    final effectiveTitle = title ?? defaultTitle;

    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: AppColors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.only(
          bottom: 18.h,
          left: 14.w,
          right: 14.w,
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.cardBg.withValues(alpha: 0.96),
                    AppColors.cardBgLight.withValues(alpha: 0.90),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: mainColor.withValues(alpha: 0.45),
                  width: 1.2.w,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: mainColor.withValues(alpha: 0.16),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sol durum vurgu çizgisi (Pillar)
                    Container(
                      width: 5.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            mainColor,
                            mainColor.withValues(alpha: 0.5),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: mainColor.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 12.w),

                    // İkon Rozeti
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: mainColor.withValues(alpha: 0.3),
                            width: 1.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: mainColor.withValues(alpha: 0.12),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          effectiveIcon,
                          color: mainColor,
                          size: 20.sp,
                        ),
                      ),
                    ),

                    SizedBox(width: 12.w),

                    // Metin Gövdesi
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 2.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Başlık rozeti
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6.w,
                                  height: 6.w,
                                  decoration: BoxDecoration(
                                    color: mainColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: mainColor,
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  effectiveTitle.toUpperCase(),
                                  style: AppTextStyles.label.standardCopyWith(
                                    color: mainColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            // Mesaj
                            Text(
                              displayMessage,
                              style: AppTextStyles.body.standardCopyWith(
                                color: AppColors.textPrimary,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Opsiyonel Aksiyon Butonu
                    if (actionLabel != null && onAction != null) ...[
                      Center(
                        child: TextButton(
                          onPressed: () {
                            scaffoldMessenger.hideCurrentSnackBar();
                            onAction();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            backgroundColor: mainColor.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              side: BorderSide(
                                color: mainColor.withValues(alpha: 0.4),
                                width: 1.w,
                              ),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: AppTextStyles.label.standardCopyWith(
                              color: mainColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                    ],

                    // Kapatma Butonu
                    Center(
                      child: IconButton(
                        onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
                        icon: Icon(
                          AppIcons.close,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          size: 18.sp,
                        ),
                        splashRadius: 16,
                        tooltip: 'Kapat',
                      ),
                    ),
                    SizedBox(width: 4.w),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Başarı Snackbar Yardımcısı
  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Hata Snackbar Yardımcısı
  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Uyarı Snackbar Yardımcısı
  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Bilgi Snackbar Yardımcısı
  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title,
      type: SnackbarType.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
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

