import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/services/hint_engine.dart';
import 'package:sudoku/services/sudoku_solver.dart';

List<List<int>> _emptyBoard() => List.generate(9, (_) => List.filled(9, 0));

/// A deterministic, fully solved grid (SudokuSolver has no randomness).
List<List<int>> _solvedGrid() =>
    SudokuSolver().solve(_emptyBoard())!.map((row) => List<int>.from(row)).toList();

bool _hasElimination(Hint hint, int row, int col, int digit) => hint
    .eliminations
    .any((e) => e.row == row && e.col == col && e.digit == digit);

/// Builds a candidates grid directly from a sparse cell -> digit-set map,
/// leaving every other cell's candidate set empty — lets a fixture target
/// exactly the cells a technique cares about without deriving them from a
/// real (and fully consistent) board.
List<List<Set<int>>> candidatesFrom(Map<List<int>, Set<int>> cells) {
  final grid = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  cells.forEach((rc, digits) => grid[rc[0]][rc[1]] = digits);
  return grid;
}

void main() {
  final engine = HintEngine();

  group('findFullHouse', () {
    test('fills the lone empty cell in an otherwise complete row', () {
      final board = _solvedGrid();
      final expectedValue = board[0][0];
      board[0][0] = 0;

      final hint = engine.findFullHouse(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.fullHouse);
      expect(hint.type, HintType.reveal);
      expect(hint.row, 0);
      expect(hint.col, 0);
      expect(hint.value, expectedValue);
      expect(hint.primaryCells, {const HintCell(0, 0)});
      expect(hint.highlightedRows, {0});
    });

    test('returns null when every unit has more than one empty cell', () {
      final board = _emptyBoard();
      board[0] = [0, 0, 3, 4, 5, 6, 7, 8, 9];
      expect(engine.findFullHouse(board), isNull);
    });
  });

  group('findNakedSingle', () {
    test('finds a cell narrowed to exactly one candidate', () {
      final board = _emptyBoard();
      // Row 0 leaves {1, 9} at (0,0); column 0 rules out 9 via row 1.
      board[0] = [0, 2, 3, 4, 5, 6, 7, 8, 0];
      board[1][0] = 9;

      final hint = engine.findNakedSingle(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.nakedSingle);
      expect(hint.type, HintType.reveal);
      expect(hint.row, 0);
      expect(hint.col, 0);
      expect(hint.value, 1);
    });

    test('returns null when no empty cell has a single candidate', () {
      expect(engine.findNakedSingle(_emptyBoard()), isNull);
    });
  });

  group('findHiddenSingle', () {
    test('finds a digit confined to one cell within a unit', () {
      final board = _emptyBoard();
      // Row 0: only (0,0) and (0,1) are empty, both start with {1, 2}.
      // Placing 1 elsewhere in column 1 knocks it out of (0,1)'s
      // candidates, leaving digit 1 possible only at (0,0) in row 0 —
      // even though (0,0) itself still has 2 raw candidates, so this is
      // not also a naked single.
      board[0] = [0, 0, 3, 4, 5, 6, 7, 8, 9];
      board[5][1] = 1;

      final hint = engine.findHiddenSingle(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.hiddenSingle);
      expect(hint.type, HintType.reveal);
      expect(hint.row, 0);
      expect(hint.col, 0);
      expect(hint.value, 1);
      // Unit itself (row 0) is highlighted, plus column 1 — the "cause":
      // (0,1) is row 0's other empty cell, and it lost candidate 1 because
      // column 1 already has a 1 at (5,1).
      expect(hint.highlightedRows, {0});
      expect(hint.highlightedCols, {1});
      expect(hint.highlightedBoxes, isEmpty);
      // Same-unit cells as before, plus the actual blocking cell (5,1)
      // itself, colored just like any other reason cell.
      expect(hint.secondaryCells, {
        const HintCell(0, 1),
        const HintCell(0, 2),
        const HintCell(0, 3),
        const HintCell(0, 4),
        const HintCell(0, 5),
        const HintCell(0, 6),
        const HintCell(0, 7),
        const HintCell(0, 8),
        const HintCell(5, 1),
      });
    });

    test('returns null when no digit is confined to a single cell', () {
      expect(engine.findHiddenSingle(_emptyBoard()), isNull);
    });

    test(
        'highlights each distinct row/column that blocks a different other '
        'empty cell in the unit', () {
      // Box 0's only empty cells are (0,0), (0,1), (1,0); box 0's own
      // givens (1, 2, 3, 4, 6, 7) already rule out every value but 5 and
      // 8/9 there. Value 5 is further blocked at (0,1) by column 1's given
      // (5,1)=5, and at (1,0) by row 1's given (1,7)=5 — leaving only
      // (0,0) as a candidate, a hidden single confined to box 0.
      final board = _emptyBoard();
      board[0] = [0, 0, 1, 0, 0, 0, 0, 0, 0];
      board[1] = [0, 2, 3, 0, 0, 0, 0, 5, 0];
      board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];
      board[5][1] = 5;

      final hint = engine.findHiddenSingle(board);

      expect(hint, isNotNull);
      expect(hint!.row, 0);
      expect(hint.col, 0);
      expect(hint.value, 5);
      expect(hint.highlightedBoxes, {0});
      expect(hint.highlightedRows, {1});
      expect(hint.highlightedCols, {1});
      // Box 0's own cells (minus the target), plus the two actual blocking
      // cells: (1,7) blocks (1,0) via row 1, (5,1) blocks (0,1) via
      // column 1.
      expect(hint.secondaryCells, {
        const HintCell(0, 1),
        const HintCell(0, 2),
        const HintCell(1, 0),
        const HintCell(1, 1),
        const HintCell(1, 2),
        const HintCell(2, 0),
        const HintCell(2, 1),
        const HintCell(2, 2),
        const HintCell(1, 7),
        const HintCell(5, 1),
      });
    });
  });

  group('findNakedPair', () {
    test('eliminates the pair digits from other cells in the unit', () {
      final board = _emptyBoard();
      // Row 0 has 4 empty cells (cols 0-3). Column exclusions shape the
      // candidates so (0,0) and (0,1) both narrow to exactly {1, 2}
      // (a naked pair), while (0,2) keeps 1 as an extra candidate and
      // (0,3) keeps both 1 and 2 — both are valid elimination targets.
      board[0] = [0, 0, 0, 0, 5, 6, 7, 8, 9];
      board[5][0] = 3;
      board[5][1] = 4;
      board[5][2] = 2;
      board[6][0] = 4;
      board[6][1] = 3;
      board[7][2] = 4;

      final hint = engine.findNakedPair(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.nakedPair);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {const HintCell(0, 0), const HintCell(0, 1)});
      expect(hint.eliminations, hasLength(3));
      expect(_hasElimination(hint, 0, 2, 1), isTrue);
      expect(_hasElimination(hint, 0, 3, 1), isTrue);
      expect(_hasElimination(hint, 0, 3, 2), isTrue);
      expect(hint.highlightedRows, {0});
      expect(hint.primaryDigits, {1, 2});
    });

    test('a true pair with no eliminating effect is skipped, not returned', () {
      final board = _emptyBoard();
      // (0,0) and (0,4) both narrow to {1, 2} and share only row 0 (they
      // sit in different columns and different 3x3 boxes), and every
      // other cell in row 0 is already filled — so the row is the only
      // unit that could pair them, and it has nothing left to eliminate.
      board[0] = [0, 3, 4, 5, 0, 6, 7, 8, 9];
      expect(engine.findNakedPair(board), isNull);
    });
  });

  group('findNakedTriple', () {
    test(
        'eliminates the triple digits from other cells, even though no '
        'two of the three cells share the same candidate set', () {
      final board = _emptyBoard();
      // Row 0 has 4 empty cells (cols 0-3), base candidates {1,2,3,4} from
      // row exclusion alone. Column givens (rows 3-8, well outside box
      // (0,0)'s rows 0-2) shape a genuine "ring" triple: (0,0)={1,2},
      // (0,1)={2,3}, (0,2)={1,3} — no two of these three sets are equal,
      // only their 3-way union ({1,2,3}) is — so this is only catchable
      // via the general union check, not a naive pairwise-equality one.
      // (0,3) keeps its full base {1,2,3,4}, so 1,2,3 are all valid
      // elimination targets there.
      board[0] = [0, 0, 0, 0, 5, 6, 7, 8, 9];
      board[3][0] = 3; // excludes 3 from (0,0)
      board[4][0] = 4; // excludes 4 from (0,0)
      board[5][1] = 1; // excludes 1 from (0,1)
      board[6][1] = 4; // excludes 4 from (0,1)
      board[7][2] = 2; // excludes 2 from (0,2)
      board[8][2] = 4; // excludes 4 from (0,2)

      final hint = engine.findNakedTriple(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.nakedTriple);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 1),
        const HintCell(0, 2),
      });
      expect(hint.eliminations, hasLength(3));
      expect(_hasElimination(hint, 0, 3, 1), isTrue);
      expect(_hasElimination(hint, 0, 3, 2), isTrue);
      expect(_hasElimination(hint, 0, 3, 3), isTrue);
      expect(hint.highlightedRows, {0});
      expect(hint.primaryDigits, {1, 2, 3});
    });

    test('a true triple with no eliminating effect is skipped, not '
        'returned', () {
      final board = _emptyBoard();
      // Row 0's only 3 empty cells (cols 0, 3, 6) sit in three different
      // boxes and every other cell in the row is filled, so row 0 (the
      // only unit containing all three) has nothing left to eliminate
      // into, and no other unit anywhere on this otherwise-empty board has
      // enough constrained cells to form a triple pool of its own.
      board[0] = [0, 4, 5, 0, 6, 7, 0, 8, 9];
      expect(engine.findNakedTriple(board), isNull);
    });
  });

  group('findNakedQuad', () {
    test(
        'eliminates the quad digits from other cells, even though no '
        'combination of the four cells shares an identical candidate set',
        () {
      final board = _emptyBoard();
      // Row 0 has 5 empty cells (cols 0-4), base candidates {1,2,3,4,5}
      // from row exclusion alone. Column givens (rows 3-7, well outside
      // box (0,0)'s rows 0-2) shape a genuine "ring" quad: (0,0)={2,3,4},
      // (0,1)={1,3,4}, (0,2)={1,2,4}, (0,3)={1,2,3} — each cell is missing
      // exactly one of {1,2,3,4}, so no two cells share a set, only the
      // 4-way union ({1,2,3,4}) does. (0,4) keeps its full base
      // {1,2,3,4,5}, so 1,2,3,4 are all valid elimination targets there.
      board[0] = [0, 0, 0, 0, 0, 6, 7, 8, 9];
      board[3] = [1, 2, 3, 4, 0, 0, 0, 0, 0]; // excludes 1/2/3/4 from cols 0-3
      board[4][0] = 5; // excludes 5 from (0,0)
      board[5][1] = 5; // excludes 5 from (0,1)
      board[6][2] = 5; // excludes 5 from (0,2)
      board[7][3] = 5; // excludes 5 from (0,3)

      final hint = engine.findNakedQuad(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.nakedQuad);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 1),
        const HintCell(0, 2),
        const HintCell(0, 3),
      });
      expect(hint.eliminations, hasLength(4));
      expect(_hasElimination(hint, 0, 4, 1), isTrue);
      expect(_hasElimination(hint, 0, 4, 2), isTrue);
      expect(_hasElimination(hint, 0, 4, 3), isTrue);
      expect(_hasElimination(hint, 0, 4, 4), isTrue);
      expect(hint.highlightedRows, {0});
      expect(hint.primaryDigits, {1, 2, 3, 4});
    });

    test('a true quad with no eliminating effect is skipped, not returned',
        () {
      final board = _emptyBoard();
      // Row 0's only 4 empty cells (cols 0-3), all identically {1,2,3,4}
      // (row excludes 5-9), with every other cell in the row filled — so
      // row 0 has nothing left to eliminate into, and the rest of the
      // board is entirely empty (no other unit has enough constrained
      // cells to form a quad pool of its own).
      board[0] = [0, 0, 0, 0, 5, 6, 7, 8, 9];
      expect(engine.findNakedQuad(board), isNull);
    });
  });

  group('findHiddenPair', () {
    test('eliminates extra candidates from the two confined cells', () {
      final board = _emptyBoard();
      // Row 0 has 4 empty cells (cols 0-3), all starting from base
      // candidates {1,2,3,4}. Column placements confine digits 1 and 2
      // to exactly (0,0) and (0,1); (0,0) also keeps an extra candidate
      // 3 that the hidden pair should eliminate.
      board[0] = [0, 0, 0, 0, 5, 6, 7, 8, 9];
      board[5][0] = 4; // excludes 4 from (0,0)
      board[5][2] = 1; // excludes 1 from (0,2)
      board[6][1] = 3; // excludes 3 from (0,1)
      board[6][2] = 2; // excludes 2 from (0,2)
      board[7][1] = 4; // excludes 4 from (0,1)
      board[7][3] = 1; // excludes 1 from (0,3)
      board[8][3] = 2; // excludes 2 from (0,3)

      final hint = engine.findHiddenPair(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.hiddenPair);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {const HintCell(0, 0), const HintCell(0, 1)});
      expect(hint.eliminations, hasLength(1));
      expect(_hasElimination(hint, 0, 0, 3), isTrue);
      expect(hint.highlightedRows, {0});
      expect(hint.primaryDigits, {1, 2});
    });

    test('returns null when no digit pair is confined to two cells', () {
      expect(engine.findHiddenPair(_emptyBoard()), isNull);
    });
  });

  group('findHiddenTriple', () {
    test(
        'eliminates extra candidates from the three confined cells, even '
        'though each digit only occupies two of the three cells', () {
      final board = _emptyBoard();
      // Row 0 has 4 empty cells (cols 0-3), base candidates {1,2,3,4} from
      // row exclusion alone. Column givens shape a genuine "ring" triple:
      // digit 1 -> {(0,0),(0,1)}, digit 2 -> {(0,1),(0,2)},
      // digit 3 -> {(0,0),(0,2)} — no digit occupies all three cells, only
      // their union does — so this is only catchable via the general
      // union check, not a naive "same fixed 3 cells" one. (0,0) also
      // keeps an extra candidate 4 that the hidden triple should
      // eliminate; (0,3) is excluded from 1,2,3 entirely so it can't be
      // mistaken for a fourth cell in the group.
      board[0] = [0, 0, 0, 0, 5, 6, 7, 8, 9];
      board[3][0] = 2; // excludes 2 from (0,0)
      board[3][3] = 1; // excludes 1 from (0,3)
      board[4][1] = 3; // excludes 3 from (0,1)
      board[4][3] = 2; // excludes 2 from (0,3)
      board[5][1] = 4; // excludes 4 from (0,1)
      board[5][3] = 3; // excludes 3 from (0,3)
      board[6][2] = 1; // excludes 1 from (0,2)
      board[7][2] = 4; // excludes 4 from (0,2)

      final hint = engine.findHiddenTriple(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.hiddenTriple);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 1),
        const HintCell(0, 2),
      });
      expect(hint.eliminations, hasLength(1));
      expect(_hasElimination(hint, 0, 0, 4), isTrue);
      expect(hint.highlightedRows, {0});
      expect(hint.primaryDigits, {1, 2, 3});
    });

    test('returns null when no digit triple is confined to three cells', () {
      expect(engine.findHiddenTriple(_emptyBoard()), isNull);
    });
  });

  group('findHiddenQuad', () {
    test(
        'eliminates an extra candidate from the four confined cells, even '
        'though each digit only occupies three of the four cells', () {
      final board = _emptyBoard();
      // Row 0 has 5 empty cells (cols 0-4), base candidates {1,2,3,4,5}
      // from row exclusion alone. Column givens shape a genuine "ring"
      // quad: digit 1 -> {(0,0),(0,1),(0,2)}, digit 2 -> {(0,1),(0,2),(0,3)},
      // digit 3 -> {(0,0),(0,2),(0,3)}, digit 4 -> {(0,0),(0,1),(0,3)} —
      // no digit occupies all four cells, only their union does. (0,3)
      // also keeps an extra candidate 5 that the hidden quad should
      // eliminate; (0,4) is excluded from 1-4 entirely so it can't be
      // mistaken for a fifth cell in the group.
      board[0] = [0, 0, 0, 0, 0, 6, 7, 8, 9];
      board[3] = [2, 3, 4, 1, 0, 0, 0, 0, 0]; // col0 excl 2, col1 excl 3,
      // col2 excl 4, col3 excl 1
      board[4] = [5, 0, 0, 0, 1, 0, 0, 0, 0]; // col0 excl 5, col4 excl 1
      board[5] = [0, 5, 0, 0, 2, 0, 0, 0, 0]; // col1 excl 5, col4 excl 2
      board[6] = [0, 0, 5, 0, 3, 0, 0, 0, 0]; // col2 excl 5, col4 excl 3
      board[7] = [0, 0, 0, 0, 4, 0, 0, 0, 0]; // col4 excl 4

      final hint = engine.findHiddenQuad(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.hiddenQuad);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 1),
        const HintCell(0, 2),
        const HintCell(0, 3),
      });
      expect(hint.eliminations, hasLength(1));
      expect(_hasElimination(hint, 0, 3, 5), isTrue);
      expect(hint.highlightedRows, {0});
      expect(hint.primaryDigits, {1, 2, 3, 4});
    });

    test('returns null when no digit quad is confined to four cells', () {
      expect(engine.findHiddenQuad(_emptyBoard()), isNull);
    });
  });

  group('findIntersectionPointing', () {
    test('a box-confined digit is eliminated from the rest of its row', () {
      final board = _emptyBoard();
      // Box (rows 0-2, cols 0-2) is filled everywhere except row 0, so
      // digit 5 (missing from the six placed digits) is only a candidate
      // in that box within row 0 — a pointing pair/triple.
      board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
      board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];

      final hint = engine.findIntersectionPointing(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.intersectionPointing);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 1),
        const HintCell(0, 2),
      });
      for (var c = 3; c < 9; c++) {
        expect(_hasElimination(hint, 0, c, 5), isTrue, reason: 'col $c');
      }
      expect(hint.highlightedRows, {0});
      expect(hint.highlightedBoxes, {0});
    });

    test('returns null on an empty board', () {
      expect(engine.findIntersectionPointing(_emptyBoard()), isNull);
    });
  });

  group('findIntersectionClaiming', () {
    test('a row-confined digit is eliminated from the rest of its box', () {
      final board = _emptyBoard();
      // Row 0 is filled everywhere except cols 0-2 (all in one box), so
      // digit 1 (a candidate at all three empty cells) is confined to
      // that box within row 0.
      board[0] = [0, 0, 0, 4, 5, 6, 7, 8, 9];

      final hint = engine.findIntersectionClaiming(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.intersectionClaiming);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 1),
        const HintCell(0, 2),
      });
      for (final rc in [
        [1, 0], [1, 1], [1, 2],
        [2, 0], [2, 1], [2, 2],
      ]) {
        expect(_hasElimination(hint, rc[0], rc[1], 1), isTrue,
            reason: 'cell $rc');
      }
      expect(hint.highlightedRows, {0});
      expect(hint.highlightedBoxes, {0});
    });

    test('returns null on an empty board', () {
      expect(engine.findIntersectionClaiming(_emptyBoard()), isNull);
    });
  });

  group('candidates parameter (elimination persistence across calls)', () {
    // Same fixture as findIntersectionPointing's case above: box
    // (rows 0-2, cols 0-2) has digits 1,2,3,4,6,7 placed, leaving {5,8,9}
    // as candidates at (0,0),(0,1),(0,2), each confined to row 0 within
    // the box.
    test(
        'without a supplied candidates grid, the same elimination repeats '
        'every call', () {
      final board = _emptyBoard();
      board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
      board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];

      final first = engine.findIntersectionPointing(board);
      final second = engine.findIntersectionPointing(board);

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(_hasElimination(first!, 0, 3, 5), isTrue);
      expect(_hasElimination(second!, 0, 3, 5), isTrue);
    });

    test(
        'a supplied, narrowed candidates grid advances past an '
        'already-applied elimination instead of repeating it', () {
      final board = _emptyBoard();
      board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
      board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];

      final firstHint = engine.findIntersectionPointing(board)!;
      expect(_hasElimination(firstHint, 0, 3, 5), isTrue);

      // Mimic GameController._applyEliminateHint's narrowing of its
      // persistent engine-candidate cache.
      final grid = SudokuGrid(board);
      final narrowed = List.generate(
          9, (r) => List.generate(9, (c) => grid.candidatesAt(r, c)));
      for (final e in firstHint.eliminations) {
        narrowed[e.row][e.col].remove(e.digit);
      }

      final secondHint = engine.findIntersectionPointing(board, narrowed)!;

      // Digit 5 is fully eliminated from row 0 outside the box now, so the
      // next pointing pattern found is digit 8 (still confined to the
      // box's row 0), not a repeat of digit 5.
      expect(_hasElimination(secondHint, 0, 3, 5), isFalse);
      expect(_hasElimination(secondHint, 0, 3, 8), isTrue);
      expect(secondHint.primaryCells, firstHint.primaryCells);
    });

    test(
        'an empty candidates grid (no notes filled in yet) finds nothing, '
        'even though a fresh recompute would', () {
      final board = _emptyBoard();
      board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
      board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];
      final emptyNotes =
          List.generate(9, (_) => List.generate(9, (_) => <int>{}));

      expect(engine.findIntersectionPointing(board, emptyNotes), isNull);
      expect(engine.findIntersectionPointing(board), isNotNull);
    });
  });

  group('findXWing', () {
    test('row-based: eliminates a digit confined to the same two columns '
        'in two rows', () {
      final board = _emptyBoard();
      // Rows 0 and 3 are identically filled except cols 2 and 6, so digit
      // 7 (missing from the placed digits) is confined to columns {2, 6}
      // in both rows.
      board[0] = [1, 2, 0, 3, 4, 5, 0, 6, 8];
      board[3] = [1, 2, 0, 3, 4, 5, 0, 6, 8];

      final hint = engine.findXWing(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.xWing);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 2),
        const HintCell(0, 6),
        const HintCell(3, 2),
        const HintCell(3, 6),
      });
      expect(_hasElimination(hint, 1, 2, 7), isTrue);
      expect(_hasElimination(hint, 1, 6, 7), isTrue);
      expect(_hasElimination(hint, 6, 2, 7), isTrue);
      expect(_hasElimination(hint, 6, 6, 7), isTrue);
      expect(hint.highlightedRows, {0, 3});
      expect(hint.highlightedCols, {2, 6});
    });

    test('column-based: eliminates a digit confined to the same two rows '
        'in two columns', () {
      final board = _emptyBoard();
      // Columns 0 and 3 are identically filled except rows 2 and 6 (the
      // transposed mirror of the row-based fixture above).
      for (var r = 0; r < 9; r++) {
        final digit = [1, 2, 0, 3, 4, 5, 0, 6, 8][r];
        if (digit == 0) continue;
        board[r][0] = digit;
        board[r][3] = digit;
      }

      final hint = engine.findXWing(board);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.xWing);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(2, 0),
        const HintCell(6, 0),
        const HintCell(2, 3),
        const HintCell(6, 3),
      });
      // Missing digits from the filled {1,2,3,4,5,6,8} are {7, 9}; digit 7
      // is checked first and confines to rows {2, 6} the same way 9 would.
      expect(_hasElimination(hint, 2, 1, 7), isTrue);
      expect(_hasElimination(hint, 6, 1, 7), isTrue);
      expect(hint.highlightedRows, {2, 6});
      expect(hint.highlightedCols, {0, 3});
    });

    test('returns null on an empty board', () {
      expect(engine.findXWing(_emptyBoard()), isNull);
    });
  });

  group('findSimpleColoring', () {
    // These fixtures build the candidates grid by hand rather than from a
    // real board (same trick as the "candidates parameter" group above) —
    // the technique only cares about which cells carry a digit as a
    // candidate, not about overall board validity, and hand-building keeps
    // every other cell's candidate set empty so no other technique could
    // possibly interfere.
    test('Rule 1 (contradiction): two same-colored chain cells that see '
        'each other wipe out that whole color', () {
      // Row 0 conjugate pair for 9: (0,0)-(0,2) -> colors 0/1.
      // Column 2 conjugate pair for 9: (0,2)-(2,2) -> colors 1/0.
      // (0,0) and (2,2) are both color 0 and share box (0,0), so that
      // color is self-contradictory.
      final candidates = candidatesFrom({
        [0, 0]: {9},
        [0, 2]: {9},
        [2, 2]: {9},
      });

      final hint = engine.findSimpleColoring(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.simpleColoring);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {const HintCell(0, 0), const HintCell(2, 2)});
      expect(hint.secondaryCells, {const HintCell(0, 2)});
      expect(hint.colorGroupA, {const HintCell(0, 0), const HintCell(2, 2)});
      expect(hint.colorGroupB, {const HintCell(0, 2)});
      expect(_hasElimination(hint, 0, 0, 9), isTrue);
      expect(_hasElimination(hint, 2, 2, 9), isTrue);
    });

    test('Rule 2 (trap): a cell outside the chain that sees both colors '
        'loses the digit', () {
      // Row 0 conjugate pair for 9: (0,0)-(0,1) -> colors 0/1. (2,2) sees
      // both through box (0,0) but isn't itself part of any conjugate
      // pair (the box has 3 candidate cells for 9, not 2).
      final candidates = candidatesFrom({
        [0, 0]: {9},
        [0, 1]: {9},
        [2, 2]: {9},
      });

      final hint = engine.findSimpleColoring(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.simpleColoring);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {const HintCell(0, 0), const HintCell(0, 1)});
      expect(hint.colorGroupA, {const HintCell(0, 0)});
      expect(hint.colorGroupB, {const HintCell(0, 1)});
      expect(_hasElimination(hint, 2, 2, 9), isTrue);
    });

    test('returns null when no conjugate-pair chain of length >= 2 exists',
        () {
      expect(engine.findSimpleColoring(_emptyBoard()), isNull);
    });
  });

  group('findXYWing', () {
    test('eliminates the shared candidate from a cell that sees both '
        'wings', () {
      // Pivot (0,0){1,2}; decoy peer (0,1){1,2} has the exact same
      // candidates as the pivot (not a real wing), scanned before the real
      // wing and correctly skipped. W1 (0,4){1,3} shares 1 with the pivot,
      // so z=3. W2 (4,0){2,3} shares 2 with the pivot and also has z=3;
      // W1/W2 are not peers of each other. Target (4,4) sees W1 via column
      // 4 and W2 via row 4, so it loses 3. Near-miss (0,8) sees only W1
      // (same row), so it keeps its 3.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 1]: {1, 2},
        [0, 4]: {1, 3},
        [4, 0]: {2, 3},
        [4, 4]: {3, 9},
        [0, 8]: {3},
      });

      final hint = engine.findXYWing(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.xyWing);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 4),
        const HintCell(4, 0),
      });
      expect(_hasElimination(hint, 4, 4, 3), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.primaryDigits, {1, 2});
    });

    test('returns null when the pattern matches structurally but no cell '
        'sees both wings with the shared candidate', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 4]: {1, 3},
        [4, 0]: {2, 3},
      });
      expect(engine.findXYWing(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findXYWing(_emptyBoard()), isNull);
    });
  });

  group('findSwordfish', () {
    test('eliminates the digit from a cell in a cover column outside the '
        'three base rows', () {
      // Rows 0/3/6 confine digit 7 to columns {1,4}/{4,7}/{1,7} — combined
      // union is exactly 3 columns {1,4,7}, forming a genuine Swordfish.
      // (1,4) sits in a cover column outside the base rows, so it loses 7.
      // (1,2) is a near-miss: column 2 is not a cover column, so it's
      // never even examined.
      final candidates = candidatesFrom({
        [0, 1]: {7},
        [0, 4]: {7},
        [3, 4]: {7},
        [3, 7]: {7},
        [6, 1]: {7},
        [6, 7]: {7},
        [1, 4]: {7},
        [1, 2]: {7},
      });

      final hint = engine.findSwordfish(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.swordfish);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 1),
        const HintCell(0, 4),
        const HintCell(3, 4),
        const HintCell(3, 7),
        const HintCell(6, 1),
        const HintCell(6, 7),
      });
      expect(_hasElimination(hint, 1, 4, 7), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.highlightedRows, {0, 3, 6});
      expect(hint.highlightedCols, {1, 4, 7});
    });

    test('returns null when three rows only ever cover two columns (a '
        'disguised X-Wing, not a true Swordfish)', () {
      final candidates = candidatesFrom({
        [0, 1]: {7},
        [0, 4]: {7},
        [3, 1]: {7},
        [3, 4]: {7},
        [6, 1]: {7},
        [6, 4]: {7},
      });
      expect(engine.findSwordfish(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findSwordfish(_emptyBoard()), isNull);
    });
  });

  group('findJellyfish', () {
    test('eliminates the digit from a cell in a cover column outside the '
        'four base rows', () {
      // Rows 0/2/4/6 confine digit 6 to columns {1,4}/{4,7}/{1,8}/{7,8} —
      // combined union is exactly 4 columns {1,4,7,8}, forming a genuine
      // Jellyfish. (1,4) sits in a cover column outside the base rows, so
      // it loses 6. (1,2) is a near-miss: column 2 is not a cover column,
      // so it's never even examined.
      final candidates = candidatesFrom({
        [0, 1]: {6},
        [0, 4]: {6},
        [2, 4]: {6},
        [2, 7]: {6},
        [4, 1]: {6},
        [4, 8]: {6},
        [6, 7]: {6},
        [6, 8]: {6},
        [1, 4]: {6},
        [1, 2]: {6},
      });

      final hint = engine.findJellyfish(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.jellyfish);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 1),
        const HintCell(0, 4),
        const HintCell(2, 4),
        const HintCell(2, 7),
        const HintCell(4, 1),
        const HintCell(4, 8),
        const HintCell(6, 7),
        const HintCell(6, 8),
      });
      expect(_hasElimination(hint, 1, 4, 6), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.highlightedRows, {0, 2, 4, 6});
      expect(hint.highlightedCols, {1, 4, 7, 8});
    });

    test('returns null when four rows only ever cover two columns (a '
        'disguised X-Wing, not a true Jellyfish)', () {
      final candidates = candidatesFrom({
        [0, 1]: {6},
        [0, 4]: {6},
        [2, 1]: {6},
        [2, 4]: {6},
        [4, 1]: {6},
        [4, 4]: {6},
        [6, 1]: {6},
        [6, 4]: {6},
      });
      expect(engine.findJellyfish(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findJellyfish(_emptyBoard()), isNull);
    });
  });

  group('findFinnedXWing', () {
    test('eliminates the digit from a cell that sees every fin and sits '
        'in a cover column outside the base rows', () {
      // Row 0 is the clean row (cover columns {2,6}). Row 3 has both cover
      // columns PLUS a fin at column 8, all within box rows 3-5 x cols
      // 6-8. (4,6) sits in a cover column, outside the base rows, and
      // shares that box with the fin, so it loses 5. (7,6) is a near-miss
      // that doesn't see the fin; (4,7) is a near-miss whose column isn't
      // a cover column.
      final candidates = candidatesFrom({
        [0, 2]: {5},
        [0, 6]: {5},
        [3, 2]: {5},
        [3, 6]: {5},
        [3, 8]: {5},
        [4, 6]: {5},
        [7, 6]: {5},
        [4, 7]: {5},
      });

      final hint = engine.findFinnedXWing(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.finnedXWing);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 2),
        const HintCell(0, 6),
        const HintCell(3, 2),
        const HintCell(3, 6),
        const HintCell(3, 8),
      });
      expect(_hasElimination(hint, 4, 6, 5), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.highlightedRows, {0, 3});
      expect(hint.highlightedCols, {2, 6});
    });

    test('returns null on an empty board', () {
      expect(engine.findFinnedXWing(_emptyBoard()), isNull);
    });
  });

  group('findSashimiXWing', () {
    test('eliminates the digit even though the fin row is missing one of '
        'the two cover columns entirely', () {
      // Same shape as the Finned X-Wing fixture, but row 3 is missing
      // cover column 6 outright — it only has column 2 (one corner) plus
      // the fin at column 8. The elimination logic and target are
      // identical: (4,6) sees the fin and sits in a cover column outside
      // the base rows.
      final candidates = candidatesFrom({
        [0, 2]: {5},
        [0, 6]: {5},
        [3, 2]: {5},
        [3, 8]: {5},
        [4, 6]: {5},
        [7, 6]: {5},
        [4, 7]: {5},
      });

      final hint = engine.findSashimiXWing(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.sashimiXWing);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 2),
        const HintCell(0, 6),
        const HintCell(3, 2),
        const HintCell(3, 8),
      });
      expect(_hasElimination(hint, 4, 6, 5), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.highlightedRows, {0, 3});
      expect(hint.highlightedCols, {2, 6});
    });

    test('returns null on an empty board', () {
      expect(engine.findSashimiXWing(_emptyBoard()), isNull);
    });
  });

  group('findXYChain', () {
    // Unlike every other technique's fixtures, every "background" cell
    // here (elimination target, near-miss) is deliberately given 3+
    // candidates rather than 2 — a stray bivalue cell would itself be a
    // node the chain search could wander into, potentially hijacking
    // which chain is found first. Padding to 3+ candidates makes them
    // provably invisible to the chain search while still visible to the
    // elimination scan (which only checks for the target digit).
    test('eliminates the shared digit from a cell that sees both ends of '
        'a 4-cell chain', () {
      // Chain: (0,0){1,9} -[1]-> (0,4){1,2} -[2]-> (4,4){2,3} -[3]->
      // (4,8){3,9}. If (0,0) isn't 9, it's 1, forcing (0,4) to 2, forcing
      // (4,4) to 3, forcing (4,8) to 9 — so either end is 9. (4,0) sees
      // both ends (column 0 / row 4) and loses its 9. (8,0) sees only the
      // start (column 0), not the end, and keeps its 9.
      final candidates = candidatesFrom({
        [0, 0]: {1, 9},
        [0, 4]: {1, 2},
        [4, 4]: {2, 3},
        [4, 8]: {3, 9},
        [4, 0]: {9, 5, 6},
        [8, 0]: {9, 5, 6},
      });

      final hint = engine.findXYChain(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.xyChain);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 4),
        const HintCell(4, 4),
        const HintCell(4, 8),
      });
      expect(hint.colorGroupA, {const HintCell(0, 0), const HintCell(4, 4)});
      expect(hint.colorGroupB, {const HintCell(0, 4), const HintCell(4, 8)});
      expect(_hasElimination(hint, 4, 0, 9), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.primaryDigits, {1, 2, 3, 9});
    });

    test('returns null for a 3-cell chain (that shape is exactly an '
        'XY-Wing, already handled by findXYWing)', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 4]: {1, 3},
        [4, 0]: {2, 3},
      });
      expect(engine.findXYChain(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findXYChain(_emptyBoard()), isNull);
    });
  });

  group('findUniqueRectangleType1', () {
    test('eliminates the deadly pair from the one cell with extra '
        'candidates', () {
      // Rows 0-1, columns 0/3 (box-row band shared, box-col bands
      // differ) -> a valid 2-box UR base. Three corners are pure {1,2};
      // (1,3) also has an extra candidate 3, so it can't join the
      // deadly pair without creating a second solution.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [1, 0]: {1, 2},
        [0, 3]: {1, 2},
        [1, 3]: {1, 2, 3},
      });

      final hint = engine.findUniqueRectangleType1(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.uniqueRectangleType1);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(1, 0),
        const HintCell(0, 3),
        const HintCell(1, 3),
      });
      expect(_hasElimination(hint, 1, 3, 1), isTrue);
      expect(_hasElimination(hint, 1, 3, 2), isTrue);
      expect(hint.eliminations, hasLength(2));
      expect(hint.highlightedBoxes, {0, 1});
    });

    test('returns null when all four corners are pure (not a resolvable '
        'Type 1 shape)', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [1, 0]: {1, 2},
        [0, 3]: {1, 2},
        [1, 3]: {1, 2},
      });
      expect(engine.findUniqueRectangleType1(_emptyBoard(), candidates),
          isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findUniqueRectangleType1(_emptyBoard()), isNull);
    });
  });

  group('findUniqueRectangleType2', () {
    test('eliminates the shared extra digit from a cell that sees both '
        'roof cells', () {
      // Floor (0,0)/(1,0) pure {1,2}; roof (0,3)/(1,3) both {1,2,3} (same
      // extra digit 3). (2,3) sees both roof cells via column 3, so it
      // loses 3. (0,7) sees only (0,3) (same row, but a different box
      // than (1,3)), so it keeps its 3.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [1, 0]: {1, 2},
        [0, 3]: {1, 2, 3},
        [1, 3]: {1, 2, 3},
        [2, 3]: {3, 4},
        [0, 7]: {3, 5},
      });

      final hint = engine.findUniqueRectangleType2(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.uniqueRectangleType2);
      expect(hint.type, HintType.eliminate);
      expect(_hasElimination(hint, 2, 3, 3), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.highlightedBoxes, {0, 1});
    });

    test('returns null on an empty board', () {
      expect(engine.findUniqueRectangleType2(_emptyBoard()), isNull);
    });
  });

  group('findUniqueRectangleType3', () {
    test('combines the roof cells\' extra candidates with an external '
        'cell into a naked pair, eliminating within their shared box', () {
      // Floor (0,0)/(1,0) pure {1,2}; roof (0,3)={1,2,3}, (1,3)={1,2,4}
      // -> virtual extra digits {3,4}. External (2,5)={3,4} (same box as
      // the roof, not column 3) completes an exact naked pair with the
      // virtual cell, so (2,4) (same box, candidates {3,5}) loses 3.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [1, 0]: {1, 2},
        [0, 3]: {1, 2, 3},
        [1, 3]: {1, 2, 4},
        [2, 5]: {3, 4},
        [2, 4]: {3, 5},
      });

      final hint = engine.findUniqueRectangleType3(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.uniqueRectangleType3);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 3),
        const HintCell(1, 3),
        const HintCell(2, 5),
      });
      expect(_hasElimination(hint, 2, 4, 3), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.highlightedBoxes, {0, 1});
      expect(hint.highlightedRows, isEmpty);
      expect(hint.highlightedCols, isEmpty);
    });

    test('returns null on an empty board', () {
      expect(engine.findUniqueRectangleType3(_emptyBoard()), isNull);
    });
  });

  group('findUniqueRectangleType4', () {
    test('eliminates the non-conjugate digit from both roof cells', () {
      // Floor (0,0)/(1,0) pure {1,2}; roof (0,3)={1,2,4}, (1,3)={1,2,5}
      // (different extras, not a Type 2 shape). Column 3 has no other
      // candidate-1 cell, so 1 is conjugate to the roof pair -> 2 is
      // eliminated from both roof cells.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [1, 0]: {1, 2},
        [0, 3]: {1, 2, 4},
        [1, 3]: {1, 2, 5},
      });

      final hint = engine.findUniqueRectangleType4(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.uniqueRectangleType4);
      expect(hint.type, HintType.eliminate);
      expect(_hasElimination(hint, 0, 3, 2), isTrue);
      expect(_hasElimination(hint, 1, 3, 2), isTrue);
      expect(hint.eliminations, hasLength(2));
      expect(hint.highlightedBoxes, {0, 1});
      expect(hint.highlightedCols, {3});
    });

    test('returns null when a third column cell breaks conjugacy for '
        'both deadly-pair digits', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [1, 0]: {1, 2},
        [0, 3]: {1, 2, 4},
        [1, 3]: {1, 2, 5},
        [4, 3]: {1, 2, 7},
      });
      expect(engine.findUniqueRectangleType4(_emptyBoard(), candidates),
          isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findUniqueRectangleType4(_emptyBoard()), isNull);
    });
  });

  group('findHint priority ordering', () {
    test('prefers Full House even when the same cell also qualifies as a '
        'naked/hidden single', () {
      final board = _solvedGrid();
      board[0][0] = 0;
      expect(engine.findHint(board)!.technique, HintTechnique.fullHouse);
    });

    test('falls through to Hidden Single when no Full House applies', () {
      // This board has a naked single at (0,0) (candidates {1}), but row 0
      // also happens to confine digit 9 to (0,8) alone — a hidden single —
      // and Hidden Single is now tried before Naked Single, so that's what
      // findHint should surface.
      final board = _emptyBoard();
      board[0] = [0, 2, 3, 4, 5, 6, 7, 8, 0];
      board[1][0] = 9;
      final hint = engine.findHint(board)!;
      expect(hint.technique, HintTechnique.hiddenSingle);
      expect(hint.row, 0);
      expect(hint.col, 8);
      expect(hint.value, 9);
    });

    test('falls through to Naked Single when no Full House or Hidden '
        'Single applies', () {
      // Row 0 has 3 empty cells so neither (0,0) nor any digit within the
      // row gets confined to a single cell by row-sharing alone; only
      // (0,0) itself narrows to one candidate via its column exclusions.
      final board = _emptyBoard();
      board[0] = [0, 0, 0, 4, 5, 6, 7, 8, 9];
      board[5][0] = 2;
      board[6][0] = 3;
      final hint = engine.findHint(board)!;
      expect(hint.technique, HintTechnique.nakedSingle);
      expect(hint.row, 0);
      expect(hint.col, 0);
      expect(hint.value, 1);
    });

    test(
        'reveal-type techniques ignore the supplied candidates grid — an '
        'empty notes grid still finds the same naked single as the fresh '
        'board computation', () {
      final board = _emptyBoard();
      board[0] = [0, 0, 0, 4, 5, 6, 7, 8, 9];
      board[5][0] = 2;
      board[6][0] = 3;
      final emptyNotes =
          List.generate(9, (_) => List.generate(9, (_) => <int>{}));

      final hint = engine.findHint(board, emptyNotes)!;
      expect(hint.technique, HintTechnique.nakedSingle);
      expect(hint.row, 0);
      expect(hint.col, 0);
      expect(hint.value, 1);
    });

    test('hintTechniqueOrder matches the documented progression', () {
      expect(hintTechniqueOrder, [
        HintTechnique.fullHouse,
        HintTechnique.hiddenSingle,
        HintTechnique.nakedSingle,
        HintTechnique.intersectionPointing,
        HintTechnique.intersectionClaiming,
        HintTechnique.xWing,
        HintTechnique.nakedPair,
        HintTechnique.nakedTriple,
        HintTechnique.hiddenPair,
        HintTechnique.hiddenTriple,
        HintTechnique.nakedQuad,
        HintTechnique.hiddenQuad,
        HintTechnique.simpleColoring,
        HintTechnique.xyWing,
        HintTechnique.swordfish,
        HintTechnique.finnedXWing,
        HintTechnique.sashimiXWing,
        HintTechnique.xyChain,
        HintTechnique.jellyfish,
        HintTechnique.uniqueRectangleType1,
        HintTechnique.uniqueRectangleType2,
        HintTechnique.uniqueRectangleType3,
        HintTechnique.uniqueRectangleType4,
      ]);
    });

    test('returns null on a fully solved board', () {
      expect(engine.findHint(_solvedGrid()), isNull);
    });
  });
}
