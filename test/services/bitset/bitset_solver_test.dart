import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/services/generation/bitset/bitset_solver.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/human_solver.dart';

// THE parity milestone: the differential runs the existing HumanSolver with
// its FULL generation technique order — BitsetSolver must solve everything it
// solves. (Locked Pair/Triple come out of BitsetSolver's Naked Subset run;
// wxyzWing/alsXZ out of its ALS-XZ pass — different labels, same power.)
const _humanFull = humanSolverTechniqueOrder;

void main() {
  test('BitsetSolver never places a wrong digit, and solves every board the '
      'equivalent HumanSolver solves — to the identical grid (differential)',
      () {
    final human = HumanSolver(techniqueOrder: _humanFull);
    final bit = BitsetSolver();
    final rng = Random(7);

    var humanSolved = 0;
    var probed = 0;
    for (var i = 0; i < 300; i++) {
      final solution = BoardGenerator(random: rng).generateSolvedBoard();
      // 26..37 givens: dense boards exercise singles/subsets, sparse ones
      // reach the chain/ALS tail of the order.
      final target = 26 + rng.nextInt(12);
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

  group('phase-3 port fixtures (remote pair / UR — zero or unverifiable '
      'live coverage in the random probe)', () {
    List<List<Set<int>>> candidatesFrom(Map<List<int>, Set<int>> entries) {
      final grid =
          List.generate(9, (_) => List.generate(9, (_) => <int>{}));
      entries.forEach((cell, digits) {
        grid[cell[0]][cell[1]] = {...digits};
      });
      return grid;
    }

    final emptyBoard = List.generate(9, (_) => List.filled(9, 0));

    test('Remote Pair: 4-cell {1,2} chain — (0,7) sees both ends and loses '
        'BOTH digits', () {
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.remotePair,
        emptyBoard,
        candidatesFrom({
          [0, 0]: {1, 2},
          [0, 4]: {1, 2},
          [5, 4]: {1, 2},
          [5, 7]: {1, 2},
          [0, 7]: {1, 2, 9},
        }),
      );
      expect(after, isNotNull);
      expect(after![0][7], {9});
    });

    test('Remote Pair: differing pairs break the alternation — no find', () {
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.remotePair,
        emptyBoard,
        candidatesFrom({
          [0, 0]: {1, 2},
          [0, 4]: {1, 3},
          [5, 4]: {1, 2},
          [5, 7]: {1, 2},
          [0, 7]: {1, 2, 9},
        }),
      );
      expect(after, isNull);
    });

    test('UR Type 1: three pure {1,2} corners — the extra corner loses both '
        'deadly digits', () {
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.uniqueRectangleType1,
        emptyBoard,
        candidatesFrom({
          [0, 0]: {1, 2},
          [1, 0]: {1, 2},
          [0, 3]: {1, 2},
          [1, 3]: {1, 2, 3},
        }),
      );
      expect(after, isNotNull);
      expect(after![1][3], {3});
    });

    test('UR Type 1: all four corners pure — nothing to resolve', () {
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.uniqueRectangleType1,
        emptyBoard,
        candidatesFrom({
          [0, 0]: {1, 2},
          [1, 0]: {1, 2},
          [0, 3]: {1, 2},
          [1, 3]: {1, 2},
        }),
      );
      expect(after, isNull);
    });

    test('UR Type 4: digit 1 conjugate-locked on the roof column strips '
        'digit 2 from both roof cells', () {
      // Floor (column 0) pure {1,2}; roof (column 3) carries extras. Digit 1
      // appears in column 3 only at the two roof cells, so 2 would complete
      // the deadly rectangle and is removed from both.
      final after = BitsetSolver().debugApplyOnce(
        HintTechnique.uniqueRectangleType4,
        emptyBoard,
        candidatesFrom({
          [0, 0]: {1, 2},
          [1, 0]: {1, 2},
          [0, 3]: {1, 2, 3},
          [1, 3]: {1, 2, 4},
        }),
      );
      expect(after, isNotNull);
      expect(after![0][3], {1, 3});
      expect(after[1][3], {1, 4});
    });
  });

  test('Multi-Coloring port fires on the known multi-coloring position '
      '(same fixture as multi_coloring_test.dart) and strikes 5 from (6,4)',
      () {
    // A singles-stall board where two separate color clusters for digit 5
    // exist and Simple Coloring does not apply — found by search, verified
    // against the hint engine in multi_coloring_test.dart.
    const board = [
      [8, 0, 4, 7, 0, 1, 6, 3, 9],
      [0, 3, 0, 6, 0, 0, 0, 1, 0],
      [1, 0, 6, 3, 0, 9, 0, 0, 0],
      [6, 4, 5, 9, 0, 0, 1, 7, 2],
      [7, 0, 0, 2, 0, 0, 3, 8, 5],
      [3, 8, 2, 5, 1, 7, 9, 6, 4],
      [0, 0, 8, 1, 0, 0, 0, 4, 3],
      [4, 6, 3, 8, 9, 0, 7, 0, 1],
      [2, 0, 0, 4, 0, 0, 8, 9, 6],
    ];
    final candidates = SudokuGrid(
            board.map((r) => List<int>.from(r)).toList())
        .allCandidates();
    // Simple coloring must not fire here (so multi genuinely owns the step).
    expect(
        BitsetSolver().debugApplyOnce(
            HintTechnique.simpleColoring,
            board.map((r) => List<int>.from(r)).toList(),
            candidates),
        isNull);
    final after = BitsetSolver().debugApplyOnce(
        HintTechnique.multiColoring,
        board.map((r) => List<int>.from(r)).toList(),
        candidates);
    expect(after, isNotNull);
    expect(after![6][4], isNot(contains(5)));
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
