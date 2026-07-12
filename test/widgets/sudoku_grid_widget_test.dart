import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/hint_engine.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';
import 'package:sudoku/state/game_controller.dart';
import 'package:sudoku/widgets/sudoku_grid_widget.dart';

/// Returns an instant, trivial puzzle instead of actually generating one —
/// this test only needs a board to exist, not a well-formed puzzle.
class _InstantGenerator extends SudokuGenerator {
  @override
  SudokuPuzzle generate(Difficulty difficulty) {
    final solved = List.generate(9, (_) => List.filled(9, 1));
    return SudokuPuzzle(
      puzzle: SudokuGrid(List.generate(9, (_) => List.filled(9, 0))),
      solution: SudokuGrid(solved),
      fixedMask: List.generate(9, (_) => List.filled(9, false)),
      difficulty: difficulty,
    );
  }
}

/// Always returns a fixed X-Wing-shaped hint, regardless of board state —
/// lets the test drive [GameController.activeHint] without needing a real
/// board that actually contains an X-Wing pattern.
class _FixedHintEngine extends HintEngine {
  static final hint = Hint(
    technique: HintTechnique.xWing,
    type: HintType.eliminate,
    explanation: 'test hint',
    primaryCells: {
      const HintCell(0, 2),
      const HintCell(0, 6),
      const HintCell(3, 2),
      const HintCell(3, 6),
    },
    highlightedRows: const {0, 3},
    highlightedCols: const {2, 6},
  );

  @override
  Hint? findHint(List<List<int>> board, [List<List<Set<int>>>? candidates]) =>
      hint;
}

void main() {
  testWidgets(
      'a hint with highlighted units renders a unit-highlight CustomPaint '
      'layer', (tester) async {
    final controller = GameController(
      generator: _InstantGenerator(),
      hintEngine: _FixedHintEngine(),
    );
    controller.startNewGame(Difficulty.beginner);
    controller.requestHint();
    expect(controller.activeHint?.highlightedRows, {0, 3});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SudokuGridWidget(controller: controller),
        ),
      ),
    );

    final unitHighlightPaints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString().contains('Unit'));
    expect(unitHighlightPaints, isNotEmpty);
  });

  testWidgets('no active hint renders no unit-highlight CustomPaint layer',
      (tester) async {
    final controller = GameController(generator: _InstantGenerator());
    controller.startNewGame(Difficulty.beginner);
    expect(controller.activeHint, isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SudokuGridWidget(controller: controller),
        ),
      ),
    );

    final unitHighlightPaints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString().contains('Unit'));
    expect(unitHighlightPaints, isEmpty);
  });
}
