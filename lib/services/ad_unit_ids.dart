import 'dart:io';

import 'package:flutter/foundation.dart';

/// Google's official test ad unit IDs, safe to ship in debug builds.
/// See https://developers.google.com/admob/flutter/test-ads.
class AdUnitIds {
  AdUnitIds._();

  static const _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIOS = 'ca-app-pub-3940256099942544/1712485313';

  // TODO(M5): replace these with the real ad unit IDs from your AdMob
  // account before release. Until then they intentionally mirror the test
  // IDs above so release builds never accidentally ship without a value.
  static const _releaseRewardedAndroid = _testRewardedAndroid;
  static const _releaseRewardedIOS = _testRewardedIOS;

  static String get rewardedAdUnitId {
    if (Platform.isIOS) {
      return kReleaseMode ? _releaseRewardedIOS : _testRewardedIOS;
    }
    return kReleaseMode ? _releaseRewardedAndroid : _testRewardedAndroid;
  }
}
