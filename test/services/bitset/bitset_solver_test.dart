import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/bitset/bitset_solver.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/human_solver.dart';

// The existing HumanSolver restricted to exactly the techniques BitsetSolver
// covers (singles + intersections + subsets). Locked Pair/Triple are included
// here because BitsetSolver's Naked Subset run produces their eliminations too.
const _phase1Human = <HintTechnique>[
  HintTechnique.fullHouse,
  HintTechnique.nakedSingle,
  HintTechnique.hiddenSingle,
  HintTechnique.intersectionPointing,
  HintTechnique.intersectionClaiming,
  HintTechnique.lockedPair,
  HintTechnique.nakedPair,
  HintTechnique.hiddenPair,
  HintTechnique.lockedTriple,
  HintTechnique.nakedTriple,
  HintTechnique.hiddenTriple,
  HintTechnique.nakedQuad,
  HintTechnique.hiddenQuad,
];

void main() {
  test('BitsetSolver never places a wrong digit, and solves every board the '
      'equivalent HumanSolver solves — to the identical grid (differential)',
      () {
    final human = HumanSolver(techniqueOrder: _phase1Human);
    final bit = BitsetSolver();
    final rng = Random(7);

    var humanSolved = 0;
    var probed = 0;
    for (var i = 0; i < 300; i++) {
      final solution = BoardGenerator(random: rng).generateSolvedBoard();
      // Vary givens so both easy (singles) and subset/intersection boards appear.
      final target = 30 + rng.nextInt(8); // 30..37
      final dug = ClueRemover(random: rng).removeClues(solution, target);
      probed++;

      final bRes = bit.solve(dug);
      // Correctness invariant: every cell BitsetSolver filled must match the
      // puzzle's unique solution — no wrong placements, even when it stalls.
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (bRes.board[r][c] != 0) {
            expect(bRes.board[r][c], solution[r][c],
                reason: 'bitset placed a wrong digit at ($r,$c) on board $i');
          }
        }
      }

      final hRes = human.solve(dug);
      if (hRes.solved) {
        humanSolved++;
        // Anything the equivalent human solver cracks, the bitset solver must
        // crack too, reaching the same (unique) solution.
        expect(bRes.solved, isTrue,
            reason: 'HumanSolver solved board $i but BitsetSolver did not');
        expect(bRes.board, equals(solution),
            reason: 'bitset solution differs from the true solution on $i');
      }
    }

    expect(probed, 300);
    // Sanity: the sample actually exercised Phase-1-solvable boards.
    expect(humanSolved, greaterThan(20),
        reason: 'too few Phase-1-solvable boards to be a meaningful check');
  });

  test('BitsetSolver logs the techniques it used, cheapest-first', () {
    // A near-complete board solves by Full House / singles only.
    final solution =
        BoardGenerator(random: Random(1)).generateSolvedBoard();
    final dug = ClueRemover(random: Random(1)).removeClues(solution, 55);
    final res = BitsetSolver().solve(dug);
    expect(res.solved, isTrue);
    expect(res.board, equals(solution));
    expect(res.history, isNotEmpty);
    expect(res.history.every(BitsetSolver.order.contains), isTrue);
  });

  test('enabled filter restricts which techniques run', () {
    // With only singles enabled, a board needing a subset/intersection stays
    // unsolved rather than using a disabled technique.
    final solution =
        BoardGenerator(random: Random(3)).generateSolvedBoard();
    final dug = ClueRemover(random: Random(3)).removeClues(solution, 30);
    final res = BitsetSolver().solve(dug, enabled: const {
      HintTechnique.fullHouse,
      HintTechnique.nakedSingle,
      HintTechnique.hiddenSingle,
    });
    expect(
        res.history.every((t) => const {
              HintTechnique.fullHouse,
              HintTechnique.nakedSingle,
              HintTechnique.hiddenSingle,
            }.contains(t)),
        isTrue);
  });
}
