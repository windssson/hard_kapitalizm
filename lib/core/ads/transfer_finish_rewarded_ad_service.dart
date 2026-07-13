import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdResult {
  const RewardedAdResult({
    required this.rewardEarned,
    required this.message,
  });

  final bool rewardEarned;
  final String message;
}

class RewardedAdService {
  static const Duration timeReductionPerAd = Duration(minutes: 10);

  static String? get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544~3347511713';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544~1458002511';
    }
    return null;
  }

  static String? get _rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return null;
  }

  static Future<RewardedAdResult> showAd() async {
    final adUnitId = _rewardedAdUnitId;
    if (adUnitId == null) {
      return const RewardedAdResult(
        rewardEarned: false,
        message: 'Bu platformda odullu reklam desteklenmiyor.',
      );
    }

    final completer = Completer<RewardedAdResult>();

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var rewardEarned = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(
                  RewardedAdResult(
                    rewardEarned: rewardEarned,
                    message: rewardEarned
                        ? 'Reklam odulu alindi.'
                        : 'Odul almak icin reklami kapanana kadar izlemeniz gerekiyor.',
                  ),
                );
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!completer.isCompleted) {
                completer.complete(
                  RewardedAdResult(
                    rewardEarned: false,
                    message:
                        'Reklam gosterilemedi. Lutfen birazdan tekrar deneyin. (${error.code})',
                  ),
                );
              }
            },
          );

          ad.show(
            onUserEarnedReward: (ad, rewardItem) {
              rewardEarned = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) {
            completer.complete(
              RewardedAdResult(
                rewardEarned: false,
                message:
                    'Test reklami su anda yuklenemedi. Lutfen internet baglantinizi kontrol edip tekrar deneyin. (${error.code})',
              ),
            );
          }
        },
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => const RewardedAdResult(
        rewardEarned: false,
        message: 'Reklam yaniti zamaninda gelmedi. Lutfen tekrar deneyin.',
      ),
    );
  }
}

typedef TransferFinishRewardedAdResult = RewardedAdResult;

class TransferFinishRewardedAdService {
  static const Duration maxEligibleRemaining = Duration(minutes: 10);

  static String? get appId => RewardedAdService.appId;

  static Future<TransferFinishRewardedAdResult> showAd() {
    return RewardedAdService.showAd();
  }
}
