import '../models/sudoku_grid.dart';
import '../models/sudoku_puzzle.dart';
import 'generation/difficulty_evaluator.dart';
import 'generation/bitset/bitset_solver.dart';
import 'sudoku_solver.dart';

class PuzzleShareException implements Exception {
  const PuzzleShareException();
}

/// Encodes/decodes a puzzle's givens as a self-contained text code — no
/// server round trip, so this works offline and needs no sign-in.
class PuzzleShareService {
  PuzzleShareService({
    SudokuSolver? solver,
    BitsetSolver? difficultySolver,
    DifficultyEvaluator? difficultyEvaluator,
  })  : _solver = solver ?? SudokuSolver(),
        _difficultySolver = difficultySolver ?? BitsetSolver(),
        _difficultyEvaluator = difficultyEvaluator ?? DifficultyEvaluator();

  final SudokuSolver _solver;
  final BitsetSolver _difficultySolver;
  final DifficultyEvaluator _difficultyEvaluator;

  static const _textCodeVersion = '1';
  static const _base62Chars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  /// Encodes just [puzzle]'s givens (81 cells) as a base62 string — the
  /// solution/fixedMask are re-derived on decode. A uniquely-solvable
  /// puzzle's solution is a deterministic function of its givens, unlike
  /// generator seeds, so nothing else needs to be encoded.
  String encodeText(SudokuPuzzle puzzle) {
    final digits = StringBuffer();
    for (final row in puzzle.puzzle.toJson()) {
      for (final value in row) {
        digits.write(value);
      }
    }
    final value = BigInt.parse(digits.toString());
    final checksum = _base62Chars[(value % BigInt.from(62)).toInt()];
    return '$_textCodeVersion${_toBase62(value)}$checksum';
  }

  SudokuPuzzle decodeText(String code) {
    if (code.length < 3 || code[0] != _textCodeVersion) {
      throw const PuzzleShareException();
    }
    final payload = code.substring(1, code.length - 1);
    final checksum = code[code.length - 1];
    final BigInt value;
    try {
      value = _fromBase62(payload);
    } on FormatException {
      throw const PuzzleShareException();
    }
    if (_base62Chars[(value % BigInt.from(62)).toInt()] != checksum) {
      throw const PuzzleShareException();
    }
    final digits = value.toString().padLeft(81, '0');
    if (digits.length != 81) {
      throw const PuzzleShareException();
    }
    final givens = List.generate(
      9,
      (r) => List.generate(9, (c) => int.parse(digits[r * 9 + c])),
    );
    final solved = _solver.solve(givens);
    if (solved == null) {
      throw const PuzzleShareException();
    }
    final fixedMask =
        List.generate(9, (r) => List.generate(9, (c) => givens[r][c] != 0));
    final evaluated = _difficultyEvaluator.evaluate(_difficultySolver.solve(givens).toSolveResult());
    return SudokuPuzzle(
      puzzle: SudokuGrid(givens),
      solution: SudokuGrid(solved),
      fixedMask: fixedMask,
      difficulty: evaluated.highestDifficulty,
    );
  }

  String _toBase62(BigInt value) {
    if (value == BigInt.zero) return '0';
    var remaining = value;
    const base = 62;
    final chars = <String>[];
    while (remaining > BigInt.zero) {
      chars.add(_base62Chars[(remaining % BigInt.from(base)).toInt()]);
      remaining = remaining ~/ BigInt.from(base);
    }
    return chars.reversed.join();
  }

  BigInt _fromBase62(String text) {
    var value = BigInt.zero;
    const base = 62;
    for (final char in text.split('')) {
      final digit = _base62Chars.indexOf(char);
      if (digit == -1) throw const FormatException('invalid base62 char');
      value = value * BigInt.from(base) + BigInt.from(digit);
    }
    return value;
  }
}
