import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/generation/bitset/geometry.dart';

/// Independent, hand-rolled peer computation to check the precomputed table
/// against (row ∪ col ∪ box, minus the cell itself).
Set<int> _peersOf(int cell) {
  final row = cell ~/ 9;
  final col = cell % 9;
  final boxRow = (row ~/ 3) * 3;
  final boxCol = (col ~/ 3) * 3;
  final peers = <int>{};
  for (var c = 0; c < 9; c++) {
    peers.add(row * 9 + c);
  }
  for (var r = 0; r < 9; r++) {
    peers.add(r * 9 + col);
  }
  for (var r = boxRow; r < boxRow + 3; r++) {
    for (var c = boxCol; c < boxCol + 3; c++) {
      peers.add(r * 9 + c);
    }
  }
  peers.remove(cell);
  return peers;
}

void main() {
  group('index math', () {
    test('rowOf / colOf / boxOf / cellIndex are consistent', () {
      for (var cell = 0; cell < 81; cell++) {
        final r = BitsetGeometry.rowOf(cell);
        final c = BitsetGeometry.colOf(cell);
        expect(BitsetGeometry.cellIndex(r, c), cell);
      }
      expect(BitsetGeometry.boxOf(0), 0);
      expect(BitsetGeometry.boxOf(40), 4); // centre cell -> centre box
      expect(BitsetGeometry.boxOf(80), 8);
      expect(BitsetGeometry.boxOf(BitsetGeometry.cellIndex(2, 6)), 2);
    });
  });

  group('buddy table', () {
    test('cell 0 has exactly its row+col+box peers (20 cells)', () {
      final buddies = BitsetGeometry.buddies[0];
      expect(buddies.count, 20);
      expect(buddies.toList().toSet(), _peersOf(0));
    });

    test('centre cell 40 matches a hand-computed peer set', () {
      expect(BitsetGeometry.buddies[40].toList().toSet(), _peersOf(40));
    });

    test('every cell has exactly 20 buddies, never itself, matches _peersOf',
        () {
      for (var cell = 0; cell < 81; cell++) {
        final buddies = BitsetGeometry.buddies[cell];
        expect(buddies.count, 20, reason: 'cell $cell');
        expect(buddies.contains(cell), isFalse, reason: 'cell $cell');
        expect(buddies.toList().toSet(), _peersOf(cell), reason: 'cell $cell');
      }
    });
  });

  group('unit table', () {
    test('there are 27 units, each with 9 cells', () {
      expect(BitsetGeometry.units.length, 27);
      for (final unit in BitsetGeometry.units) {
        expect(unit.count, 9);
      }
    });

    test('every cell belongs to exactly 3 units (its row, col, box)', () {
      for (var cell = 0; cell < 81; cell++) {
        final memberships =
            BitsetGeometry.units.where((u) => u.contains(cell)).length;
        expect(memberships, 3, reason: 'cell $cell');
      }
    });

    test('unit indices map to the expected row/col/box', () {
      // Row 3 = cells 27..35.
      expect(BitsetGeometry.units[3].toList(),
          [for (var c = 0; c < 9; c++) 27 + c]);
      // Column 5 = cells 5, 14, 23, ...
      expect(BitsetGeometry.units[9 + 5].toList(),
          [for (var r = 0; r < 9; r++) r * 9 + 5]);
      // Box 4 (centre) = rows 3..5, cols 3..5.
      expect(
        BitsetGeometry.units[18 + 4].toList().toSet(),
        {
          for (var r = 3; r < 6; r++)
            for (var c = 3; c < 6; c++) r * 9 + c,
        },
      );
    });
  });
}
