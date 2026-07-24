import 'package:flutter/foundation.dart';

import '../services/purchase_service.dart';
import '../services/storage_service.dart';

/// App-global premium entitlement, a process-wide singleton like
/// [AdService.instance] — there's one entitlement per install and premium
/// gates are read from many screens, so a shared instance beats threading a
/// controller through every one.
///
/// Entitlement is resolved through [PurchaseService]; only the local mock
/// ([MockPurchaseService], flipped from the debug settings toggle via
/// [setMockPremium]) exists today. Wiring in real store billing later means
/// swapping the service — none of the `isPremium` call sites change.
class PremiumController extends ChangeNotifier {
  PremiumController({PurchaseService? purchaseService, StorageService? storage})
      : _storage = storage ?? StorageService(),
        _purchase = purchaseService ?? MockPurchaseService(storage: storage);

  /// The shared instance used throughout the app. Tests construct their own
  /// [PremiumController] with a fake service instead of touching this.
  static final PremiumController instance = PremiumController();

  final StorageService _storage;
  final PurchaseService _purchase;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  /// Resolves the current entitlement from the purchase service. Call once at
  /// startup (see main).
  Future<void> load() async {
    _isPremium = await _purchase.isEntitled();
    notifyListeners();
  }

  /// Debug-only override wired to the settings sheet's premium toggle. Persists
  /// the mock flag so a relaunch keeps the chosen state (the mock purchase
  /// service reads it back in [load]).
  Future<void> setMockPremium(bool value) async {
    await _storage.savePremiumMock(value);
    _isPremium = value;
    notifyListeners();
  }
}
