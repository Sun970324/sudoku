import 'storage_service.dart';

/// Abstraction over store billing so [PremiumController] resolves entitlement
/// the same way regardless of source. Only [MockPurchaseService] exists today;
/// a real StoreKit / Play Billing implementation drops in here later without
/// changing any `isPremium` call site.
abstract class PurchaseService {
  /// Whether the user currently owns the premium entitlement.
  Future<bool> isEntitled();
}

/// Debug/mockup entitlement backed by a persisted local flag, flipped from the
/// settings sheet's premium toggle. Stands in for real IAP until store billing
/// is integrated.
class MockPurchaseService implements PurchaseService {
  MockPurchaseService({StorageService? storage})
      : _storage = storage ?? StorageService();

  final StorageService _storage;

  @override
  Future<bool> isEntitled() => _storage.loadPremiumMock();
}
