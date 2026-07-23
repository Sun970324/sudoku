import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide online/offline state, backed by connectivity_plus. This reflects
/// whether the device has a usable *network interface* (Wi-Fi / cellular) — not
/// a guaranteed round-trip to our server. Screens use [isOnline] to pre-empt
/// server-only actions (see ensureOnline); an actual request that still fails
/// on a flaky link is the failure fallback layer on top of this.
///
/// Singleton (mirrors [AdService]/[PremiumController]) so any widget can read
/// the current state and listen for changes without threading it through
/// constructors.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  /// Optimistic default: assume online until the first check resolves, so a
  /// slow initial probe never flashes the offline UI on a connected device.
  bool _online = true;
  bool get isOnline => _online;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Reads the current state once and subscribes to changes. Called from main()
  /// before runApp. Failures (e.g. a platform without the plugin) leave the
  /// optimistic online default in place rather than blocking startup.
  Future<void> initialize() async {
    try {
      _apply(await Connectivity().checkConnectivity());
      _sub = Connectivity().onConnectivityChanged.listen(_apply);
    } catch (e) {
      debugPrint('[ConnectivityService] init failed: $e');
    }
  }

  void _apply(List<ConnectivityResult> results) {
    // "Offline" only when every reported interface is none.
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
