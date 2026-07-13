import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/core/ads/transfer_finish_rewarded_ad_service.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';

class RewardedTimeReductionFlow {
  static Future<bool> run(
    BuildContext context, {
    required Future<Map<String, dynamic>> Function() onApplyReduction,
    required String successMessage,
    String loadingMessage = 'Google AdMob test reklami yukleniyor.',
  }) async {
    AppSnackbar.show(
      context,
      title: 'Test Reklami Hazirlaniyor',
      message: loadingMessage,
      type: SnackbarType.info,
    );

    final adResult = await RewardedAdService.showAd();
    if (!context.mounted) return false;

    if (!adResult.rewardEarned) {
      AppSnackbar.show(
        context,
        title: 'Odul Alinamadi',
        message: adResult.message,
        type: SnackbarType.warning,
      );
      return false;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: AppLoadingIndicator(color: AppColors.gold),
      ),
    );

    try {
      final result = await onApplyReduction();

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (result['success'] == true) {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            title: 'Sure Kisaltildi',
            message: successMessage,
            type: SnackbarType.success,
          );
        }
        return true;
      }

      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Islem Basarisiz',
          message: result['message']?.toString() ?? 'Sure kisaltma uygulanamadi.',
          type: SnackbarType.error,
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
      return false;
    }
  }
}
