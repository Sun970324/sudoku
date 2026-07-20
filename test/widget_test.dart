import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/services/auth_service.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';
import 'package:sudoku/services/profile_service.dart';
import 'package:sudoku/services/puzzle_queue_manager.dart';
import 'package:sudoku/state/auth_controller.dart';
import 'package:sudoku/state/settings_controller.dart';
import 'package:sudoku/widgets/number_pad_widget.dart';

// The home screen only ever has Beginner selected in these tests (the wheel
// is never scrolled), and disables "Start" until that tier's queue is
// non-empty — so generateBatch only ever needs to serve Beginner, fast
// enough to run for real rather than needing a dummy/empty fixture.
PuzzleQueueManager _testPuzzleQueue() => PuzzleQueueManager(
      generateBatch: (Difficulty difficulty, int count) async =>
          List.generate(count, (_) => SudokuGenerator().generate(difficulty)),
    );

// A standalone SupabaseClient (not the Supabase.instance singleton, which
// requires Supabase.initialize() and real project credentials) — enough to
// satisfy AuthService/ProfileService/AuthController's dependency without any
// network call, since these tests never sign in.
AuthController _testAuthController() {
  // autoRefreshToken: false — otherwise GoTrueClient starts a periodic
  // refresh Timer that outlives the widget tree and trips flutter_test's
  // "no pending timers" invariant, since nothing in these tests ever signs
  // in (so there's no session to refresh anyway).
  final client = SupabaseClient(
    'https://test.supabase.co',
    'test-anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return AuthController(
    authService: AuthService(client: client),
    profileService: ProfileService(client: client),
  );
}

void main() {
  // The queue's background refill persists to SharedPreferences. The
  // tutorial seen-flags are pre-set so the first-entry coach marks (whose
  // PulseRing repeats forever) don't keep pumpAndSettle from settling.
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'seen_home_tutorial': true,
      'seen_game_tutorial': true,
    });
  });

  // flutter_test's default test locale is en_US, which our supportedLocales
  // resolves to 'en' — so these assertions use the English ARB strings
  // (see lib/l10n/app_en.arb), not the Korean ones.
  testWidgets('home screen leads into a playable game screen',
      (WidgetTester tester) async {
    final puzzleQueue = _testPuzzleQueue();
    await tester.pumpWidget(SudokuApp(
      settings: SettingsController(),
      puzzleQueue: puzzleQueue,
      auth: _testAuthController(),
    ));

    // Home screen now shows a difficulty wheel picker (default selection:
    // Beginner) instead of a "New Game" button + modal. "Start" is disabled
    // (showing "Generating...") until the Beginner tier's queue — refilled
    // in the background as soon as the picker renders — is non-empty.
    await puzzleQueue.waitUntilIdle();
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // Game screen should render the number pad and grid.
    expect(find.text('1'), findsWidgets);
    expect(find.text('Hint'), findsOneWidget);
  });

  testWidgets(
      'toggling the note control fades the second number pad in and out',
      (WidgetTester tester) async {
    final puzzleQueue = _testPuzzleQueue();
    await tester.pumpWidget(SudokuApp(
      settings: SettingsController(),
      puzzleQueue: puzzleQueue,
      auth: _testAuthController(),
    ));
    await puzzleQueue.waitUntilIdle();
    await tester.pump();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // Both number pads always occupy layout space (so the grid above never
    // shifts) — only the notes pad's opacity toggles with note mode.
    expect(find.byType(NumberPadWidget), findsNWidgets(2));
    double notesOpacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    // Note mode defaults to on for a new game, so the notes pad starts
    // fully visible.
    expect(notesOpacity(), 1);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NumberPadWidget), findsNWidgets(2));
    expect(notesOpacity(), 0);

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(notesOpacity(), 1);
  });
}
