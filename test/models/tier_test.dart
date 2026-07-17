import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/tier.dart';

void main() {
  group('Tier.minRating', () {
    // These MUST match the server's tier_for_rating thresholds
    // (supabase/migrations/0008_remove_platinum_tier.sql). If that migration
    // changes, this test and Tier.minRating both need updating together.
    test('matches the server tier_for_rating thresholds', () {
      expect(Tier.bronze.minRating, 0);
      expect(Tier.silver.minRating, 1100);
      expect(Tier.gold.minRating, 1300);
      expect(Tier.diamond.minRating, 1500);
      expect(Tier.master.minRating, 1700);
      expect(Tier.challenger.minRating, 1900);
    });
  });

  group('Tier.nextTier', () {
    test('walks up the ladder and stops at the top', () {
      expect(Tier.bronze.nextTier, Tier.silver);
      expect(Tier.silver.nextTier, Tier.gold);
      expect(Tier.gold.nextTier, Tier.diamond);
      expect(Tier.diamond.nextTier, Tier.master);
      expect(Tier.master.nextTier, Tier.challenger);
      expect(Tier.challenger.nextTier, isNull);
    });

    test('points remaining to the next tier is the threshold gap', () {
      // e.g. a silver at rating 1180 needs 120 more to reach gold (1300).
      const rating = 1180;
      final next = Tier.silver.nextTier!;
      expect(next.minRating - rating, 120);
    });
  });
}
