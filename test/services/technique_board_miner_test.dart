import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/difficulty_evaluator.dart';
import 'package:sudoku/services/generation/human_solver.dart';
import 'package:sudoku/services/generation/technique_board_miner.dart';

void main() {
  // A real dug board (seeded, deterministic), full-solved once so the tests
  // below can assert acceptance against its actual path and tier.
  final board = ClueRemover(random: Random(11))
      .removeClues(BoardGenerator(random: Random(11)).generateSolvedBoard(), 40);
  final result =
      HumanSolver(techniqueOrder: minableOrder).solve(board);
  final evaluated = DifficultyEvaluator().evaluate(result);

  test('fixture sanity: the seeded board full-solves', () {
    expect(result.solved, isTrue);
    expect(result.history, isNotEmpty);
  });

  test('boardShowsItem accepts every technique that appears in the full '
      'solve path (HoDoKu LEARNING contains-semantics, no tier cap)', () {
    for (final technique in result.techniqueCounts.keys) {
      expect(boardShowsItem({technique}, board), isTrue,
          reason: '$technique appears in the path but was rejected');
    }
  });

  test('boardShowsItem rejects a technique absent from the solve path', () {
    final absent =
        minableOrder.where((t) => !result.techniqueCounts.containsKey(t));
    expect(absent, isNotEmpty,
        reason: 'fixture must leave at least one technique unused');
    expect(boardShowsItem({absent.first}, board), isFalse);
  });

  test('boardShowsItemAtDifficulty additionally requires the evaluated tier '
      'to match (HoDoKu PRACTISING acceptance)', () {
    final shown = result.techniqueCounts.keys.first;
    expect(
        boardShowsItemAtDifficulty(
            {shown}, board, evaluated.highestDifficulty),
        isTrue);
    final otherTier = Difficulty.values
        .firstWhere((d) => d != evaluated.highestDifficulty);
    expect(boardShowsItemAtDifficulty({shown}, board, otherTier), isFalse);
  });
}
