import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';

Map<String, dynamic> _jsonWith(String difficultyName) => {
      'puzzle': SudokuGrid.empty().toJson(),
      'solution': SudokuGrid.empty().toJson(),
      'fixedMask': List.generate(9, (_) => List.filled(9, false)),
      'difficulty': difficultyName,
    };

void main() {
  test('fromJson parses the current difficulty names', () {
    for (final difficulty in Difficulty.values) {
      final puzzle = SudokuPuzzle.fromJson(_jsonWith(difficulty.name));
      expect(puzzle.difficulty, difficulty);
    }
  });

  test('fromJson treats a locally-saved "challenger" as expert — the '
      'enum value name before it was renamed to match generator.md', () {
    final puzzle = SudokuPuzzle.fromJson(_jsonWith('challenger'));
    expect(puzzle.difficulty, Difficulty.expert);
  });

  test('toJson/fromJson round-trips every difficulty using its current '
      'name', () {
    for (final difficulty in Difficulty.values) {
      final original = SudokuPuzzle(
        puzzle: SudokuGrid.empty(),
        solution: SudokuGrid.empty(),
        fixedMask: List.generate(9, (_) => List.filled(9, false)),
        difficulty: difficulty,
      );
      final roundTripped = SudokuPuzzle.fromJson(original.toJson());
      expect(roundTripped.difficulty, difficulty);
    }
  });
}
