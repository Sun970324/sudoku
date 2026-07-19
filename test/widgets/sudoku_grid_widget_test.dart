import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/l10n/generated/app_localizations.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/hint_engine.dart';
import 'package:sudoku/services/generation/sudoku_generator.dart';
import 'package:sudoku/state/game_controller.dart';
import 'package:sudoku/widgets/sudoku_cell_widget.dart';
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
  Hint? findHint(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) =>
      hint;
}

/// Always returns a reveal-type hint (Naked Single) — used to check the
/// arrow overlay is gated to eliminate-type hints only.
class _FixedRevealHintEngine extends HintEngine {
  static final hint = Hint(
    technique: HintTechnique.nakedSingle,
    type: HintType.reveal,
    explanation: 'test reveal',
    primaryCells: {const HintCell(0, 0)},
    row: 0,
    col: 0,
    value: 5,
  );

  @override
  Hint? findHint(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) =>
      hint;
}

/// Always returns a chain-type hint (Skyscraper) carrying chainLinks — the
/// only hints the arrow overlay draws for.
class _FixedChainHintEngine extends HintEngine {
  static final hint = Hint(
    technique: HintTechnique.skyscraper,
    type: HintType.eliminate,
    explanation: 'chain',
    primaryCells: {
      const HintCell(0, 0),
      const HintCell(0, 3),
      const HintCell(8, 0),
      const HintCell(8, 5),
    },
    primaryDigits: {4},
    eliminations: [const HintElimination(1, 5, 4)],
    chainLinks: [
      HintChainLink(
        from: HintChainNode.single(const HintCell(0, 3), 4),
        to: HintChainNode.single(const HintCell(0, 0), 4),
        strong: true,
      ),
      HintChainLink(
        from: HintChainNode.single(const HintCell(0, 0), 4),
        to: HintChainNode.single(const HintCell(8, 0), 4),
        strong: false,
      ),
      HintChainLink(
        from: HintChainNode.single(const HintCell(8, 0), 4),
        to: HintChainNode.single(const HintCell(8, 5), 4),
        strong: true,
      ),
    ],
  );

  @override
  Hint? findHint(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) =>
      hint;
}

/// Requests a hint and drives the progressive reveal to its final stage —
/// the board deliberately draws nothing until then (see
/// [GameController.visualizedHint]), so every test that asserts on the
/// overlay layers has to get there first.
void _requestVisualizedHint(GameController controller) {
  controller.requestHint();
  while (controller.hintStage < 2) {
    controller.advanceHintStage();
  }
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
    _requestVisualizedHint(controller);
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

  testWidgets('a chain hint renders a hint-arrow CustomPaint layer',
      (tester) async {
    final controller = GameController(
      generator: _InstantGenerator(),
      hintEngine: _FixedChainHintEngine(),
    );
    controller.startNewGame(Difficulty.beginner);
    _requestVisualizedHint(controller);
    expect(controller.activeHint?.chainLinks, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SudokuGridWidget(controller: controller)),
      ),
    );

    final arrowPaints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString().contains('Arrow'));
    expect(arrowPaints, isNotEmpty);
  });

  testWidgets(
      'a non-chain eliminate hint (X-Wing) renders no hint-arrow layer',
      (tester) async {
    final controller = GameController(
      generator: _InstantGenerator(),
      hintEngine: _FixedHintEngine(),
    );
    controller.startNewGame(Difficulty.beginner);
    _requestVisualizedHint(controller);
    expect(controller.activeHint?.type, HintType.eliminate);
    expect(controller.activeHint?.chainLinks, isEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SudokuGridWidget(controller: controller)),
      ),
    );

    final arrowPaints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString().contains('Arrow'));
    expect(arrowPaints, isEmpty);
  });

  testWidgets('a reveal hint renders no hint-arrow layer', (tester) async {
    final controller = GameController(
      generator: _InstantGenerator(),
      hintEngine: _FixedRevealHintEngine(),
    );
    controller.startNewGame(Difficulty.beginner);
    _requestVisualizedHint(controller);
    expect(controller.activeHint?.type, HintType.reveal);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SudokuGridWidget(controller: controller)),
      ),
    );

    final arrowPaints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString().contains('Arrow'));
    expect(arrowPaints, isEmpty);
  });

  testWidgets(
      'a step walkthrough shows the red elimination marks only at the '
      'final step, and hides them again when paging back', (tester) async {
    final controller = GameController(
      generator: _InstantGenerator(),
      hintEngine: _FixedChainHintEngine(),
    );
    controller.startNewGame(Difficulty.beginner);
    _requestVisualizedHint(controller);

    // The chain hint (Skyscraper) gets a walkthrough attached by
    // requestHint, starting on its first step.
    final steps = controller.hintSteps;
    expect(steps, isNotEmpty);
    expect(controller.currentHintStep, steps.first);

    // Wrapped the same way GameScreen wires it (`ListenableBuilder` around
    // the grid), so controller notifications actually rebuild the board.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => SudokuGridWidget(controller: controller),
          ),
        ),
      ),
    );

    bool anyRedNotes() => tester
        .widgetList<SudokuCellWidget>(find.byType(SudokuCellWidget))
        .any((w) => w.hintRedNotes.isNotEmpty);
    expect(anyRedNotes(), isFalse);

    while (controller.hintStepIndex < steps.length - 1) {
      controller.nextHintStep();
    }
    await tester.pump();
    expect(controller.currentHintStep!.showConclusion, isTrue);
    expect(anyRedNotes(), isTrue);
    // Paging past the end is a no-op, not an error.
    controller.nextHintStep();
    expect(controller.hintStepIndex, steps.length - 1);

    controller.prevHintStep();
    await tester.pump();
    expect(anyRedNotes(), isFalse);
  });

  testWidgets(
      'dragging across the grid updates the selected cell to follow the '
      'finger, without waiting for a release', (tester) async {
    final controller = GameController(generator: _InstantGenerator());
    controller.startNewGame(Difficulty.beginner);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SudokuGridWidget(controller: controller),
        ),
      ),
    );

    final gridFinder = find.byType(SudokuGridWidget);
    final topLeft = tester.getTopLeft(gridFinder);
    final cellSize = tester.getSize(gridFinder).width / 9;
    Offset cellCenter(int row, int col) => topLeft +
        Offset((col + 0.5) * cellSize, (row + 0.5) * cellSize);

    final gesture = await tester.startGesture(cellCenter(0, 0));
    addTearDown(() => gesture.removePointer());
    await tester.pump();
    // A bare pointer-down with no movement yet is still just a
    // potential tap, not a drag — nothing is selected until the finger
    // actually moves past the touch slop.
    expect(controller.selectedRow, isNull);
    expect(controller.selectedCol, isNull);

    await gesture.moveTo(cellCenter(2, 4));
    await tester.pump();
    expect(controller.selectedRow, 2);
    expect(controller.selectedCol, 4);

    // Sweeping back over the cell the drag started on must not deselect
    // it (selectCellForDrag never toggles, unlike a plain tap).
    await gesture.moveTo(cellCenter(0, 0));
    await tester.pump();
    expect(controller.selectedRow, 0);
    expect(controller.selectedCol, 0);

    await gesture.up();
  });
}
