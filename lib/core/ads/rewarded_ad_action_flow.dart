import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/core/ads/transfer_finish_rewarded_ad_service.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RewardedAdActionFlow {
  static Future<bool> run(
    BuildContext context, {
    required Future<Map<String, dynamic>> Function() onApplyAction,
    required String rewardKind,
    required String successTitle,
    required String successMessage,
    String? resourceId,
    String loadingMessage = 'Google AdMob test reklami yukleniyor.',
    double? feedbackAmount,
    FloatingFeedbackType? feedbackType,
  }) async {
    final eligibility = await _checkEligibility(
      rewardKind: rewardKind,
      resourceId: resourceId,
    );
    if (!context.mounted) return false;

    if (eligibility['allowed'] != true) {
      AppSnackbar.show(
        context,
        title: 'Reklam Hakki Kullanilamiyor',
        message:
            eligibility['message']?.toString() ??
            'Reklam odulu su anda kullanilamiyor.',
        type: SnackbarType.warning,
      );
      return false;
    }

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
      builder: (context) => PopScope(
        canPop: false,
        child: Center(child: AppLoadingIndicator(color: AppColors.gold)),
      ),
    );

    try {
      final result = await onApplyAction();

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (result['success'] == true) {
        if (context.mounted) {
          final appliedAmount =
              (result['time_reduced_minutes'] as num?)?.toDouble() ??
              feedbackAmount;
          if (appliedAmount != null && feedbackType != null) {
            FloatingFeedback.show(
              context,
              amount: appliedAmount,
              type: feedbackType,
            );
          }
          final dailyUsage = (result['reward_daily_usage'] as num?)?.toInt();
          final dailyLimit = (result['reward_daily_limit'] as num?)?.toInt();
          final usageText = dailyUsage != null && dailyLimit != null
              ? ' Bugunku kullanim: $dailyUsage/$dailyLimit.'
              : '';
          AppSnackbar.show(
            context,
            title: successTitle,
            message:
                '${result['message']?.toString() ?? successMessage}$usageText',
            type: SnackbarType.success,
          );
        }
        return true;
      }

      if (context.mounted) {
        AppSnackbar.show(
          context,
          title: 'Islem Basarisiz',
          message:
              result['message']?.toString() ?? 'Reklam odulu uygulanamadi.',
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

  static Future<Map<String, dynamic>> _checkEligibility({
    required String rewardKind,
    String? resourceId,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      return {'allowed': false, 'message': 'Oturum acilmamis.'};
    }

    try {
      final response = await supabase.rpc(
        'get_rewarded_ad_reward_status',
        params: {
          'p_player_id': user.id,
          'p_reward_kind': rewardKind,
          'p_resource_id': resourceId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'allowed': false,
        'message': 'Reklam haklari kontrol edilemedi. Lutfen tekrar dene: $e',
      };
    }
  }
}
