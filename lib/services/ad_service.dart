import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_unit_ids.dart';

class AdService {
  AdService._internal();

  static final AdService instance = AdService._internal();

  /// Devices registered to always receive test ads — bypasses AdMob's no-fill
  /// throttling that otherwise hits real devices during development. Debug
  /// builds only (see [initialize]); harmless if left, but no reason to ship.
  static const _testDeviceIds = ['86e542f3ab2c88dbbeefb626ab59ac83'];

  RewardedAd? _rewardedAd;
  bool _isLoadingRewardedAd = false;

  /// Set once [MobileAds.instance.initialize] has completed. Loading a rewarded
  /// ad before the SDK is initialized fails (and can poison later requests), so
  /// [preloadRewardedAd] refuses until this is true — a button tap during the
  /// startup consent round-trip would otherwise fire a doomed load.
  bool _initialized = false;

  Future<void> initialize() async {
    await _gatherConsent();
    final status = await MobileAds.instance.initialize();
    // Applied after init (and awaited) so the test-device registration is in
    // place before the first ad request below.
    if (kDebugMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: _testDeviceIds),
      );
    }
    _initialized = true;
    debugPrint('[AdService] MobileAds initialized: '
        '${status.adapterStatuses.map((k, v) => MapEntry(k, v.state))}');
    preloadRewardedAd();
  }

  Future<void> _gatherConsent() {
    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadConsentForm(completer);
        } else {
          completer.complete();
        }
      },
      (FormError error) {
        debugPrint('[AdService] consent info update error: '
            '${error.errorCode} ${error.message}');
        completer.complete();
      },
    );

    return completer.future;
  }

  void _loadConsentForm(Completer<void> completer) {
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((FormError? formError) => completer.complete());
        } else {
          completer.complete();
        }
      },
      (FormError formError) => completer.complete(),
    );
  }

  void preloadRewardedAd() {
    if (!_initialized) {
      debugPrint('[AdService] preload skipped — SDK not initialized yet');
      return;
    }
    if (_isLoadingRewardedAd || _rewardedAd != null) return;
    _isLoadingRewardedAd = true;
    debugPrint('[AdService] requesting RewardedAd (${AdUnitIds.rewardedAdUnitId})');
    RewardedAd.load(
      adUnitId: AdUnitIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[AdService] RewardedAd loaded (${AdUnitIds.rewardedAdUnitId})');
          _rewardedAd = ad;
          _isLoadingRewardedAd = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] RewardedAd failed to load: '
              'code=${error.code} domain=${error.domain} ${error.message}');
          _isLoadingRewardedAd = false;
        },
      ),
    );
  }

  bool get isRewardedAdReady => _rewardedAd != null;

  /// Shows a rewarded ad. [onUserEarnedReward] fires only once the user
  /// actually earns the reward (i.e. watches the ad to completion) — callers
  /// must gate the hint/continue behavior behind this callback, not behind
  /// the button tap itself. If no ad is ready yet, [onAdUnavailable] fires
  /// instead and a new ad load is kicked off for next time.
  Future<void> showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdUnavailable,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      onAdUnavailable();
      preloadRewardedAd();
      return;
    }

    _rewardedAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      // The status bar area is otherwise fully transparent (Flutter's
      // default edge-to-edge mode), and the ad's own view doesn't reliably
      // repaint that exact strip when it takes over — leaving a sliver of
      // the game screen visibly peeking through behind it for as long as
      // the ad is up. Forcing it opaque black here (and letting the app's
      // own AppBar/Scaffold reassert the normal style once a frame renders
      // again after dismissal) closes that gap.
      onAdShowedFullScreenContent: (ad) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(statusBarColor: Color(0xFF000000)),
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadRewardedAd();
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) => onUserEarnedReward(),
    );
  }
}
