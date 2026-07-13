import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_unit_ids.dart';

class AdService {
  AdService._internal();

  static final AdService instance = AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isLoadingRewardedAd = false;

  Future<void> initialize() async {
    await _gatherConsent();
    await MobileAds.instance.initialize();
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
      (FormError error) => completer.complete(),
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

  BannerAd createBannerAd({
    required void Function(BannerAd ad) onAdLoaded,
    required VoidCallback onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: AdUnitIds.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onAdLoaded(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad();
        },
      ),
    )..load();
  }

  void preloadRewardedAd() {
    if (_isLoadingRewardedAd || _rewardedAd != null) return;
    _isLoadingRewardedAd = true;
    RewardedAd.load(
      adUnitId: AdUnitIds.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewardedAd = false;
        },
        onAdFailedToLoad: (error) {
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
