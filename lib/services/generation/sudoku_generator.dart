import 'dart:math';

import '../../models/difficulty.dart';
import '../../models/sudoku_grid.dart';
import '../../models/sudoku_puzzle.dart';
import 'board_generator.dart';
import 'clue_remover.dart';
import 'difficulty_evaluator.dart';
import 'human_solver.dart';
import 'minimalizer.dart';

/// Orchestrates board generation end to end — the "Generator" module.
///
/// Per generator.md, difficulty is decided by which techniques a
/// [HumanSolver] actually needed, never by given count. Every [Difficulty]
/// tier is gated the same way: [ClueRemover] and [Minimalizer] both dig
/// only while a candidate board's [DifficultyEvaluator]-computed
/// `highestDifficulty` stays at or below the target tier (a "ceiling"), and
/// the final board is only accepted if it *exactly* matches the target —
/// this catches undershoot (a dig that stayed within the ceiling but never
/// actually reached the target tier's representative technique). A puzzle
/// that doesn't reach an exact match is discarded and generation retries
/// with a fresh solved board.
class SudokuGenerator {
  SudokuGenerator({
    Random? random,
    BoardGenerator? boardGenerator,
    ClueRemover? clueRemover,
    HumanSolver? humanSolver,
    Minimalizer? minimalizer,
    DifficultyEvaluator? difficultyEvaluator,
  })  : _boardGenerator = boardGenerator ?? BoardGenerator(random: random),
        _clueRemover = clueRemover ?? ClueRemover(random: random),
        _humanSolver = humanSolver ?? HumanSolver(),
        _minimalizer = minimalizer ?? Minimalizer(random: random),
        _evaluator = difficultyEvaluator ?? DifficultyEvaluator();

  static const _maxAttempts = 200;

  final BoardGenerator _boardGenerator;
  final ClueRemover _clueRemover;
  final HumanSolver _humanSolver;
  final Minimalizer _minimalizer;
  final DifficultyEvaluator _evaluator;

  SudokuPuzzle generate(Difficulty difficulty) {
    final targetRank = Difficulty.values.indexOf(difficulty);

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final solvedBoard = _boardGenerator.generateSolvedBoard();

      bool withinCeiling(List<List<int>> candidate) {
        final evaluated = _evaluator.evaluate(_humanSolver.solve(candidate));
        // `solved` is deliberately ignored here: an intermediate dig state
        // HumanSolver can't yet fully finish is normal (fewer givens means
        // more ambiguity along the way), not evidence of "too hard." Only a
        // technique that actually outranks the target tier disqualifies.
        return Difficulty.values.indexOf(evaluated.highestDifficulty) <=
            targetRank;
      }

      final dug = _clueRemover.removeClues(
        solvedBoard,
        difficulty.givenCount,
        isAcceptable: withinCeiling,
      );
      final minimized =
          _minimalizer.minimalize(dug, isAcceptable: withinCeiling);

      final finalEvaluated =
          _evaluator.evaluate(_humanSolver.solve(minimized));
      if (finalEvaluated.solved &&
          finalEvaluated.highestDifficulty == difficulty) {
        final fixedMask = List.generate(
          9,
          (r) => List.generate(9, (c) => minimized[r][c] != 0),
        );
        return SudokuPuzzle(
          puzzle: SudokuGrid(minimized),
          solution: SudokuGrid(solvedBoard),
          fixedMask: fixedMask,
          difficulty: difficulty,
        );
      }
      // Undershoot (never reached the target tier), or an overshoot that
      // slipped past the ceiling (shouldn't happen given both passes are
      // ceiling-gated, but this final check is the real guard either way)
      // — retry with a fresh solved board.
    }

    throw StateError(
      'SudokuGenerator: could not produce a $difficulty puzzle that exactly '
      'matches the target difficulty after $_maxAttempts attempts.',
    );
  }
}
