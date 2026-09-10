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
    String loadingMessage = 'Google AdMob ödüllü reklamı yükleniyor.',
    double? feedbackAmount,
    FloatingFeedbackType? feedbackType,
  }) async {
    final normalizedResourceId = resourceId?.trim() ?? '';
    if (normalizedResourceId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Reklam Hakkı Kullanılamıyor',
        message: 'Reklam ödülünün bağlı olduğu işlem bulunamadı.',
        type: SnackbarType.warning,
      );
      return false;
    }

    final eligibility = await _checkEligibility(
      rewardKind: rewardKind,
      resourceId: normalizedResourceId,
    );
    if (!context.mounted) return false;

    if (eligibility['allowed'] != true) {
      AppSnackbar.show(
        context,
        title: 'Reklam Hakkı Kullanılamıyor',
        message:
            eligibility['message']?.toString() ??
            'Reklam ödülü şu anda kullanılamıyor.',
        type: SnackbarType.warning,
      );
      return false;
    }

    final challenge = await _createChallenge(
      rewardKind: rewardKind,
      resourceId: normalizedResourceId,
    );
    if (!context.mounted) return false;

    if (challenge['success'] != true) {
      AppSnackbar.show(
        context,
        title: 'Reklam Doğrulaması Hazırlanamadı',
        message:
            challenge['message']?.toString() ??
            'Sunucu tarafı reklam doğrulaması başlatılamadı.',
        type: SnackbarType.warning,
      );
      return false;
    }

    final challengeId = challenge['challenge_id']?.toString() ?? '';
    final ssvUserId = challenge['user_id']?.toString() ?? '';
    final ssvCustomData = challenge['custom_data']?.toString() ?? '';
    if (challengeId.isEmpty || ssvUserId.isEmpty || ssvCustomData.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Reklam Doğrulaması Hazırlanamadı',
        message: 'Sunucu doğrulama bilgisi eksik döndü.',
        type: SnackbarType.error,
      );
      return false;
    }

    // A previous ad callback may already have verified this same open challenge.
    // In that case never force the player to watch a second ad.
    if (challenge['verified'] == true || challenge['status'] == 'verified') {
      return _applyVerifiedReward(
        context,
        onApplyAction: onApplyAction,
        successTitle: successTitle,
        successMessage: successMessage,
        feedbackAmount: feedbackAmount,
        feedbackType: feedbackType,
      );
    }

    AppSnackbar.show(
      context,
      title: 'Reklam Hazırlanıyor',
      message: loadingMessage,
      type: SnackbarType.info,
    );

    final adResult = await RewardedAdService.showAd(
      ssvUserId: ssvUserId,
      ssvCustomData: ssvCustomData,
    );
    if (!context.mounted) return false;

    if (!adResult.rewardEarned) {
      AppSnackbar.show(
        context,
        title: 'Ödül Alınamadı',
        message: adResult.message,
        type: SnackbarType.warning,
      );
      return false;
    }

    _showBlockingLoader(context);
    var loaderOpen = true;

    try {
      final verified = await _waitForServerVerification(challengeId);
      if (!context.mounted) return false;

      if (!verified) {
        if (loaderOpen) {
          Navigator.of(context).pop();
          loaderOpen = false;
        }
        AppSnackbar.show(
          context,
          title: 'Sunucu Doğrulaması Bekleniyor',
          message:
              'Reklam tamamlandı ancak Google doğrulaması henüz ulaşmadı. Birkaç saniye sonra aynı işlemi tekrar deneyin; yeniden reklam izlemeniz gerekmeyecek.',
          type: SnackbarType.warning,
        );
        return false;
      }

      final result = await onApplyAction();
      if (!context.mounted) return false;

      if (loaderOpen) {
        Navigator.of(context).pop();
        loaderOpen = false;
      }

      return _handleApplyResult(
        context,
        result: result,
        successTitle: successTitle,
        successMessage: successMessage,
        feedbackAmount: feedbackAmount,
        feedbackType: feedbackType,
      );
    } catch (e) {
      if (context.mounted && loaderOpen) {
        Navigator.of(context).pop();
        loaderOpen = false;
      }
      if (context.mounted) {
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

  static Future<bool> _applyVerifiedReward(
    BuildContext context, {
    required Future<Map<String, dynamic>> Function() onApplyAction,
    required String successTitle,
    required String successMessage,
    double? feedbackAmount,
    FloatingFeedbackType? feedbackType,
  }) async {
    _showBlockingLoader(context);
    var loaderOpen = true;

    try {
      final result = await onApplyAction();
      if (!context.mounted) return false;

      if (loaderOpen) {
        Navigator.of(context).pop();
        loaderOpen = false;
      }

      return _handleApplyResult(
        context,
        result: result,
        successTitle: successTitle,
        successMessage: successMessage,
        feedbackAmount: feedbackAmount,
        feedbackType: feedbackType,
      );
    } catch (e) {
      if (context.mounted && loaderOpen) {
        Navigator.of(context).pop();
        loaderOpen = false;
      }
      if (context.mounted) {
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

  static bool _handleApplyResult(
    BuildContext context, {
    required Map<String, dynamic> result,
    required String successTitle,
    required String successMessage,
    double? feedbackAmount,
    FloatingFeedbackType? feedbackType,
  }) {
    if (result['success'] == true) {
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
          ? ' Bugünkü kullanım: $dailyUsage/$dailyLimit.'
          : '';

      AppSnackbar.show(
        context,
        title: successTitle,
        message: '${result['message']?.toString() ?? successMessage}$usageText',
        type: SnackbarType.success,
      );
      return true;
    }

    AppSnackbar.show(
      context,
      title: 'İşlem Başarısız',
      message:
          result['message']?.toString() ?? 'Reklam ödülü uygulanamadı.',
      type: SnackbarType.error,
    );
    return false;
  }

  static void _showBlockingLoader(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(child: AppLoadingIndicator(color: AppColors.gold)),
      ),
    );
  }

  static Future<Map<String, dynamic>> _checkEligibility({
    required String rewardKind,
    required String resourceId,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      return {'allowed': false, 'message': 'Oturum açılmamış.'};
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
        'message': 'Reklam hakları kontrol edilemedi. Lütfen tekrar dene: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> _createChallenge({
    required String rewardKind,
    required String resourceId,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'message': 'Oturum açılmamış.'};
    }

    try {
      final response = await supabase.rpc(
        'create_rewarded_ad_challenge',
        params: {
          'p_reward_kind': rewardKind,
          'p_resource_id': resourceId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {
        'success': false,
        'message': 'Reklam doğrulaması hazırlanamadı: $e',
      };
    }
  }

  static Future<bool> _waitForServerVerification(String challengeId) async {
    final supabase = Supabase.instance.client;

    for (var attempt = 0; attempt < 20; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }

      try {
        final response = await supabase.rpc(
          'get_rewarded_ad_challenge_status',
          params: {'p_challenge_id': challengeId},
        );
        final status = Map<String, dynamic>.from(response as Map);
        if (status['success'] != true) return false;
        if (status['verified'] == true || status['status'] == 'verified') {
          return true;
        }
        if (status['status'] == 'expired' || status['status'] == 'rejected') {
          return false;
        }
      } catch (_) {
        // SSV callbacks can arrive a little later than the client reward event.
        // Retry briefly; the verified challenge remains reusable on the next UI attempt.
      }
    }

    return false;
  }
}
