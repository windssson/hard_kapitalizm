import 'package:flutter/material.dart';
import 'package:hard_kapitalizm/core/ads/rewarded_ad_action_flow.dart';
import 'package:hard_kapitalizm/core/ads/transfer_finish_rewarded_ad_service.dart';
import 'package:hard_kapitalizm/core/widgets/floating_feedback.dart';

class RewardedTimeReductionFlow {
  static Future<bool> run(
    BuildContext context, {
    required Future<Map<String, dynamic>> Function() onApplyReduction,
    required String rewardKind,
    required String resourceId,
    required String successMessage,
    String loadingMessage = 'Google AdMob test reklamı yükleniyor.',
  }) async {
    return RewardedAdActionFlow.run(
      context,
      onApplyAction: onApplyReduction,
      rewardKind: rewardKind,
      resourceId: resourceId,
      successTitle: 'Süre Kısaltıldı',
      successMessage: successMessage,
      loadingMessage: loadingMessage,
      feedbackAmount: RewardedAdService.timeReductionPerAd.inMinutes.toDouble(),
      feedbackType: FloatingFeedbackType.timeReduce,
    );
  }
}
