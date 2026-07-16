import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  static const Duration boostDurationPerAd = Duration(minutes: 30);
  static bool _requestInFlight = false;

  static String? get appId {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544~3347511713';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544~1458002511';
    }
    return null;
  }

  static String? get _rewardedAdUnitId {
    if (kIsWeb) return null;
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    }
    return null;
  }

  static Future<RewardedAdResult> showAd() async {
    if (_requestInFlight) {
      return const RewardedAdResult(
        rewardEarned: false,
        message: 'Baska bir reklam islemi zaten devam ediyor.',
      );
    }

    final adUnitId = _rewardedAdUnitId;
    if (adUnitId == null) {
      return const RewardedAdResult(
        rewardEarned: false,
        message: 'Bu platformda odullu reklam desteklenmiyor.',
      );
    }

    _requestInFlight = true;
    final completer = Completer<RewardedAdResult>();
    RewardedAd? loadedAd;
    var isDisposed = false;

    void disposeAd() {
      if (isDisposed) return;
      isDisposed = true;
      loadedAd?.dispose();
      loadedAd = null;
    }

    void completeIfNeeded(RewardedAdResult result) {
      if (completer.isCompleted) return;
      completer.complete(result);
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (completer.isCompleted) {
            ad.dispose();
            return;
          }

          loadedAd = ad;
          var rewardEarned = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              disposeAd();
              completeIfNeeded(
                RewardedAdResult(
                  rewardEarned: rewardEarned,
                  message: rewardEarned
                      ? 'Reklam odulu alindi.'
                      : 'Odul almak icin reklami kapanana kadar izlemeniz gerekiyor.',
                ),
              );
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              disposeAd();
              completeIfNeeded(
                RewardedAdResult(
                  rewardEarned: false,
                  message:
                      'Reklam gosterilemedi. Lutfen birazdan tekrar deneyin. (${error.code})',
                ),
              );
            },
          );

          ad.show(
            onUserEarnedReward: (ad, rewardItem) {
              rewardEarned = true;
            },
          );
        },
        onAdFailedToLoad: (error) {
          completeIfNeeded(
            RewardedAdResult(
              rewardEarned: false,
              message:
                  'Test reklami su anda yuklenemedi. Lutfen internet baglantinizi kontrol edip tekrar deneyin. (${error.code})',
            ),
          );
        },
      ),
    );

    try {
      return await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          disposeAd();
          return const RewardedAdResult(
            rewardEarned: false,
            message: 'Reklam yaniti zamaninda gelmedi. Lutfen tekrar deneyin.',
          );
        },
      );
    } finally {
      disposeAd();
      _requestInFlight = false;
    }
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
