import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/state/premium_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to non-premium before load', () {
    expect(PremiumController().isPremium, isFalse);
  });

  test('load reflects the persisted mock flag', () async {
    SharedPreferences.setMockInitialValues({'premium_mock': true});
    final premium = PremiumController();
    await premium.load();
    expect(premium.isPremium, isTrue);
  });

  test('setMockPremium updates, notifies, and persists', () async {
    final premium = PremiumController();
    var notified = 0;
    premium.addListener(() => notified++);

    await premium.setMockPremium(true);
    expect(premium.isPremium, isTrue);
    expect(notified, 1);

    // Persisted: a fresh controller loads the same value.
    final reloaded = PremiumController();
    await reloaded.load();
    expect(reloaded.isPremium, isTrue);
  });
}
