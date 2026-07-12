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

  /// The tier of [highestTechnique], or [Difficulty.beginner] when
  /// [solveHistory] is empty (a puzzle solved with zero technique
  /// applications is trivially the easiest tier).
  final Difficulty highestDifficulty;

  final Map<HintTechnique, int> techniqueCounts;
  final List<HintTechnique> solveHistory;
}

/// Maps a [SolveResult] onto the app's [Difficulty] tiers using
/// [techniqueDifficulty] — the "DifficultyEvaluator" module.
///
/// Per generator.md, difficulty is decided solely by the single
/// hardest-tier technique that appeared in the solve history — not a
/// cumulative score. Priority order ([humanSolverTechniqueOrder]) is only
/// used to break ties among techniques that share a tier (e.g. picking a
/// representative technique among Naked/Hidden Pair/Triple, all Hard); it
/// must never be used to compare across tiers, because priority order and
/// tier order are not monotonic with each other in this app's mapping
/// (nakedQuad/hiddenQuad/simpleColoring/finnedXWing/sashimiXWing/xyChain
/// are all Expert-tier despite sitting earlier in priority order than
/// several Master-tier techniques like xWing/xyWing/swordfish/jellyfish).
class DifficultyEvaluator {
  DifficultyResult evaluate(SolveResult result) {
    HintTechnique? highestTechnique;
    var highestRank = -1;

    for (final technique in result.techniqueCounts.keys) {
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

    return DifficultyResult(
      solved: result.solved,
      guessed: false,
      highestTechnique: highestTechnique,
      highestDifficulty: highestTechnique == null
          ? Difficulty.beginner
          : techniqueDifficulty[highestTechnique]!,
      techniqueCounts: result.techniqueCounts,
      solveHistory: result.history,
    );
  }
}
