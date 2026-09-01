import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_error_message.dart';
import 'package:hard_kapitalizm/core/utils/app_haptic.dart';
import 'package:hard_kapitalizm/core/widgets/in_game_notification_banner.dart';

enum SnackbarType { success, error, info, warning }

class AppSnackbar {
  /// Global context kullanarak snackbar / toast gösterme (rootNavigatorKey üzerinden)
  static void showGlobal({
    required String message,
    String? title,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
    IconData? customIcon,
    bool playHaptic = true,
  }) {
    _showInternal(
      context: null,
      message: message,
      title: title,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      customIcon: customIcon,
      playHaptic: playHaptic,
    );
  }

  /// Genel snackbar / toast gösterimi (Tüm uygulama genelinde üstten kayan birleşik kart)
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
    _showInternal(
      context: context,
      message: message,
      title: title,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      customIcon: customIcon,
      playHaptic: playHaptic,
    );
  }

  static void _showInternal({
    BuildContext? context,
    required String message,
    String? title,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    IconData? customIcon,
    bool playHaptic = true,
  }) {
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

    Color mainColor;
    IconData defaultIcon;
    String defaultTitle;

    switch (type) {
      case SnackbarType.success:
        mainColor = AppColors.green;
        defaultIcon = AppIcons.checkCircleOutline;
        defaultTitle = 'Başarılı';
        break;
      case SnackbarType.error:
        mainColor = AppColors.red;
        defaultIcon = AppIcons.errorOutline;
        defaultTitle = 'Hata';
        break;
      case SnackbarType.warning:
        mainColor = AppColors.warning;
        defaultIcon = AppIcons.warningAmberRounded;
        defaultTitle = 'Uyarı';
        break;
      case SnackbarType.info:
        mainColor = AppColors.gold;
        defaultIcon = AppIcons.infoOutline;
        defaultTitle = 'Bilgi';
        break;
    }

    final effectiveIcon = customIcon ?? defaultIcon;
    final effectiveTitle = title ?? defaultTitle;

    InGameToastManager.show(
      InGameToastData(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: effectiveTitle,
        message: displayMessage,
        categoryLabel: defaultTitle.toUpperCase(),
        icon: effectiveIcon,
        color: mainColor,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
      context: context,
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

  /// Aktif toast veya snackbar'ı kapatır
  static void hide() {
    InGameToastManager.hide();
  }

  static void _debugLog({
    required SnackbarType type,
    required String? title,
    required String rawMessage,
    required String displayMessage,
  }) {
    final tag = switch (type) {
      SnackbarType.success => '[SNACKBAR][SUCCESS]',
      SnackbarType.error => '[SNACKBAR][ERROR]',
      SnackbarType.warning => '[SNACKBAR][WARNING]',
      SnackbarType.info => '[SNACKBAR][INFO]',
    };

    final titlePart = (title == null || title.trim().isEmpty)
        ? ''
        : ' title="$title"';

    debugPrint(
      '$tag$titlePart message="$displayMessage"'
      '${rawMessage != displayMessage ? ' raw="$rawMessage"' : ''}',
    );
  }
}
