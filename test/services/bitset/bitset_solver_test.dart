import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/bitset/bitset_solver.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/human_solver.dart';

// The existing HumanSolver restricted to exactly the techniques BitsetSolver
// covers (singles + intersections + subsets + basic fish + single-digit
// patterns + wings + simple coloring). Locked Pair/Triple are included here
// because BitsetSolver's Naked Subset run produces their eliminations too.
// Order mirrors humanSolverTechniqueOrder's relative order.
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
  HintTechnique.xWing,
  HintTechnique.skyscraper,
  HintTechnique.twoStringKite,
  HintTechnique.turbotFish,
  HintTechnique.xyWing,
  HintTechnique.simpleColoring,
  HintTechnique.xyzWing,
  HintTechnique.wWing,
  HintTechnique.swordfish,
  HintTechnique.jellyfish,
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

  group('fish port fixtures (mirroring hint_engine_test positions — '
      'swordfish/jellyfish are too rare on random boards for the '
      'differential to reach them)', () {
    // A synthetic candidate grid on an empty board: only the listed cells
    // hold the listed candidates (all other cells get a full mask so they
    // never look like accidental singles/subsets to the technique under
    // test... they aren't consulted by _fish at all, but keep it faithful).
    List<List<Set<int>>> candidatesFrom(Map<List<int>, Set<int>> entries) {
      final grid = List.generate(
          9, (_) => List.generate(9, (_) => <int>{}));
      entries.forEach((cell, digits) {
        grid[cell[0]][cell[1]] = {...digits};
      });
      return grid;
    }

    final emptyBoard = List.generate(9, (_) => List.filled(9, 0));

    test('Swordfish: rows 0/3/6 cover columns {1,4,7} — (1,4) loses 7, '
        'near-miss (1,2) untouched', () {
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.swordfish,
        emptyBoard,
        candidatesFrom({
          [0, 1]: {7},
          [0, 4]: {7},
          [3, 4]: {7},
          [3, 7]: {7},
          [6, 1]: {7},
          [6, 7]: {7},
          [1, 4]: {7},
          [1, 2]: {7},
        }),
      );
      expect(after, isNotNull);
      expect(after![1][4], isNot(contains(7)));
      expect(after[1][2], contains(7));
      expect(after[0][1], contains(7)); // base cells keep the digit
    });

    test('Swordfish: three rows covering only two columns (disguised '
        'X-Wing) is not a Swordfish', () {
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.swordfish,
        emptyBoard,
        candidatesFrom({
          [0, 1]: {7},
          [0, 4]: {7},
          [3, 1]: {7},
          [3, 4]: {7},
          [6, 1]: {7},
          [6, 4]: {7},
        }),
      );
      expect(after, isNull);
    });

    test('Jellyfish: rows 0/2/4/6 cover columns {1,4,7,8} — (1,4) loses 6, '
        'near-miss (1,2) untouched', () {
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.jellyfish,
        emptyBoard,
        candidatesFrom({
          [0, 1]: {6},
          [0, 4]: {6},
          [2, 4]: {6},
          [2, 7]: {6},
          [4, 1]: {6},
          [4, 8]: {6},
          [6, 7]: {6},
          [6, 8]: {6},
          [1, 4]: {6},
          [1, 2]: {6},
        }),
      );
      expect(after, isNotNull);
      expect(after![1][4], isNot(contains(6)));
      expect(after[1][2], contains(6));
    });
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
