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
/// [Difficulty.beginner]/[Difficulty.easy]/[Difficulty.medium] are generated
/// purely by given count (see [_generateByGivenCount]): [ClueRemover] digs
/// straight to the tier's [Difficulty.givenCount] preserving only
/// uniqueness, with no technique check at all. At these generous given
/// counts an advanced technique is only ever needed in rare, unlucky cases —
/// an acceptable tradeoff for these tiers. (The result screen's "which
/// techniques did this puzzle need" display is unaffected either way — it
/// re-solves the puzzle's own given board with [HumanSolver] independently
/// at completion time, regardless of how the puzzle was generated.)
///
/// [Difficulty.hard]/[Difficulty.master]/[Difficulty.expert] keep the
/// original technique-gated generation (see [_generateByTechnique]): per
/// generator.md, difficulty is decided by which techniques a [HumanSolver]
/// actually needed, never by given count. [ClueRemover] and [Minimalizer]
/// both dig only while a candidate board's [DifficultyEvaluator]-computed
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

  /// Expert puzzles are pushed toward a sparser board (require.md #5 asked
  /// for a givens cap). Measured: uniqueness-minimal expert boards land at
  /// ~24 givens on average, so the originally-requested "< 22" was only
  /// reachable ~8% of the time (very slow to force). 23 sits just below the
  /// median — it reliably trims the fuller 24-26 boards without exploding
  /// generation time. Enforced as an acceptance condition with a fallback,
  /// so it can never become a hard failure (see [_generateByTechnique]).
  static const _expertMaxGivens = 23;

  // Bronze/Silver are the only given-count tiers: their bands (singles /
  // hidden-single + intersections) don't separate cleanly by technique, so
  // digging to a target given-count and stopping is both faster (one pass,
  // always succeeds) and a truer knob for them. Every tier from Gold up is
  // technique-gated.
  static const _givenCountBasedTiers = {
    Difficulty.beginner,
    Difficulty.easy,
  };

  final BoardGenerator _boardGenerator;
  final ClueRemover _clueRemover;
  final HumanSolver _humanSolver;
  final Minimalizer _minimalizer;
  final DifficultyEvaluator _evaluator;

  SudokuPuzzle generate(Difficulty difficulty) =>
      _givenCountBasedTiers.contains(difficulty)
          ? _generateByGivenCount(difficulty)
          : _generateByTechnique(difficulty);

  /// No technique check at all — just dig straight to [Difficulty.givenCount]
  /// preserving only uniqueness (see class doc for the rationale/tradeoff).
  /// Always succeeds in one pass: with no ceiling constraining the dig, it
  /// reliably reaches (or gets very close to) the target given count.
  SudokuPuzzle _generateByGivenCount(Difficulty difficulty) {
    final solvedBoard = _boardGenerator.generateSolvedBoard();
    final dug = _clueRemover.removeClues(solvedBoard, difficulty.givenCount);
    final fixedMask = List.generate(
      9,
      (r) => List.generate(9, (c) => dug[r][c] != 0),
    );
    return SudokuPuzzle(
      puzzle: SudokuGrid(dug),
      solution: SudokuGrid(solvedBoard),
      fixedMask: fixedMask,
      difficulty: difficulty,
    );
  }

  SudokuPuzzle _generateByTechnique(Difficulty difficulty) {
    final targetRank = Difficulty.values.indexOf(difficulty);

    // Expert only: a tier-correct candidate that missed the givens cap is
    // kept as a last resort, so exhausting every attempt degrades to a
    // slightly-too-full expert puzzle instead of a StateError — which the
    // puzzle queue would swallow and, on the take() miss fallback, would
    // mean a very long synchronous generate on the UI thread.
    SudokuPuzzle? overfullFallback;

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
        final givens = minimized.fold<int>(
            0, (sum, row) => sum + row.where((v) => v != 0).length);
        if (difficulty != Difficulty.expert || givens <= _expertMaxGivens) {
          return _toPuzzle(minimized, solvedBoard, difficulty);
        }
        overfullFallback ??= _toPuzzle(minimized, solvedBoard, difficulty);
      }
      // Undershoot (never reached the target tier), an overshoot that
      // slipped past the ceiling (shouldn't happen given both passes are
      // ceiling-gated, but this final check is the real guard either way),
      // or an expert board that landed with too many givens — retry with a
      // fresh solved board.
    }

    final fallback = overfullFallback;
    if (fallback != null) return fallback;

    throw StateError(
      'SudokuGenerator: could not produce a $difficulty puzzle that exactly '
      'matches the target difficulty after $_maxAttempts attempts.',
    );
  }

  SudokuPuzzle _toPuzzle(
    List<List<int>> puzzle,
    List<List<int>> solution,
    Difficulty difficulty,
  ) =>
      SudokuPuzzle(
        puzzle: SudokuGrid(puzzle),
        solution: SudokuGrid(solution),
        fixedMask: List.generate(
          9,
          (r) => List.generate(9, (c) => puzzle[r][c] != 0),
        ),
        difficulty: difficulty,
      );
}
