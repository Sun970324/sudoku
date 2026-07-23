import '../../models/difficulty.dart';
import '../../models/hint.dart';
import '../../models/sudoku_grid.dart';
import '../hint_engine.dart';

/// Technique priority order for [HumanSolver], per generator.md's own
/// specification and score table (section 6): "Locked Candidate" (this
/// app's Intersection Pointing/Claiming) is listed once, between Hidden
/// Single and Naked Pair — matching how [DifficultyEvaluator]'s weights are
/// already laid out. generator.md never mentions Naked/Hidden
/// Triple/Quad explicitly; they're folded in as an escalating
/// Pair→Triple→Quad family right before X-Wing, mirroring the equivalent
/// grouping already established in [hintTechniqueOrder] (the separate,
/// player-facing order). Deliberately separate from [hintTechniqueOrder]
/// itself — generator.md asks for Naked Single before Hidden Single, while
/// the player-facing hint engine was intentionally reordered earlier
/// (Hidden before Naked) for a better in-game hint experience. Both are
/// correct for their own purpose; this is not an inconsistency.
const humanSolverTechniqueOrder = [
  // Bronze
  HintTechnique.fullHouse,
  HintTechnique.nakedSingle,
  // Silver
  HintTechnique.hiddenSingle,
  HintTechnique.intersectionPointing,
  HintTechnique.intersectionClaiming,
  // Gold — pairs
  HintTechnique.lockedPair,
  HintTechnique.nakedPair,
  HintTechnique.hiddenPair,
  // Diamond — triples, single-digit fish/chains, basic wings
  HintTechnique.lockedTriple,
  HintTechnique.nakedTriple,
  HintTechnique.hiddenTriple,
  HintTechnique.xWing,
  HintTechnique.skyscraper,
  HintTechnique.twoStringKite,
  HintTechnique.turbotFish,
  HintTechnique.xyWing,
  HintTechnique.remotePair,
  // Master — single-digit colouring, 3-cover fish, compound wings,
  // finned/sashimi, quads. Simple Coloring leads the band: placed any later
  // it is fully preempted by the single-digit techniques (Skyscraper /
  // Turbot / X-Chain) that resolve the same colourable components, so it
  // would never fire in generation at all.
  HintTechnique.simpleColoring,
  HintTechnique.xyzWing,
  HintTechnique.wWing,
  HintTechnique.swordfish,
  HintTechnique.jellyfish,
  HintTechnique.finnedXWing,
  HintTechnique.sashimiXWing,
  HintTechnique.nakedQuad,
  HintTechnique.hiddenQuad,
  // Challenger — uniqueness, chains, ALS
  HintTechnique.bugPlusOne,
  HintTechnique.uniqueRectangleType1,
  HintTechnique.uniqueRectangleType2,
  HintTechnique.uniqueRectangleType3,
  HintTechnique.uniqueRectangleType4,
  HintTechnique.xChain,
  HintTechnique.wxyzWing,
  HintTechnique.alsXZ,
  // Deliberately last (user request): the solver only reaches for XY-Chain
  // when nothing more local applies. Its tier still comes from
  // [techniqueDifficulty], not this position.
  HintTechnique.xyChain,
];

/// The outcome of [HumanSolver.solve]: how far a human-technique-only
/// solve got, and which techniques it used to get there.
class SolveResult {
  const SolveResult({
    required this.solved,
    required this.board,
    required this.history,
    required this.techniqueCounts,
  });

  /// Whether every cell was filled in using only [humanSolverTechniqueOrder]
  /// — false means the puzzle needs a technique this solver doesn't have
  /// yet (expected and normal for puzzles harder than what's implemented).
  final bool solved;
  final List<List<int>> board;

  /// Every technique application, in the order it was used. Includes
  /// eliminate-type techniques (they narrow candidates but don't fill a
  /// cell themselves) as well as reveal-type ones.
  final List<HintTechnique> history;

  /// How many times each technique in [history] was used.
  final Map<HintTechnique, int> techniqueCounts;
}

/// Solves a board using only genuine human solving techniques (never
/// backtracking), reusing [HintEngine]'s existing technique implementations
/// — the "HumanSolver" module. Finds one deduction, applies it, and
/// restarts from the top of [humanSolverTechniqueOrder]; stops once no
/// technique applies.
///
/// Tracks its own candidate grid across iterations (separate from
/// [HintEngine]'s per-call default of computing fresh from the board) so
/// that eliminate-type techniques (Intersection Pointing/Claiming,
/// Naked/Hidden Pair/Triple/Quad, X-Wing) actually make forward progress:
/// applying one narrows this grid in place, which both prevents
/// rediscovering the identical elimination forever (the board alone never
/// changes) and lets a subsequently-unlocked Naked/Hidden Single actually
/// get found. This is a deliberate simplification of the "invalidate,
/// don't touch stale state" discipline [GameController] uses for the
/// player's own notes — there's no player-entered state to protect here,
/// since every digit in this grid is derived purely from this solver's own
/// valid deductions, so a full recompute after every reveal is always safe.
class HumanSolver {
  HumanSolver({HintEngine? hintEngine, List<HintTechnique>? techniqueOrder})
      : _hintEngine = hintEngine ?? HintEngine(),
        _techniqueOrder = techniqueOrder ?? humanSolverTechniqueOrder;

  final HintEngine _hintEngine;

  /// The priority order [_findNext] scans. Defaults to
  /// [humanSolverTechniqueOrder] (generation/difficulty semantics); the
  /// technique-board miner passes an extended order that appends the
  /// hint-only techniques, so "solve history contains X" is a checkable
  /// condition for them too.
  final List<HintTechnique> _techniqueOrder;

  /// Solves as far as human techniques reach. With [maxDifficulty] set, the
  /// solve aborts early the moment it becomes clear the puzzle exceeds that
  /// tier — HoDoKu's generation-time optimisation (SudokuSolver.getHint:
  /// "Wenn das Puzzle zu schwer ist, gleich abbrechen"): a candidate that
  /// needs an over-tier technique, or whose cumulative score leaves the
  /// tier's band, is going to be rejected anyway, so finishing the solve is
  /// pure waste. An aborted result has `solved == false` (indistinguishable
  /// from "stuck" — callers reject both); the offending technique is NOT
  /// added to [SolveResult.history].
  SolveResult solve(List<List<int>> board, {Difficulty? maxDifficulty}) {
    final working = board.map((row) => List<int>.from(row)).toList();
    final history = <HintTechnique>[];
    final techniqueCounts = <HintTechnique, int>{};
    List<List<Set<int>>>? candidates;
    final scoreCeiling =
        maxDifficulty == null ? null : difficultyScoreBands[maxDifficulty];
    var score = 0;

    while (true) {
      candidates ??= _freshCandidates(working);
      final hint = _findNext(working, candidates);
      if (hint == null) break;

      if (maxDifficulty != null &&
          techniqueDifficulty[hint.technique]!.index > maxDifficulty.index) {
        break; // over-tier step found — too hard, abort unapplied
      }
      score += techniqueBaseScore[hint.technique]!;
      if (scoreCeiling != null && score >= scoreCeiling) {
        break; // cumulative score already past the tier's band — too hard
      }

      history.add(hint.technique);
      techniqueCounts[hint.technique] =
          (techniqueCounts[hint.technique] ?? 0) + 1;

      if (hint.type == HintType.reveal) {
        working[hint.row!][hint.col!] = hint.value!;
        candidates = null;
      } else {
        for (final elimination in hint.eliminations) {
          candidates[elimination.row][elimination.col].remove(elimination.digit);
        }
      }
    }

    return SolveResult(
      solved: _isComplete(working),
      board: working,
      history: history,
      techniqueCounts: techniqueCounts,
    );
  }

  Hint? _findNext(List<List<int>> board, List<List<Set<int>>> candidates) {
    for (final technique in _techniqueOrder) {
      final hint = switch (technique) {
        HintTechnique.fullHouse => _hintEngine.findFullHouse(board),
        HintTechnique.nakedSingle =>
          _hintEngine.findNakedSingle(board, candidates),
        HintTechnique.hiddenSingle =>
          _hintEngine.findHiddenSingle(board, candidates),
        HintTechnique.intersectionPointing =>
          _hintEngine.findIntersectionPointing(board, candidates),
        HintTechnique.intersectionClaiming =>
          _hintEngine.findIntersectionClaiming(board, candidates),
        HintTechnique.lockedPair =>
          _hintEngine.findLockedPair(board, candidates),
        HintTechnique.lockedTriple =>
          _hintEngine.findLockedTriple(board, candidates),
        HintTechnique.nakedPair =>
          _hintEngine.findNakedPair(board, candidates),
        HintTechnique.hiddenPair =>
          _hintEngine.findHiddenPair(board, candidates),
        HintTechnique.nakedTriple =>
          _hintEngine.findNakedTriple(board, candidates),
        HintTechnique.hiddenTriple =>
          _hintEngine.findHiddenTriple(board, candidates),
        HintTechnique.nakedQuad =>
          _hintEngine.findNakedQuad(board, candidates),
        HintTechnique.hiddenQuad =>
          _hintEngine.findHiddenQuad(board, candidates),
        HintTechnique.xWing => _hintEngine.findXWing(board, candidates),
        HintTechnique.skyscraper =>
          _hintEngine.findSkyscraper(board, candidates),
        HintTechnique.twoStringKite =>
          _hintEngine.findTwoStringKite(board, candidates),
        HintTechnique.turbotFish =>
          _hintEngine.findTurbotFish(board, candidates),
        HintTechnique.remotePair =>
          _hintEngine.findRemotePair(board, candidates),
        HintTechnique.simpleColoring =>
          _hintEngine.findSimpleColoring(board, candidates),
        HintTechnique.xyWing => _hintEngine.findXYWing(board, candidates),
        HintTechnique.xyzWing => _hintEngine.findXYZWing(board, candidates),
        HintTechnique.wWing => _hintEngine.findWWing(board, candidates),
        HintTechnique.swordfish =>
          _hintEngine.findSwordfish(board, candidates),
        HintTechnique.finnedXWing =>
          _hintEngine.findFinnedXWing(board, candidates),
        HintTechnique.sashimiXWing =>
          _hintEngine.findSashimiXWing(board, candidates),
        HintTechnique.bugPlusOne =>
          _hintEngine.findBugPlusOne(board, candidates),
        HintTechnique.xyChain => _hintEngine.findXYChain(board, candidates),
        HintTechnique.jellyfish =>
          _hintEngine.findJellyfish(board, candidates),
        // Hint-only: deliberately absent from [humanSolverTechniqueOrder], so
        // these arms are unreachable today. Wired to the real search anyway
        // rather than `null`, so that adding them to that list is all it
        // would take — a `null` here would instead make them silently
        // find nothing.
        HintTechnique.finnedSwordfish =>
          _hintEngine.findFinnedSwordfish(board, candidates),
        HintTechnique.finnedJellyfish =>
          _hintEngine.findFinnedJellyfish(board, candidates),
        HintTechnique.uniqueRectangleType1 =>
          _hintEngine.findUniqueRectangleType1(board, candidates),
        HintTechnique.uniqueRectangleType2 =>
          _hintEngine.findUniqueRectangleType2(board, candidates),
        HintTechnique.uniqueRectangleType3 =>
          _hintEngine.findUniqueRectangleType3(board, candidates),
        HintTechnique.uniqueRectangleType4 =>
          _hintEngine.findUniqueRectangleType4(board, candidates),
        // Hint-only: never in humanSolverTechniqueOrder, so unreachable here,
        // but the switch must stay exhaustive over HintTechnique.
        HintTechnique.xChain =>
          _hintEngine.findXChain(board, candidates),
        HintTechnique.aic => _hintEngine.findAic(board, candidates),
        HintTechnique.groupedXChain =>
          _hintEngine.findGroupedXChain(board, candidates),
        HintTechnique.groupedAic =>
          _hintEngine.findGroupedAic(board, candidates),
        HintTechnique.wxyzWing => _hintEngine.findWXYZWing(board, candidates),
        HintTechnique.alsXZ => _hintEngine.findAlsXZ(board, candidates),
        HintTechnique.sueDeCoq =>
          _hintEngine.findSueDeCoq(board, candidates),
        HintTechnique.tripleFirework =>
          _hintEngine.findTripleFirework(board, candidates),
        HintTechnique.alsAic => _hintEngine.findAlsAic(board, candidates),
      };
      if (hint != null) return hint;
    }
    return null;
  }

  List<List<Set<int>>> _freshCandidates(List<List<int>> board) =>
      SudokuGrid(board).allCandidates();

  bool _isComplete(List<List<int>> board) {
    for (final row in board) {
      if (row.contains(0)) return false;
    }
    return true;
  }
}
