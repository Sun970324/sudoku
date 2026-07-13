import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/puzzle_queue_manager.dart';
import 'package:sudoku/state/settings_controller.dart';
import 'package:sudoku/widgets/number_pad_widget.dart';

// Never populated (warmUp/loadFromDisk are never called), so take() always
// misses and GameController falls back to its normal synchronous generate
// — these widget tests don't need the real Isolate-based queue at all.
PuzzleQueueManager _emptyPuzzleQueue() => PuzzleQueueManager(
      generateBatch: (Difficulty difficulty, int count) async =>
          <SudokuPuzzle>[],
    );

void main() {
  // flutter_test's default test locale is en_US, which our supportedLocales
  // resolves to 'en' — so these assertions use the English ARB strings
  // (see lib/l10n/app_en.arb), not the Korean ones.
  testWidgets('home screen leads into a playable game screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(SudokuApp(
      settings: SettingsController(),
      puzzleQueue: _emptyPuzzleQueue(),
    ));

    // Home screen now shows a difficulty wheel picker (default selection:
    // Beginner) instead of a "New Game" button + modal — tap "Start"
    // directly with whatever's selected.
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
    await tester.pumpWidget(SudokuApp(
      settings: SettingsController(),
      puzzleQueue: _emptyPuzzleQueue(),
    ));
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
