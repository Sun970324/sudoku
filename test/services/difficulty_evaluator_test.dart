import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/difficulty_evaluator.dart';
import 'package:sudoku/services/generation/human_solver.dart';

List<List<int>> _dummyBoard() => List.generate(9, (_) => List.filled(9, 0));

SolveResult _resultFor(List<HintTechnique> history, {bool solved = true}) {
  final counts = <HintTechnique, int>{};
  for (final t in history) {
    counts[t] = (counts[t] ?? 0) + 1;
  }
  return SolveResult(
    solved: solved,
    board: _dummyBoard(),
    history: history,
    techniqueCounts: counts,
  );
}

void main() {
  final evaluator = DifficultyEvaluator();

  test('techniqueDifficulty covers every HintTechnique and every technique '
      'HumanSolver can produce', () {
    expect(techniqueDifficulty.keys.toSet(), HintTechnique.values.toSet());
    for (final technique in humanSolverTechniqueOrder) {
      expect(techniqueDifficulty, contains(technique));
    }
  });

  test('highestDifficulty is the max tier across every technique used, by '
      'techniqueDifficulty — not by any single technique\'s position', () {
    // A mixed history whose hardest technique (Swordfish, Master) is not the
    // last one used, so the tier comes from the tier map, not "last entry".
    final result = _resultFor([
      HintTechnique.hiddenSingle, // easy
      HintTechnique.swordfish, // master
      HintTechnique.nakedPair, // medium
    ]);

    final evaluated = evaluator.evaluate(result);

    expect(evaluated.highestDifficulty, Difficulty.master);
    expect(evaluated.highestTechnique, HintTechnique.swordfish);
  });

  test('within the same tier, highestTechnique is broken by whichever has '
      'the larger humanSolverTechniqueOrder index', () {
    final result =
        _resultFor([HintTechnique.nakedTriple, HintTechnique.hiddenTriple]);

    expect(techniqueDifficulty[HintTechnique.nakedTriple], Difficulty.medium);
    expect(techniqueDifficulty[HintTechnique.hiddenTriple], Difficulty.medium);
    expect(
      humanSolverTechniqueOrder.indexOf(HintTechnique.hiddenTriple),
      greaterThan(humanSolverTechniqueOrder.indexOf(HintTechnique.nakedTriple)),
    );

    final evaluated = evaluator.evaluate(result);

    expect(evaluated.highestDifficulty, Difficulty.medium);
    expect(evaluated.highestTechnique, HintTechnique.hiddenTriple);
  });

  test('an empty history (already-solved input) has no highest technique '
      'and defaults to beginner difficulty', () {
    final evaluated = evaluator.evaluate(_resultFor(const []));

    expect(evaluated.highestTechnique, isNull);
    expect(evaluated.highestDifficulty, Difficulty.beginner);
  });

  test('guessed is always false — HumanSolver never backtracks', () {
    expect(evaluator.evaluate(_resultFor(const [])).guessed, isFalse);
    expect(
      evaluator.evaluate(_resultFor([HintTechnique.xyChain])).guessed,
      isFalse,
    );
  });

  test('solveHistory and techniqueCounts pass through the SolveResult '
      'unchanged', () {
    final history = [
      HintTechnique.nakedSingle,
      HintTechnique.nakedSingle,
      HintTechnique.hiddenSingle,
    ];
    final result = _resultFor(history);

    final evaluated = evaluator.evaluate(result);

    expect(evaluated.solveHistory, history);
    expect(evaluated.techniqueCounts, {
      HintTechnique.nakedSingle: 2,
      HintTechnique.hiddenSingle: 1,
    });
  });

  test('solved is passed through unchanged, and highestDifficulty is still '
      'computed from whatever history exists even when unsolved — needed '
      'for the generator to evaluate intermediate dig states', () {
    final result = _resultFor([HintTechnique.intersectionPointing],
        solved: false);

    final evaluated = evaluator.evaluate(result);

    expect(evaluated.solved, isFalse);
    expect(evaluated.highestDifficulty, Difficulty.easy);
    expect(evaluated.highestTechnique, HintTechnique.intersectionPointing);
  });

  test('score is the sum of every applied step\'s techniqueBaseScore', () {
    // nakedSingle 4 + 4, hiddenSingle 14 → 22.
    final evaluated = evaluator.evaluate(_resultFor([
      HintTechnique.nakedSingle,
      HintTechnique.nakedSingle,
      HintTechnique.hiddenSingle,
    ]));

    expect(evaluated.score, 22);
  });

  test('a high cumulative score promotes the tier above the hardest '
      'technique\'s floor, while floorDifficulty keeps the floor', () {
    // 10 Intersection Pointings: floor tier is easy, but 10 * 50 = 500 lands
    // in the medium score band ([450, 700)), so the puzzle promotes.
    final evaluated = evaluator.evaluate(_resultFor(
      List.filled(10, HintTechnique.intersectionPointing),
    ));

    expect(evaluated.score, 500);
    expect(evaluated.floorDifficulty, Difficulty.easy);
    expect(evaluated.highestDifficulty, Difficulty.medium);
    expect(evaluated.highestTechnique, HintTechnique.intersectionPointing);
  });

  test('a low cumulative score never demotes below the hardest technique\'s '
      'tier — the floor is a floor', () {
    // A single XYZ-Wing (master, base 180) scores only 180, well inside the
    // beginner band, but the floor keeps it at master.
    final evaluated =
        evaluator.evaluate(_resultFor([HintTechnique.xyzWing]));

    expect(scoreBand(evaluated.score), Difficulty.beginner);
    expect(evaluated.highestDifficulty, Difficulty.master);
  });

  test('one representative technique per tier maps to the expected '
      'difficulty', () {
    expect(
      evaluator.evaluate(_resultFor([HintTechnique.nakedSingle]))
          .highestDifficulty,
      Difficulty.beginner,
    );
    expect(
      evaluator.evaluate(_resultFor([HintTechnique.hiddenSingle]))
          .highestDifficulty,
      Difficulty.easy,
    );
    expect(
      evaluator
          .evaluate(_resultFor([HintTechnique.intersectionClaiming]))
          .highestDifficulty,
      Difficulty.easy,
    );
    expect(
      evaluator.evaluate(_resultFor([HintTechnique.hiddenPair]))
          .highestDifficulty,
      Difficulty.medium,
    );
    expect(
      evaluator.evaluate(_resultFor([HintTechnique.xWing]))
          .highestDifficulty,
      Difficulty.hard,
    );
    expect(
      evaluator.evaluate(_resultFor([HintTechnique.xyzWing]))
          .highestDifficulty,
      Difficulty.master,
    );
    expect(
      evaluator.evaluate(_resultFor([HintTechnique.uniqueRectangleType4]))
          .highestDifficulty,
      Difficulty.expert,
    );
  });
}
