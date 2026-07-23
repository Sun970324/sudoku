import 'dart:math';

import '../../models/hint.dart';
import '../../models/sudoku_grid.dart';
import '../../models/sudoku_puzzle.dart';
import '../hint_engine.dart';
import 'board_generator.dart';
import 'clue_remover.dart';
import 'minimalizer.dart';

/// Digs one solved board to several depths — shallow boards feed the
/// reveal/single techniques, deep minimalized ones the hard families.
const _digTargets = [80, 55, 40, 30];

/// Mines one puzzle on which [technique]'s own finder fires (on fresh
/// candidates) with a conclusion matching the real solution — the refill
/// source behind [TechniqueQueueManager]. Scans up to [maxBoards] random
/// boards (each probed at several dig depths) and returns null when the
/// budget runs out, which the caller treats as "retry later"; rare
/// techniques (Triple Firework fires on ~0.6% of dug boards) simply take a
/// few attempts. BUG+1 is unminable this way by design — its precondition
/// never arises on fresh candidates — and is excluded from the demo/queue
/// feature entirely.
SudokuPuzzle? mineTechniqueBoard(
  HintTechnique technique, {
  int maxBoards = 600,
  Random? random,
}) {
  final rng = random ?? Random();
  final engine = HintEngine();

  bool sound(Hint hint, List<List<int>> solution) {
    if (hint.type == HintType.reveal) {
      return solution[hint.row!][hint.col!] == hint.value;
    }
    return hint.eliminations.every((e) => solution[e.row][e.col] != e.digit);
  }

  SudokuPuzzle? tryBoard(List<List<int>> board, List<List<int>> solution) {
    final hint = engine.findTechnique(technique, board);
    if (hint == null || hint.technique != technique || !sound(hint, solution)) {
      return null;
    }
    return SudokuPuzzle(
      puzzle: SudokuGrid(board.map((r) => List<int>.from(r)).toList()),
      solution: SudokuGrid(solution.map((r) => List<int>.from(r)).toList()),
      fixedMask: List.generate(
          9, (r) => List.generate(9, (c) => board[r][c] != 0)),
      difficulty: techniqueDifficulty[technique]!,
    );
  }

  for (var i = 0; i < maxBoards; i++) {
    final solution = BoardGenerator(random: rng).generateSolvedBoard();
    for (final target in _digTargets) {
      final dug = ClueRemover(random: rng).removeClues(solution, target);
      final found = tryBoard(dug, solution);
      if (found != null) return found;
    }
    final minimal = Minimalizer(random: rng)
        .minimalize(ClueRemover(random: rng).removeClues(solution, 24));
    final found = tryBoard(minimal, solution);
    if (found != null) return found;
  }
  return null;
}
