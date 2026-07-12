import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/generation/board_generator.dart';

bool _isCompleteAndValid(List<List<int>> cells) {
  bool groupIsValid(Iterable<int> values) {
    final sorted = values.toList()..sort();
    return sorted.join(',') == List.generate(9, (i) => i + 1).join(',');
  }

  for (var r = 0; r < 9; r++) {
    if (!groupIsValid(cells[r])) return false;
  }
  for (var c = 0; c < 9; c++) {
    if (!groupIsValid([for (var r = 0; r < 9; r++) cells[r][c]])) {
      return false;
    }
  }
  for (var boxRow = 0; boxRow < 3; boxRow++) {
    for (var boxCol = 0; boxCol < 3; boxCol++) {
      final box = [
        for (var r = boxRow * 3; r < boxRow * 3 + 3; r++)
          for (var c = boxCol * 3; c < boxCol * 3 + 3; c++) cells[r][c],
      ];
      if (!groupIsValid(box)) return false;
    }
  }
  return true;
}

void main() {
  test('generateSolvedBoard produces a fully valid, complete grid', () {
    final board = BoardGenerator(random: Random(1)).generateSolvedBoard();
    expect(_isCompleteAndValid(board), isTrue);
  });

  test('generateSolvedBoard fills every cell (no zeros left)', () {
    final board = BoardGenerator(random: Random(2)).generateSolvedBoard();
    for (final row in board) {
      expect(row.contains(0), isFalse);
    }
  });

  test('different seeds produce different boards', () {
    final a = BoardGenerator(random: Random(1)).generateSolvedBoard();
    final b = BoardGenerator(random: Random(2)).generateSolvedBoard();
    expect(a, isNot(equals(b)));
  });

  test('the same seed produces the same board (deterministic)', () {
    final a = BoardGenerator(random: Random(7)).generateSolvedBoard();
    final b = BoardGenerator(random: Random(7)).generateSolvedBoard();
    expect(a, equals(b));
  });
}
