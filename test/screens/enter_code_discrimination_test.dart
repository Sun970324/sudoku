import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/difficulty.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/models/sudoku_puzzle.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/puzzle_share_service.dart';

// Mirrors EnterCodeScreen's classifier: a friend room code is exactly 6
// chars from the room alphabet (0/O/1/I/L excluded), matched uppercase.
final _roomCodePattern = RegExp(r'^[2-9A-HJKMNP-Z]{6}$');
bool _isRoomCode(String raw) =>
    _roomCodePattern.hasMatch(raw.trim().toUpperCase());

void main() {
  group('room-code vs puzzle-code discrimination', () {
    test('a 6-char room code is recognized, upper or lower case', () {
      expect(_isRoomCode('ABCDEF'), isTrue);
      expect(_isRoomCode('abcdef'), isTrue);
      expect(_isRoomCode('  Q7K2MN '), isTrue);
    });

    test('excluded lookalike chars (0 O 1 I L) are not room codes', () {
      expect(_isRoomCode('ABC0EF'), isFalse); // 0
      expect(_isRoomCode('ABCOEF'), isFalse); // O
      expect(_isRoomCode('ABC1EF'), isFalse); // 1
      expect(_isRoomCode('ABCIEF'), isFalse); // I
      expect(_isRoomCode('ABCLEF'), isFalse); // L
    });

    test('wrong length is not a room code', () {
      expect(_isRoomCode('ABCDE'), isFalse);
      expect(_isRoomCode('ABCDEFG'), isFalse);
    });

    test('a real puzzle share code is far longer than 6 chars, so it never '
        'matches the room-code pattern', () {
      final solved = BoardGenerator(random: Random(7)).generateSolvedBoard();
      final givens = ClueRemover(random: Random(7)).removeClues(solved, 30);
      final puzzle = SudokuPuzzle(
        puzzle: SudokuGrid(givens),
        solution: SudokuGrid(solved),
        fixedMask:
            List.generate(9, (r) => List.generate(9, (c) => givens[r][c] != 0)),
        difficulty: Difficulty.medium,
      );
      final code = PuzzleShareService().encodeText(puzzle);

      expect(code.length, greaterThan(6));
      expect(_isRoomCode(code), isFalse);
    });
  });
}
