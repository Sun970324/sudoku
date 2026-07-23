import '../../models/difficulty.dart';
import '../../models/hint.dart';
import 'human_solver.dart';

/// The computed difficulty of a puzzle, derived from how a [HumanSolver]
/// actually solved it — mirrors generator.md's `DifficultyResult` shape.
class DifficultyResult {
  const DifficultyResult({
    required this.solved,
    required this.guessed,
    required this.highestTechnique,
    required this.highestDifficulty,
    required this.floorDifficulty,
    required this.score,
    required this.techniqueCounts,
    required this.solveHistory,
  });

  /// Whether every cell was filled in using only human techniques.
  final bool solved;

  /// Always false: [HumanSolver] never backtracks/guesses by construction
  /// (see its class doc) — no code path here can set this true. Kept as an
  /// explicit field to match generator.md's `DifficultyResult` shape and
  /// make the "no guessing" invariant visible to callers without reading
  /// HumanSolver's source.
  final bool guessed;

  final HintTechnique? highestTechnique;

  /// The puzzle's overall tier: the higher of the hardest technique's tier
  /// (a "floor", from [techniqueDifficulty]) and the cumulative-score band
  /// (from [scoreBand]). So a puzzle can be *promoted* above its hardest
  /// technique when it needs enough hard steps to accumulate a high [score],
  /// but never demoted below it. [Difficulty.beginner] when [solveHistory]
  /// is empty.
  final Difficulty highestDifficulty;

  /// The tier of [highestTechnique] alone (the floor before score
  /// promotion), or [Difficulty.beginner] when [solveHistory] is empty.
  /// Kept separate from [highestDifficulty] so callers can show "hardest
  /// technique used" independently of the score-promoted overall tier.
  final Difficulty floorDifficulty;

  /// The cumulative difficulty score: the sum of every applied step's
  /// [techniqueBaseScore]. Drives the [scoreBand] half of
  /// [highestDifficulty].
  final int score;

  final Map<HintTechnique, int> techniqueCounts;
  final List<HintTechnique> solveHistory;
}

/// Maps a [SolveResult] onto the app's [Difficulty] tiers — the
/// "DifficultyEvaluator" module.
///
/// Difficulty is the higher of two views of the solve (HoDoKu's model):
///  * a **floor** — the single hardest-tier technique that appeared, via
///    [techniqueDifficulty]; and
///  * a **score band** — [scoreBand] of the cumulative [techniqueBaseScore]
///    summed over every step, so a puzzle that needs *many* hard steps can
///    promote above its hardest single technique.
///
/// A puzzle is therefore never rated below its hardest technique, but can be
/// rated above it. Priority order ([humanSolverTechniqueOrder]) is used only
/// to pick a representative [highestTechnique] among techniques that share
/// the floor tier (e.g. Naked/Hidden Pair/Triple, all one tier); it must
/// never be used to compare across tiers, because priority order and tier
/// order are not monotonic with each other in this app's mapping
/// (nakedQuad/hiddenQuad/simpleColoring/finnedXWing/sashimiXWing/xyChain
/// are all Expert-tier despite sitting earlier in priority order than
/// several Master-tier techniques like xWing/xyWing/swordfish/jellyfish).
class DifficultyEvaluator {
  DifficultyResult evaluate(SolveResult result) {
    HintTechnique? highestTechnique;
    var highestRank = -1;
    var score = 0;

    for (final entry in result.techniqueCounts.entries) {
      final technique = entry.key;
      score += entry.value * techniqueBaseScore[technique]!;

      final rank = Difficulty.values.indexOf(techniqueDifficulty[technique]!);
      final isNewMax = rank > highestRank;
      final tieBrokenByPriority = rank == highestRank &&
          humanSolverTechniqueOrder.indexOf(technique) >
              humanSolverTechniqueOrder.indexOf(highestTechnique!);
      if (isNewMax || tieBrokenByPriority) {
        highestRank = rank;
        highestTechnique = technique;
      }
    }

    final floorDifficulty = highestTechnique == null
        ? Difficulty.beginner
        : techniqueDifficulty[highestTechnique]!;
    final scoreDifficulty = scoreBand(score);
    // Higher of floor and score band (enum is ordered easiest→hardest).
    final highestDifficulty =
        scoreDifficulty.index > floorDifficulty.index
            ? scoreDifficulty
            : floorDifficulty;

    return DifficultyResult(
      solved: result.solved,
      guessed: false,
      highestTechnique: highestTechnique,
      highestDifficulty: highestDifficulty,
      floorDifficulty: floorDifficulty,
      score: score,
      techniqueCounts: result.techniqueCounts,
      solveHistory: result.history,
    );
  }
}
