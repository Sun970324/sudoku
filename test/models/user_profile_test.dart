import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/tier.dart';
import 'package:sudoku/models/user_profile.dart';

void main() {
  group('UserProfile.fromJson', () {
    // Shape mirrors a `profiles` row (season counters added in 0016).
    test('parses lifetime and season records separately', () {
      final profile = UserProfile.fromJson({
        'id': '5b0e806e-0000-0000-0000-000000000000',
        'username': 'Player1',
        'avatar_url': null,
        'rating': 1350,
        'tier': 'gold',
        'wins': 40,
        'losses': 30,
        'season_wins': 3,
        'season_losses': 1,
      });

      expect(profile.tier, Tier.gold);
      expect(profile.wins, 40);
      expect(profile.losses, 30);
      expect(profile.seasonWins, 3);
      expect(profile.seasonLosses, 1);
      expect(profile.seasonGames, 4);
    });
  });
}
