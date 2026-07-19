import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sudoku/l10n/generated/app_localizations.dart';
import 'package:sudoku/models/rating_leaderboard.dart';
import 'package:sudoku/models/tier.dart';
import 'package:sudoku/screens/race/rating_leaderboard_screen.dart';
import 'package:sudoku/services/auth_service.dart';
import 'package:sudoku/services/profile_service.dart';
import 'package:sudoku/state/auth_controller.dart';
import 'package:sudoku/widgets/tier_badge.dart';

// A standalone (non-singleton) client so AuthService/ProfileService can be
// constructed without Supabase.initialize; autoRefreshToken:false avoids a
// lingering refresh timer (these tests never sign in). Same pattern as
// test/widget_test.dart.
SupabaseClient _dummyClient() => SupabaseClient(
      'https://test.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

class _FakeProfileService extends ProfileService {
  _FakeProfileService(this._board, {required super.client});

  final RatingLeaderboard _board;

  @override
  Future<RatingLeaderboard> fetchLeaderboard() async => _board;
}

RatingLeaderboardEntry _entry(int rank, String name, int rating, Tier tier) =>
    RatingLeaderboardEntry(
      rank: rank,
      profileId: 'id-$rank',
      username: name,
      rating: rating,
      tier: tier,
      wins: rating ~/ 100,
      losses: 1,
    );

Future<void> _pumpScreen(WidgetTester tester, RatingLeaderboard board) async {
  final client = _dummyClient();
  final auth = AuthController(
    authService: AuthService(client: client),
    profileService: ProfileService(client: client),
  );
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RatingLeaderboardScreen(
      auth: auth,
      service: _FakeProfileService(board, client: client),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders a row per entry with username, tier badge, and rating',
      (tester) async {
    await _pumpScreen(
      tester,
      RatingLeaderboard(
        total: 2,
        myRank: 1,
        myRating: 1231,
        entries: [
          _entry(1, 'huru', 1231, Tier.silver),
          _entry(2, 'master', 1169, Tier.silver),
        ],
      ),
    );

    expect(find.text('huru'), findsOneWidget);
    expect(find.text('master'), findsOneWidget);
    expect(find.text('1231'), findsOneWidget);
    expect(find.text('1169'), findsOneWidget);
    expect(find.byType(TierBadge), findsNWidgets(2));
    // "Your rank: #1 of 2" (en fallback locale).
    expect(find.textContaining('#1'), findsOneWidget);
  });

  testWidgets('shows the empty message when no one has played', (tester) async {
    await _pumpScreen(
      tester,
      const RatingLeaderboard(total: 0, entries: []),
    );

    expect(find.text('No ranked players yet.'), findsOneWidget);
    expect(find.text('No ranked record yet'), findsOneWidget);
    expect(find.byType(TierBadge), findsNothing);
  });
}
