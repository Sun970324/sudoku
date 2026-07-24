import 'bitset81.dart';
import 'candidates.dart';
import 'geometry.dart';

/// Lossless conversions between the app's plain data shapes and the
/// bitset-based representations. Every function here round-trips exactly, so
/// techniques can move a puzzle into bitset form, work on it, and hand back a
/// board/candidate grid indistinguishable from the input.

/// Converts a 9x9 [board] (0 = empty) into HoDoKu-style digit-position sets:
/// a `List<BitSet81>` of length 10 where entry `d` (1..9) holds every cell in
/// which digit `d` is placed. Entry 0 is always empty (kept only so callers
/// can index directly by digit).
List<BitSet81> boardToDigitPositions(List<List<int>> board) {
  final positions = List.generate(10, (_) => BitSet81());
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      final digit = board[r][c];
      if (digit != 0) positions[digit].add(BitsetGeometry.cellIndex(r, c));
    }
  }
  return positions;
}

/// Inverse of [boardToDigitPositions]: rebuilds the 9x9 board (0 = empty).
List<List<int>> digitPositionsToBoard(List<BitSet81> positions) {
  final board = List.generate(9, (_) => List.filled(9, 0));
  for (var d = 1; d <= 9; d++) {
    positions[d].forEach((cell) {
      board[BitsetGeometry.rowOf(cell)][BitsetGeometry.colOf(cell)] = d;
    });
  }
  return board;
}

/// Converts a 9x9 grid of candidate [Set]s into a flat 81-cell candidate-mask
/// grid (see [candidates.dart]).
List<int> candidatesToMasks(List<List<Set<int>>> candidates) {
  final masks = emptyCandidateGrid();
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      var mask = 0;
      for (final d in candidates[r][c]) {
        mask = candAdd(mask, d);
      }
      masks[BitsetGeometry.cellIndex(r, c)] = mask;
    }
  }
  return masks;
}

/// Inverse of [candidatesToMasks]: rebuilds the 9x9 grid of candidate sets.
List<List<Set<int>>> masksToCandidates(List<int> masks) {
  return List.generate(
    9,
    (r) => List.generate(
      9,
      (c) => candDigits(masks[BitsetGeometry.cellIndex(r, c)]).toSet(),
    ),
  );
}
