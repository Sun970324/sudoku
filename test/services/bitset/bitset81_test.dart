import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/services/generation/bitset/bitset81.dart';

BitSet81 _setOf(Iterable<int> indices) {
  final set = BitSet81();
  for (final i in indices) {
    set.add(i);
  }
  return set;
}

void main() {
  group('BitSet81 basics', () {
    test('add/remove/contains across both words', () {
      final set = BitSet81();
      expect(set.isEmpty, isTrue);
      for (final i in [0, 1, 63, 64, 80]) {
        expect(set.contains(i), isFalse);
        set.add(i);
        expect(set.contains(i), isTrue);
      }
      expect(set.isEmpty, isFalse);
      expect(set.count, 5);

      set.remove(63);
      expect(set.contains(63), isFalse);
      expect(set.count, 4);
      // Removing an absent index is a no-op.
      set.remove(63);
      expect(set.count, 4);
    });

    test('high-word indices (>= 64) do not leak into the low word', () {
      final set = BitSet81()..add(64);
      expect(set.contains(0), isFalse);
      expect(set.contains(64), isTrue);
      expect(set.count, 1);

      final all = BitSet81.all();
      expect(all.count, 81);
      for (var i = 0; i < 81; i++) {
        expect(all.contains(i), isTrue);
      }
    });

    test('clear empties the set', () {
      final set = _setOf([0, 40, 80]);
      set.clear();
      expect(set.isEmpty, isTrue);
      expect(set.count, 0);
      expect(set.toList(), isEmpty);
    });
  });

  group('BitSet81 set algebra', () {
    test('in-place union / intersect / subtract', () {
      final a = _setOf([1, 2, 3, 70]);
      final b = _setOf([3, 4, 70, 71]);

      final union = a.copy()..union(b);
      expect(union.toList(), [1, 2, 3, 4, 70, 71]);

      final inter = a.copy()..intersect(b);
      expect(inter.toList(), [3, 70]);

      final diff = a.copy()..subtract(b);
      expect(diff.toList(), [1, 2]);
    });

    test('non-mutating |, &, difference leave operands untouched', () {
      final a = _setOf([1, 2, 3, 70]);
      final b = _setOf([3, 4, 70, 71]);
      final aBefore = a.toList();
      final bBefore = b.toList();

      expect((a | b).toList(), [1, 2, 3, 4, 70, 71]);
      expect((a & b).toList(), [3, 70]);
      expect(a.difference(b).toList(), [1, 2]);

      expect(a.toList(), aBefore);
      expect(b.toList(), bBefore);
    });

    test('intersects and containsAll (subset)', () {
      final a = _setOf([1, 2, 3, 70]);
      final sub = _setOf([2, 70]);
      final disjoint = _setOf([4, 5, 71]);

      expect(a.intersects(sub), isTrue);
      expect(a.intersects(disjoint), isFalse);

      expect(a.containsAll(sub), isTrue);
      expect(a.containsAll(a), isTrue);
      expect(a.containsAll(BitSet81()), isTrue); // empty is a subset
      expect(sub.containsAll(a), isFalse);
      expect(a.containsAll(disjoint), isFalse);
    });
  });

  group('BitSet81 enumeration', () {
    test('toList is ascending and spans both words', () {
      final indices = [0, 5, 63, 64, 65, 80];
      expect(_setOf(indices.reversed).toList(), indices);
    });

    test('forEach visits every element in ascending order', () {
      final indices = [2, 8, 40, 63, 64, 79];
      final visited = <int>[];
      _setOf(indices).forEach(visited.add);
      expect(visited, indices);
    });
  });

  group('BitSet81 equality / copy', () {
    test('value equality and hashCode', () {
      final a = _setOf([1, 40, 80]);
      final b = _setOf([80, 1, 40]);
      final c = _setOf([1, 40]);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('copy is independent of the original', () {
      final original = _setOf([1, 2, 3]);
      final clone = original.copy();
      clone.add(80);
      original.remove(1);

      // The clone keeps 1 (copied before original.remove) and gains 80;
      // the original loses 1 and never sees 80 — proving independence.
      expect(clone.toList(), [1, 2, 3, 80]);
      expect(original.toList(), [2, 3]);
    });
  });
}
