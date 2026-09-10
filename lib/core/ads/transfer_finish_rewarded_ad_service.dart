import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  static const String _androidTestAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String _iosTestAppId =
      'ca-app-pub-3940256099942544~1458002511';
  static const String _androidTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  static bool _requestInFlight = false;

  static String? _envValue(String key) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String? get appId {
    if (kIsWeb) return null;

    if (Platform.isAndroid) {
      if (kDebugMode) return _androidTestAppId;
      final value = _envValue('ADMOB_ANDROID_APP_ID');
      if (value == null || value == _androidTestAppId) return null;
      return value;
    }

    if (Platform.isIOS) {
      if (kDebugMode) return _iosTestAppId;
      final value = _envValue('ADMOB_IOS_APP_ID');
      if (value == null || value == _iosTestAppId) return null;
      return value;
    }

    return null;
  }

  static String? get _rewardedAdUnitId {
    if (kIsWeb) return null;

    if (Platform.isAndroid) {
      if (kDebugMode) return _androidTestRewardedId;
      final value = _envValue('ADMOB_ANDROID_REWARDED_ID');
      if (value == null || value == _androidTestRewardedId) return null;
      return value;
    }

    if (Platform.isIOS) {
      if (kDebugMode) return _iosTestRewardedId;
      final value = _envValue('ADMOB_IOS_REWARDED_ID');
      if (value == null || value == _iosTestRewardedId) return null;
      return value;
    }

    return null;
  }

  static bool get usingTestAds {
    if (kIsWeb) return false;
    if (!kDebugMode) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<RewardedAdResult> showAd({
    required String ssvUserId,
    required String ssvCustomData,
  }) async {
    if (_requestInFlight) {
      return const RewardedAdResult(
        rewardEarned: false,
        message: 'Başka bir reklam işlemi zaten devam ediyor.',
      );
    }

    if (ssvUserId.trim().isEmpty || ssvCustomData.trim().isEmpty) {
      return const RewardedAdResult(
        rewardEarned: false,
        message: 'Reklam sunucu doğrulama bilgisi eksik.',
      );
    }

    final adUnitId = _rewardedAdUnitId;
    if (adUnitId == null) {
      return const RewardedAdResult(
        rewardEarned: false,
        message:
            'Ödüllü reklam production yapılandırması eksik. AdMob App/Rewarded ID ayarlarını kontrol edin.',
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
        onAdLoaded: (ad) async {
          if (completer.isCompleted) {
            ad.dispose();
            return;
          }

          loadedAd = ad;

          try {
            await ad.setServerSideOptions(
              ServerSideVerificationOptions(
                userId: ssvUserId,
                customData: ssvCustomData,
              ),
            );
          } catch (error) {
            disposeAd();
            completeIfNeeded(
              RewardedAdResult(
                rewardEarned: false,
                message: 'Reklam sunucu doğrulaması hazırlanamadı: $error',
              ),
            );
            return;
          }

          var rewardEarned = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              disposeAd();
              completeIfNeeded(
                RewardedAdResult(
                  rewardEarned: rewardEarned,
                  message: rewardEarned
                      ? 'Reklam tamamlandı. Sunucu doğrulaması bekleniyor.'
                      : 'Ödül almak için reklamı kapanana kadar izlemeniz gerekiyor.',
                ),
              );
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              disposeAd();
              completeIfNeeded(
                RewardedAdResult(
                  rewardEarned: false,
                  message:
                      'Reklam gösterilemedi. Lütfen birazdan tekrar deneyin. (${error.code})',
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
                  'Ödüllü reklam şu anda yüklenemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin. (${error.code})',
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
            message: 'Reklam yanıtı zamanında gelmedi. Lütfen tekrar deneyin.',
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

  static Future<TransferFinishRewardedAdResult> showAd({
    required String ssvUserId,
    required String ssvCustomData,
  }) {
    return RewardedAdService.showAd(
      ssvUserId: ssvUserId,
      ssvCustomData: ssvCustomData,
    );
  }
}
