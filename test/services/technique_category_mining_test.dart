import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/generation/human_solver.dart';
import 'package:sudoku/services/generation/technique_board_miner.dart';

int _givens(SudokuPuzzle p) =>
    p.puzzle.toJson().expand((r) => r).where((v) => v != 0).length;

void main() {
  test('categoryCeilingOrder includes this-and-easier categories only', () {
    final ceiling = categoryCeilingOrder(TechniqueCategory.subsets);
    expect(ceiling, contains(HintTechnique.nakedPair)); // subsets itself
    expect(ceiling, contains(HintTechnique.hiddenSingle)); // easier
    expect(ceiling, isNot(contains(HintTechnique.xWing))); // harder category
    expect(ceiling, isNot(contains(HintTechnique.aic)));
  });

  test('a mined Singles board is a genuine easy sudoku solvable by singles '
      'ALONE — not a near-complete grid with one Full House', () {
    final board = mineCategoryBoard(TechniqueCategory.singles,
        maxSeeds: 200, random: Random(7));
    expect(board, isNotNull);

    // Solvable using nothing but the three singles.
    final singlesOnly = HumanSolver(techniqueOrder: const [
      HintTechnique.fullHouse,
      HintTechnique.nakedSingle,
      HintTechnique.hiddenSingle,
    ]);
    expect(singlesOnly.solve(board!.puzzle.toJson()).solved, isTrue);

    // And a real puzzle, not the old ~55-given near-complete board.
    expect(_givens(board), lessThan(45),
        reason: 'Singles practice board should be a proper sparse puzzle');
  });

  test('a mined Subsets board actually requires a subset (not solvable by '
      'singles + intersections alone)', () {
    final board = mineCategoryBoard(TechniqueCategory.subsets,
        maxSeeds: 200, random: Random(9));
    expect(board, isNotNull);
    final cells = board!.puzzle.toJson();

    // Requires the Subsets ceiling...
    expect(boardRequiresCategory(TechniqueCategory.subsets, cells), isTrue);
    // ...and genuinely can't be finished with only the easier ceiling.
    final easier =
        HumanSolver(techniqueOrder: categoryCeilingOrder(
            TechniqueCategory.intersections));
    expect(easier.solve(cells).solved, isFalse);
  });
}
