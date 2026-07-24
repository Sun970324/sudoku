import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/models/sudoku_grid.dart';
import 'package:sudoku/services/generation/board_generator.dart';
import 'package:sudoku/services/generation/clue_remover.dart';
import 'package:sudoku/services/generation/minimalizer.dart';
import 'package:sudoku/services/hint_engine.dart';
import 'package:sudoku/services/sudoku_solver.dart';

List<List<int>> _emptyBoard() => List.generate(9, (_) => List.filled(9, 0));

/// A deterministic, fully solved grid (SudokuSolver has no randomness).
List<List<int>> _solvedGrid() =>
    SudokuSolver().solve(_emptyBoard())!.map((row) => List<int>.from(row)).toList();

bool _hasElimination(Hint hint, int row, int col, int digit) => hint
    .eliminations
    .any((e) => e.row == row && e.col == col && e.digit == digit);

bool _cellsSee(HintCell a, HintCell b) =>
    (a.row != b.row || a.col != b.col) &&
    (a.row == b.row ||
        a.col == b.col ||
        (a.row ~/ 3 == b.row ~/ 3 && a.col ~/ 3 == b.col ~/ 3));

/// Asserts a chain technique's [chainLinks] is the shape the hint-arrow
/// overlay relies on: the links are contiguous and alternate strong/weak,
/// their nodes cover exactly [primaryCells], each link either joins peers or
/// stays within one cell (an XY-Chain's own bivalue link does the latter),
/// and both ends claim the same digit and are seen by [elimination] — which
/// is what makes the "sees both ends" conclusion sound.
void _expectWellFormedChain(
  List<HintChainLink> chainLinks,
  Set<HintCell> primaryCells,
  HintCell elimination,
) {
  expect(chainLinks, isNotEmpty);

  for (var i = 0; i + 1 < chainLinks.length; i++) {
    expect(chainLinks[i].to, chainLinks[i + 1].from,
        reason: 'link $i must end where link ${i + 1} begins');
    expect(chainLinks[i].strong, isNot(chainLinks[i + 1].strong),
        reason: 'links $i and ${i + 1} must alternate strong/weak');
  }

  for (final link in chainLinks) {
    for (final a in link.from.cells) {
      for (final b in link.to.cells) {
        expect(a == b || _cellsSee(a, b), isTrue,
            reason: 'a link joins peers or stays within a single cell');
      }
    }
  }

  expect({
    for (final link in chainLinks) ...[...link.from.cells, ...link.to.cells],
  }, primaryCells);

  final start = chainLinks.first.from;
  final end = chainLinks.last.to;
  expect(start.digit, end.digit,
      reason: 'both ends must claim the same digit — the one eliminated '
          'wherever both are seen');
  for (final cell in [...start.cells, ...end.cells]) {
    expect(_cellsSee(cell, elimination), isTrue);
  }
}

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
      // Two solid rails along the base rows; all four corners offered as
      // convergence sources for the column eliminations.
      expect(hint.chainLinks, hasLength(2));
      expect(hint.chainLinks.every((l) => l.strong), isTrue);
      expect(
        hint.chainLinks
            .expand((l) => [...l.from.cells, ...l.to.cells])
            .toSet(),
        hint.primaryCells,
      );
      expect(hint.elimSources, hasLength(4));
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

  group('findSkyscraper', () {
    test('eliminates the digit from a cell seeing both free ends of two '
        'row strong links sharing one column', () {
      // Rows 0 and 8 each have 4 exactly twice; they share column 0, so
      // (0,0)~(8,0) is the connecting weak link. The free ends (0,3) and
      // (8,5) mean at least one must be 4, so (1,5) — which sees (0,3) via
      // box 1 and (8,5) via column 5 — loses 4.
      final candidates = candidatesFrom({
        [0, 0]: {4},
        [0, 3]: {4},
        [8, 0]: {4},
        [8, 5]: {4},
        [1, 5]: {4, 7},
      });

      final hint = engine.findSkyscraper(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.skyscraper);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 3),
        const HintCell(8, 0),
        const HintCell(8, 5),
      });
      expect(_hasElimination(hint, 1, 5, 4), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.primaryDigits, {4});
      _expectWellFormedChain(
          hint.chainLinks, hint.primaryCells, const HintCell(1, 5));
    });

    test('returns null for an X-Wing where both strong links share both '
        'columns (the free ends align)', () {
      // Both rows have 4 in exactly columns 0 and 3, so the free ends are in
      // the same column — this is an X-Wing, not a Skyscraper, and must not
      // be reported as one (it would wrongly eliminate 4 at (4,0)).
      final candidates = candidatesFrom({
        [0, 0]: {4},
        [0, 3]: {4},
        [8, 0]: {4},
        [8, 3]: {4},
        [4, 0]: {4, 7},
      });
      expect(engine.findSkyscraper(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findSkyscraper(_emptyBoard()), isNull);
    });
  });

  group('findTwoStringKite', () {
    test('eliminates the digit from the cell seeing both free ends of a row '
        'and column strong link joined in a box', () {
      // Row 0 has 4 at (0,0) and (0,5); column 1 has 4 at (2,1) and (7,1).
      // The near ends (0,0) and (2,1) share box 0 (the weak link). The free
      // ends (0,5) and (7,1) force at least one to be 4, so (7,5) — seeing
      // (0,5) via column 5 and (7,1) via row 7 — loses 4.
      final candidates = candidatesFrom({
        [0, 0]: {4},
        [0, 5]: {4},
        [2, 1]: {4},
        [7, 1]: {4},
        [7, 5]: {4, 7},
      });

      final hint = engine.findTwoStringKite(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.twoStringKite);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 5),
        const HintCell(2, 1),
        const HintCell(7, 1),
      });
      expect(_hasElimination(hint, 7, 5, 4), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.primaryDigits, {4});
      _expectWellFormedChain(
          hint.chainLinks, hint.primaryCells, const HintCell(7, 5));
    });

    test('returns null on an empty board', () {
      expect(engine.findTwoStringKite(_emptyBoard()), isNull);
    });
  });

  group('findTurbotFish', () {
    test('eliminates the digit using one box strong link and one line '
        'strong link joined by a weak link', () {
      // Box 0 has 4 at (0,2) and (1,0); row 5 has 4 at (5,2) and (5,7). The
      // near ends (0,2) and (5,2) share column 2 (the weak link). The free
      // ends (1,0) and (5,7) force at least one to be 4, so (1,7) — seeing
      // (1,0) via row 1 and (5,7) via column 7 — loses 4.
      final candidates = candidatesFrom({
        [1, 0]: {4},
        [0, 2]: {4},
        [5, 2]: {4},
        [5, 7]: {4},
        [1, 7]: {4, 7},
      });

      final hint = engine.findTurbotFish(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.turbotFish);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 2),
        const HintCell(1, 0),
        const HintCell(5, 2),
        const HintCell(5, 7),
      });
      expect(_hasElimination(hint, 1, 7, 4), isTrue);
      expect(hint.eliminations, hasLength(1));
      expect(hint.primaryDigits, {4});
      _expectWellFormedChain(
          hint.chainLinks, hint.primaryCells, const HintCell(1, 7));
    });

    test('returns null on an empty board', () {
      expect(engine.findTurbotFish(_emptyBoard()), isNull);
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
      // The two conjugate edges drawn solid, plus one dashed link between
      // the clashing same-colored pair — and no convergence connectors,
      // since the eliminations land on the chain's own cells.
      expect(hint.chainLinks, hasLength(3));
      expect(hint.chainLinks.where((l) => l.strong), hasLength(2));
      expect(hint.chainLinks.where((l) => !l.strong), hasLength(1));
      expect(hint.elimSources, isEmpty);
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
      // The single conjugate edge drawn solid; every chain cell offered as
      // a convergence source (the overlay narrows to nearest-per-color).
      expect(hint.chainLinks, hasLength(1));
      expect(hint.chainLinks.single.strong, isTrue);
      expect(hint.elimSources, hasLength(2));
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
      // A 3-cell XY-Chain in link form: wing z = wing's shared digit ~
      // pivot ... ~ other wing ~ its z, both ends on z so the overlay's
      // convergence connectors meet at the eliminated candidate.
      _expectWellFormedChain(
          hint.chainLinks, hint.primaryCells, const HintCell(4, 4));
      expect(hint.chainLinks.first.from.digit, 3,
          reason: 'the chain must start and end on z');
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

  group('findLockedPair', () {
    test('sweeps both the line and the box, which is the whole point — a '
        'plain Naked Pair only ever clears one of them', () {
      // (0,0) and (0,1) are both {4,7}: same row 0, same box 0. So 4 and 7
      // must take those two cells, clearing out of the rest of row 0 AND the
      // rest of box 0.
      final candidates = candidatesFrom({
        [0, 0]: {4, 7},
        [0, 1]: {4, 7},
        [0, 5]: {4, 9}, // rest of the line
        [1, 1]: {7, 8}, // rest of the box
        [2, 2]: {4, 5}, // rest of the box
      });

      final hint = engine.findLockedPair(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.lockedPair);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {const HintCell(0, 0), const HintCell(0, 1)});
      expect(hint.primaryDigits, {4, 7});
      // Down the line...
      expect(_hasElimination(hint, 0, 5, 4), isTrue);
      // ...and inside the box, in the same step.
      expect(_hasElimination(hint, 1, 1, 7), isTrue);
      expect(_hasElimination(hint, 2, 2, 4), isTrue);
      expect(hint.eliminations, hasLength(3));
      expect(hint.highlightedRows, {0});
      expect(hint.highlightedBoxes, {0});
    });

    test('returns null for a pair that shares a line but not a box, since '
        'there is nothing locked about it', () {
      final candidates = candidatesFrom({
        [0, 0]: {4, 7},
        [0, 5]: {4, 7},
        [0, 8]: {4, 9},
      });

      expect(engine.findLockedPair(_emptyBoard(), candidates), isNull);
    });

    test('returns null when the pair is alone in its intersection with '
        'nothing to eliminate', () {
      final candidates = candidatesFrom({
        [0, 0]: {4, 7},
        [0, 1]: {4, 7},
      });

      expect(engine.findLockedPair(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findLockedPair(_emptyBoard()), isNull);
    });
  });

  group('findLockedTriple', () {
    test('sweeps both the line and the box for all three digits', () {
      // {1,2}/{2,3}/{1,3} across the row-0 x box-0 intersection spans exactly
      // {1,2,3} — the cells need not have identical candidate sets.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 1]: {2, 3},
        [0, 2]: {1, 3},
        [0, 7]: {1, 9}, // rest of the line
        [2, 1]: {3, 8}, // rest of the box
      });

      final hint = engine.findLockedTriple(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.lockedTriple);
      expect(hint.primaryDigits, {1, 2, 3});
      expect(_hasElimination(hint, 0, 7, 1), isTrue);
      expect(_hasElimination(hint, 2, 1, 3), isTrue);
      expect(hint.eliminations, hasLength(2));
    });

    test('returns null on an empty board', () {
      expect(engine.findLockedTriple(_emptyBoard()), isNull);
    });
  });

  group('findRemotePair', () {
    test('removes BOTH digits from a cell seeing the two ends of an '
        'odd-length chain', () {
      // Four {1,2} cells chained (0,0)-(0,4)-(5,4)-(5,7): each sees the next,
      // three links, so the ends hold opposite values. (0,7) sees (0,0) by
      // row and (5,7) by column, so it loses both 1 and 2.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 4]: {1, 2},
        [5, 4]: {1, 2},
        [5, 7]: {1, 2},
        [0, 7]: {1, 2, 9},
      });

      final hint = engine.findRemotePair(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.remotePair);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryDigits, {1, 2});
      // Both digits, not just one — that's what separates this from a
      // one-digit chain elimination.
      expect(_hasElimination(hint, 0, 7, 1), isTrue);
      expect(_hasElimination(hint, 0, 7, 2), isTrue);
      expect(hint.colorGroupA, isNotEmpty);
      expect(hint.colorGroupB, isNotEmpty);
      // Same link grammar as an XY-Chain: in-cell strong pairs joined by
      // weak shared-digit hops, both ends landing on the same digit.
      _expectWellFormedChain(
          hint.chainLinks, hint.primaryCells, const HintCell(0, 7));
    });

    test('returns null for cells whose pairs differ, since the alternation '
        'argument needs one shared pair throughout', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 4]: {1, 3},
        [5, 4]: {1, 2},
        [5, 7]: {1, 2},
        [0, 7]: {1, 2, 9},
      });

      expect(engine.findRemotePair(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findRemotePair(_emptyBoard()), isNull);
    });
  });

  group('findXYZWing', () {
    test('eliminates z only from cells that see the pivot as well as both '
        'wings, since a 3-candidate pivot can itself be z', () {
      // Pivot (0,0)={1,2,3}; wings (0,1)={1,3} and (1,0)={2,3}. z = 3.
      // (1,1) sees all three (shared box 0), so it loses 3.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2, 3},
        [0, 1]: {1, 3},
        [1, 0]: {2, 3},
        [1, 1]: {3, 8},
      });

      final hint = engine.findXYZWing(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.xyzWing);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells, {
        const HintCell(0, 0),
        const HintCell(0, 1),
        const HintCell(1, 0),
      });
      expect(hint.primaryDigits, {1, 2, 3});
      expect(_hasElimination(hint, 1, 1, 3), isTrue);
      expect(hint.eliminations, hasLength(1));
      // Two branches rather than one chain — no link joins the trivalue
      // pivot's own 1/2 (they're not a strong pair, the pivot could be 3):
      // wing1's 3=1 ~ pivot's 1, then pivot's 2 ~ wing2's 2=3.
      expect(hint.chainLinks, hasLength(4));
      expect(hint.chainLinks.map((l) => l.strong).toList(),
          [true, false, false, true]);
      // All three z sources — both wings AND the pivot itself — converge on
      // the eliminated cell; that's the "sees all three" requirement.
      expect(hint.elimSources, hasLength(3));
      for (final source in hint.elimSources!) {
        expect(source.digit, 3);
        for (final cell in source.cells) {
          expect(_cellsSee(cell, const HintCell(1, 1)), isTrue);
        }
      }
    });

    test('returns null when the pattern is present but nothing sees all '
        'three cells', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2, 3},
        [0, 1]: {1, 3},
        [1, 0]: {2, 3},
      });

      expect(engine.findXYZWing(_emptyBoard(), candidates), isNull);
    });

    test('returns null for a bivalue pivot, which is an XY-Wing rather than '
        'an XYZ-Wing', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 1]: {1, 3},
        [1, 0]: {2, 3},
        [1, 1]: {3, 8},
      });

      expect(engine.findXYZWing(_emptyBoard(), candidates), isNull);
      // ...and the XY-Wing search does claim it.
      expect(engine.findXYWing(_emptyBoard(), candidates), isNotNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findXYZWing(_emptyBoard()), isNull);
    });
  });

  group('findWWing', () {
    test('eliminates a from cells seeing both pair cells, via a strong link '
        'on b', () {
      // (0,0) and (4,4) both {1,2}, not peers. Column 8 has exactly two
      // places for 2: (0,8) sees (0,0) by row, (4,8) sees (4,4) by row.
      // So at least one of the pair is 1 -> any cell seeing both loses 1.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [4, 4]: {1, 2},
        [0, 8]: {2, 7},
        [4, 8]: {2, 7},
        [4, 0]: {1, 9}, // sees (0,0) by column, (4,4) by row
      });

      final hint = engine.findWWing(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.wWing);
      expect(hint.type, HintType.eliminate);
      expect(_hasElimination(hint, 4, 0, 1), isTrue);
      expect(hint.primaryCells, contains(const HintCell(0, 0)));
      expect(hint.primaryCells, contains(const HintCell(4, 4)));
      // The strong link's own cells belong to the pattern too.
      expect(hint.primaryCells, contains(const HintCell(0, 8)));
      expect(hint.primaryCells, contains(const HintCell(4, 8)));
    });

    test('returns null when the two pair cells see each other, which is a '
        'Naked Pair rather than a W-Wing', () {
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [0, 4]: {1, 2},
        [0, 8]: {2, 7},
        [4, 8]: {2, 7},
        [4, 0]: {1, 9},
      });

      expect(engine.findWWing(_emptyBoard(), candidates), isNull);
    });

    test('returns null without a strong link to join the pair', () {
      // Column 8 now has three places for 2, so it is not a strong link.
      final candidates = candidatesFrom({
        [0, 0]: {1, 2},
        [4, 4]: {1, 2},
        [0, 8]: {2, 7},
        [4, 8]: {2, 7},
        [7, 8]: {2, 7},
        [4, 0]: {1, 9},
      });

      expect(engine.findWWing(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findWWing(_emptyBoard()), isNull);
    });
  });

  group('findFinnedSwordfish', () {
    /// Rows 0/3/6 would be a Swordfish for digit 6 on cover columns {1,4,7},
    /// except row 6 also has a candidate at column 2 — the fin. Either the
    /// fin is false (making this a true Swordfish, which empties column 1
    /// outside the base rows) or (6,2) is 6 — and (7,1) sees (6,2) via their
    /// shared box, so it loses 6 under both branches.
    List<List<Set<int>>> finnedFixture() => candidatesFrom({
          [0, 1]: {6},
          [0, 4]: {6},
          [3, 4]: {6},
          [3, 7]: {6},
          [6, 1]: {6},
          [6, 7]: {6},
          [6, 2]: {6}, // the fin
          [7, 1]: {6}, // the target: sees the fin, sits in a cover column
        });

    test('eliminates from a cover-column cell that sees the fin', () {
      final hint = engine.findFinnedSwordfish(_emptyBoard(), finnedFixture());

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.finnedSwordfish);
      expect(hint.type, HintType.eliminate);
      expect(hint.highlightedRows, {0, 3, 6});
      expect(hint.highlightedCols, {1, 4, 7});
      expect(_hasElimination(hint, 7, 1, 6), isTrue);
      expect(hint.eliminations, hasLength(1));
      // The fin belongs to the pattern, so it's highlighted with the rest.
      expect(hint.primaryCells, contains(const HintCell(6, 2)));
    });

    test('the fixture is genuinely finned — a plain Swordfish does not see '
        'it, so the elimination is not just a Swordfish in disguise', () {
      expect(engine.findSwordfish(_emptyBoard(), finnedFixture()), isNull);
    });

    test('returns null for a clean Swordfish, which has no fin to reason '
        'about', () {
      final candidates = candidatesFrom({
        [0, 1]: {6},
        [0, 4]: {6},
        [3, 4]: {6},
        [3, 7]: {6},
        [6, 1]: {6},
        [6, 7]: {6},
        [7, 1]: {6},
      });

      expect(engine.findFinnedSwordfish(_emptyBoard(), candidates), isNull);
    });

    test('returns null when no cell sees every fin', () {
      // Same shape, but the target (7,5) shares neither box, row, nor column
      // with the fin at (6,2) — so the "fin is true" branch leaves it alone.
      final candidates = candidatesFrom({
        [0, 1]: {6},
        [0, 4]: {6},
        [3, 4]: {6},
        [3, 7]: {6},
        [6, 1]: {6},
        [6, 7]: {6},
        [6, 2]: {6},
        [7, 4]: {6},
      });

      expect(engine.findFinnedSwordfish(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findFinnedSwordfish(_emptyBoard()), isNull);
    });
  });

  group('findFinnedJellyfish', () {
    test('eliminates from a cover-column cell that sees the fin', () {
      // Rows 0/2/4/6 on cover columns {1,4,7,8} for digit 6, with a fin at
      // (6,6); (7,7) sees it through their shared box.
      final candidates = candidatesFrom({
        [0, 1]: {6},
        [0, 4]: {6},
        [2, 4]: {6},
        [2, 7]: {6},
        [4, 1]: {6},
        [4, 8]: {6},
        [6, 7]: {6},
        [6, 8]: {6},
        [6, 6]: {6}, // the fin
        [7, 7]: {6}, // the target
      });

      final hint = engine.findFinnedJellyfish(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.finnedJellyfish);
      expect(hint.type, HintType.eliminate);
      expect(hint.highlightedRows, {0, 2, 4, 6});
      expect(hint.highlightedCols, {1, 4, 7, 8});
      expect(_hasElimination(hint, 7, 7, 6), isTrue);
    });

    test('returns null on an empty board', () {
      expect(engine.findFinnedJellyfish(_emptyBoard()), isNull);
    });
  });

  group('findXChain', () {
    test('a four-node single-digit chain (two conjugate pairs joined by a '
        'weak link) eliminates the digit from a cell seeing both ends', () {
      // The same shape a Skyscraper has — an X-Chain generalizes it. Rows 0
      // and 8 are conjugate pairs on 4; (0,0)~(8,0) is the weak bridge; the
      // ends (0,3) and (8,5) mean (1,5), seeing both, loses 4.
      final candidates = candidatesFrom({
        [0, 0]: {4},
        [0, 3]: {4},
        [8, 0]: {4},
        [8, 5]: {4},
        [1, 5]: {4, 7},
      });

      final hint = engine.findXChain(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.xChain);
      expect(hint.type, HintType.eliminate);
      expect(hint.eliminations, isNotEmpty);
      // Single digit throughout.
      expect(hint.primaryDigits, {4});
      // Alternating strong/weak links, endpoints on the same digit — that
      // (not a fixed eliminated cell — this fixture admits several valid
      // chains) is what defines an X-Chain.
      expect(hint.chainLinks, isNotEmpty);
      for (var i = 0; i + 1 < hint.chainLinks.length; i++) {
        expect(hint.chainLinks[i].strong,
            isNot(hint.chainLinks[i + 1].strong));
      }
      expect(hint.chainLinks.first.from.digit,
          hint.chainLinks.last.to.digit);
      // Whichever chain it picked, every eliminated candidate must be 4.
      expect(hint.eliminations.every((e) => e.digit == 4), isTrue);
    });

    test('returns null on an empty board', () {
      expect(engine.findXChain(_emptyBoard()), isNull);
    });
  });

  group('findAic', () {
    test('the general chain also solves the single-digit case (X-Chain is a '
        'restriction of it)', () {
      final candidates = candidatesFrom({
        [0, 0]: {4},
        [0, 3]: {4},
        [8, 0]: {4},
        [8, 5]: {4},
        [1, 5]: {4, 7},
      });

      final hint = engine.findAic(_emptyBoard(), candidates);

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.aic);
      expect(hint.eliminations, isNotEmpty);
      expect(hint.chainLinks, isNotEmpty);
    });

    test('returns null on an empty board', () {
      expect(engine.findAic(_emptyBoard()), isNull);
    });
  });

  group('findGroupedXChain', () {
    // Digit 1: row 0 splits into box chunks {r0c0} | {r0c6,r0c7}, so the
    // pair acts as one grouped node; col 0 and row 8 are plain conjugate
    // pairs. One valid chain is {r0c6,r0c7} = r0c0 ~ r8c0 = r8c7, whose
    // ends both see the 1 in (1,7).
    final groupedFixture = {
      [0, 0]: {1},
      [0, 6]: {1},
      [0, 7]: {1},
      [8, 0]: {1},
      [8, 7]: {1},
      [1, 7]: {1, 7},
    };

    test('a chain through a two-cell group node eliminates the digit from a '
        'cell seeing both ends', () {
      final hint =
          engine.findGroupedXChain(_emptyBoard(), candidatesFrom(groupedFixture));

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.groupedXChain);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryDigits, {1});
      expect(hint.eliminations, isNotEmpty);
      expect(hint.eliminations.every((e) => e.digit == 1), isTrue);
      // Alternating links, and at least one node really is a multi-cell
      // group — that's what distinguishes this from a plain X-Chain. (The
      // fixture admits several valid chains, so no fixed cells asserted.)
      expect(hint.chainLinks, isNotEmpty);
      for (var i = 0; i + 1 < hint.chainLinks.length; i++) {
        expect(hint.chainLinks[i].strong,
            isNot(hint.chainLinks[i + 1].strong));
      }
      expect(hint.chainLinks.first.from.digit,
          hint.chainLinks.last.to.digit);
      expect(
          hint.chainLinks.any(
              (l) => l.from.cells.length > 1 || l.to.cells.length > 1),
          isTrue);
    });

    test('stays silent when only a plain chain exists — that is the plain '
        'finders\' job', () {
      // The findXChain fixture: all segments hold a single candidate, so no
      // group node can form and no group-bearing chain exists.
      final candidates = candidatesFrom({
        [0, 0]: {4},
        [0, 3]: {4},
        [8, 0]: {4},
        [8, 5]: {4},
        [1, 5]: {4, 7},
      });

      expect(engine.findXChain(_emptyBoard(), candidates), isNotNull);
      expect(engine.findGroupedXChain(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findGroupedXChain(_emptyBoard()), isNull);
    });
  });

  group('findGroupedAic', () {
    test('the general grouped chain also solves the single-digit case', () {
      final hint = engine.findGroupedAic(
          _emptyBoard(),
          candidatesFrom({
            [0, 0]: {1},
            [0, 6]: {1},
            [0, 7]: {1},
            [8, 0]: {1},
            [8, 7]: {1},
            [1, 7]: {1, 7},
          }));

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.groupedAic);
      expect(hint.eliminations, isNotEmpty);
      expect(
          hint.chainLinks.any(
              (l) => l.from.cells.length > 1 || l.to.cells.length > 1),
          isTrue);
    });

    test('returns null on an empty board', () {
      expect(engine.findGroupedAic(_emptyBoard()), isNull);
    });
  });

  // An ALS strong link is the only link kind joining two DIFFERENT digits
  // across different cells (bilocation/segment links keep the digit, the
  // bivalue link stays inside one cell) — the tests below use that as the
  // observable "this chain really used an ALS" marker.
  bool usesAlsLink(Hint hint) => hint.chainLinks.any((l) =>
      l.strong &&
      l.from.digit != l.to.digit &&
      !(l.from.cells.length == 1 &&
          l.to.cells.length == 1 &&
          l.from.cells.first == l.to.cells.first));

  group('findAlsXZ', () {
    // A = the bivalue cell (0,0){1,2}; B = the 2-cell ALS {(0,4){1,2},
    // (0,5){1,3}} with candidates {1,2,3}. Digit 2 is restricted common
    // (all its cells share row 0), so digit 1 — in both sets — leaves any
    // cell seeing every 1 of both, e.g. (0,8).
    final alsXzFixture = {
      [0, 0]: {1, 2},
      [0, 4]: {1, 2},
      [0, 5]: {1, 3},
      [0, 8]: {1, 5},
    };

    test('two ALSs joined by a restricted common digit eliminate a shared '
        'digit seeing both', () {
      final hint =
          engine.findAlsXZ(_emptyBoard(), candidatesFrom(alsXzFixture));

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.alsXZ);
      expect(hint.type, HintType.eliminate);
      expect(hint.eliminations, isNotEmpty);
      expect(hint.chainLinks, isNotEmpty);
      for (var i = 0; i + 1 < hint.chainLinks.length; i++) {
        expect(hint.chainLinks[i].strong,
            isNot(hint.chainLinks[i + 1].strong));
      }
      expect(usesAlsLink(hint), isTrue,
          reason: 'an ALS-XZ chain must actually cross an ALS link');
    });

    test('stays silent when only a plain chain exists — that is the plain '
        'finders\' job', () {
      final candidates = candidatesFrom({
        [0, 0]: {4},
        [0, 3]: {4},
        [8, 0]: {4},
        [8, 5]: {4},
        [1, 5]: {4, 7},
      });

      expect(engine.findAlsXZ(_emptyBoard(), candidates), isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findAlsXZ(_emptyBoard()), isNull);
    });
  });

  group('findWXYZWing', () {
    test('a bivalue cell and a 3-cell ALS joined by a restricted common '
        'digit fire as a WXYZ-Wing', () {
      // Bivalue (0,0){1,2} + 3-cell ALS {(2,0){2,3},(3,0){3,4},(4,0){1,2,4}}
      // (4 candidates over 3 cells), all in column 0; RCC 2, shared digit 1
      // also lives in (8,0).
      final hint = engine.findWXYZWing(
          _emptyBoard(),
          candidatesFrom({
            [0, 0]: {1, 2},
            [2, 0]: {2, 3},
            [3, 0]: {3, 4},
            [4, 0]: {1, 2, 4},
            [8, 0]: {1, 9},
          }));

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.wxyzWing);
      expect(hint.eliminations, isNotEmpty);
      // Its defining shape: exactly 4 nodes — one in-cell bivalue strong
      // link and one ALS strong link.
      expect(hint.chainLinks, hasLength(3));
      expect(usesAlsLink(hint), isTrue);
      expect(
          hint.chainLinks.any((l) =>
              l.strong &&
              l.from.cells.length == 1 &&
              l.from.cells.first == l.to.cells.first),
          isTrue,
          reason: 'one strong link must be the bivalue cell');
    });

    test('returns null on an empty board', () {
      expect(engine.findWXYZWing(_emptyBoard()), isNull);
    });
  });

  group('findSueDeCoq', () {
    // Box 0 ∩ row 0: crossing cells (0,0){1,2,3} + (0,1){2,3,4} hold
    // V={1,2,3,4}; the line ALS is the bivalue (0,5){1,4}, the box ALS the
    // bivalue (1,2){2,3} — disjoint digits, V exactly absorbed. So 1/4 are
    // locked to the line side and 2/3 to the box side: (0,7) loses 1 and
    // (2,1) loses 3.
    final fixture = {
      [0, 0]: {1, 2, 3},
      [0, 1]: {2, 3, 4},
      [0, 5]: {1, 4},
      [0, 7]: {1, 5},
      [1, 2]: {2, 3},
      [2, 1]: {3, 9},
    };

    test('crossing cells + line ALS + box ALS lock every digit and eliminate '
        'outside the clusters', () {
      final hint = engine.findSueDeCoq(_emptyBoard(), candidatesFrom(fixture));

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.sueDeCoq);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryCells,
          {const HintCell(0, 0), const HintCell(0, 1)});
      expect(hint.colorGroupA, {const HintCell(0, 5)});
      expect(hint.colorGroupB, {const HintCell(1, 2)});
      expect(hint.eliminations, contains(const HintElimination(0, 7, 1)));
      expect(hint.eliminations, contains(const HintElimination(2, 1, 3)));
      expect(hint.highlightedRows, {0});
      expect(hint.highlightedBoxes, {0});
    });

    test('stays silent when the line and box sets share a digit (the classic '
        'disjoint condition)', () {
      // Same shape but the box ALS is {1,3} — digit 1 overlaps the line
      // ALS's {1,4}, so the disjoint counting argument no longer holds.
      final hint = engine.findSueDeCoq(
          _emptyBoard(),
          candidatesFrom({
            [0, 0]: {1, 2, 3},
            [0, 1]: {2, 3, 4},
            [0, 5]: {1, 4},
            [1, 2]: {1, 3},
          }));

      expect(hint, isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findSueDeCoq(_emptyBoard()), isNull);
    });
  });

  group('findTripleFirework', () {
    // Cross at (4,4): digits 1·2·3 in row 4 live only inside box 4 plus the
    // row wing (4,8); in column 4 only inside the box plus the column wing
    // (8,4). The cross + wings must then hold exactly 1,2,3 — the wings'
    // spare candidates (5, 6) go, and so does the 1 in the box's non-cross
    // cell (3,3).
    final fixture = {
      [4, 3]: {1, 2},
      [4, 4]: {1, 2, 3},
      [4, 5]: {3, 7},
      [4, 8]: {1, 3, 5},
      [3, 4]: {2, 3},
      [5, 4]: {1, 2},
      [8, 4]: {2, 3, 6},
      [3, 3]: {1, 8},
    };

    test('three digits spraying out of one box by a single wing per line '
        'lock the cross and wings to exactly those digits', () {
      final hint =
          engine.findTripleFirework(_emptyBoard(), candidatesFrom(fixture));

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.tripleFirework);
      expect(hint.type, HintType.eliminate);
      expect(hint.primaryDigits, {1, 2, 3});
      expect(hint.primaryCells, {
        const HintCell(4, 4), const HintCell(4, 8), const HintCell(8, 4), //
      });
      expect(hint.eliminations, contains(const HintElimination(4, 8, 5)));
      expect(hint.eliminations, contains(const HintElimination(8, 4, 6)));
      expect(hint.eliminations, contains(const HintElimination(3, 3, 1)));
    });

    test('stays silent when a line leaks by two cells', () {
      // Same shape, but digit 1 gains a second row cell outside the box —
      // the row spray now needs two wings, which is no firework.
      final hint = engine.findTripleFirework(
          _emptyBoard(),
          candidatesFrom({
            ...fixture,
            [4, 7]: {1, 9},
          }));

      expect(hint, isNull);
    });

    test('returns null on an empty board', () {
      expect(engine.findTripleFirework(_emptyBoard()), isNull);
    });

    test('fires on a real generated board (mined seed 40184) and never '
        'eliminates a solution digit', () {
      final rng = Random(40184);
      final solution = BoardGenerator(random: rng).generateSolvedBoard();
      final puzzle = Minimalizer(random: rng)
          .minimalize(ClueRemover(random: rng).removeClues(solution, 24));

      final hint = engine.findTripleFirework(puzzle);

      expect(hint, isNotNull);
      expect(hint!.eliminations, isNotEmpty);
      for (final e in hint.eliminations) {
        expect(solution[e.row][e.col], isNot(e.digit),
            reason: 'firework eliminated r${e.row + 1}c${e.col + 1}\'s '
                'actual solution ${e.digit}');
      }
    });
  });

  group('findAlsAic', () {
    test('the general ALS chain also solves the ALS-XZ case', () {
      final hint = engine.findAlsAic(
          _emptyBoard(),
          candidatesFrom({
            [0, 0]: {1, 2},
            [0, 4]: {1, 2},
            [0, 5]: {1, 3},
            [0, 8]: {1, 5},
          }));

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.alsAic);
      expect(hint.eliminations, isNotEmpty);
      expect(usesAlsLink(hint), isTrue);
    });

    test('returns null on an empty board', () {
      expect(engine.findAlsAic(_emptyBoard()), isNull);
    });
  });

  // Hand-built fixtures can only show that a technique fires where it should.
  // They cannot show it stays silent everywhere it shouldn't — and an
  // over-permissive elimination rule doesn't throw, it quietly removes digits
  // that are the actual answer, corrupting both hints and (for the techniques
  // in humanSolverTechniqueOrder) generated puzzles. So assert the property
  // directly against real dug boards whose solutions are known.
  //
  // Worth the seconds it costs: the rules exercised here are the subtle ones.
  // Finned fish uses "the target must see every fin" rather than the commonly
  // published "all fins share one box" shortcut; XYZ-Wing must require the
  // target to see the pivot too; Remote Pair drops BOTH digits at once.
  // Seeded, so it's deterministic.
  group('elimination soundness', () {
    test('no technique ever eliminates a digit that is the cell\'s actual '
        'solution, across many real generated boards', () {
      final rng = Random(3);
      final engine = HintEngine();
      final found = <HintTechnique, int>{};

      for (var i = 0; i < 150; i++) {
        final solution = BoardGenerator(random: rng).generateSolvedBoard();
        final puzzle = Minimalizer(random: rng)
            .minimalize(ClueRemover(random: rng).removeClues(solution, 24));

        for (final hint in [
          engine.findFinnedSwordfish(puzzle),
          engine.findFinnedJellyfish(puzzle),
          engine.findLockedPair(puzzle),
          engine.findLockedTriple(puzzle),
          engine.findXYZWing(puzzle),
          engine.findWWing(puzzle),
          engine.findRemotePair(puzzle),
          engine.findXChain(puzzle),
          engine.findAic(puzzle),
          engine.findGroupedXChain(puzzle),
          engine.findGroupedAic(puzzle),
          engine.findWXYZWing(puzzle),
          engine.findAlsXZ(puzzle),
          engine.findSueDeCoq(puzzle),
          engine.findTripleFirework(puzzle),
          engine.findAlsAic(puzzle),
        ]) {
          if (hint == null) continue;
          found[hint.technique] = (found[hint.technique] ?? 0) + 1;
          for (final e in hint.eliminations) {
            expect(solution[e.row][e.col], isNot(e.digit),
                reason: '${hint.technique} eliminated ${e.digit} from '
                    'r${e.row + 1}c${e.col + 1}, but that is its solution');
          }
        }
      }

      // Guards the guard: a technique that silently stopped firing would make
      // every assertion above pass vacuously, so require each to be exercised.
      for (final technique in [
        HintTechnique.finnedSwordfish,
        HintTechnique.finnedJellyfish,
        HintTechnique.lockedPair,
        HintTechnique.lockedTriple,
        HintTechnique.xyzWing,
        HintTechnique.wWing,
        HintTechnique.remotePair,
        HintTechnique.xChain,
        HintTechnique.aic,
        HintTechnique.groupedXChain,
        HintTechnique.groupedAic,
        HintTechnique.wxyzWing,
        HintTechnique.alsXZ,
        HintTechnique.sueDeCoq,
        // tripleFirework is absent here on purpose: it fires on ~0.6% of
        // dug boards (3 in 532 when mined), so 150 boards can't guarantee a
        // hit — its own group has a mined real-board test instead.
        HintTechnique.alsAic,
      ]) {
        expect(found[technique] ?? 0, greaterThan(0),
            reason: '$technique never fired across 150 real boards — either '
                'it is dead code or this probe stopped reaching it');
      }
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
      _expectWellFormedChain(
          hint.chainLinks, hint.primaryCells, const HintCell(4, 0));
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

  group('findBugPlusOne', () {
    // A real board+candidates pair taken mid-solve from a genuine
    // BoardGenerator + ClueRemover + Minimalizer puzzle (found by digging
    // real grids and checking whether HumanSolver's history ever used
    // bugPlusOne — see human_solver_test.dart's BUG+1 test for the full
    // derivation). The *candidates* here matter, not just the board:
    // earlier eliminate-type techniques (Intersection Claiming, Naked
    // Pair) had already narrowed several cells' tracked candidates beyond
    // what a fresh board-only computation would show, which is exactly why
    // this fixture supplies them explicitly rather than relying on
    // findBugPlusOne's own board-derived fallback. By this point every
    // other empty cell already has exactly 2 candidates; (8,5) is the sole
    // exception with 3 ({3, 7, 8}). Cross-validated against the puzzle's
    // actual unique solution, which has 7 at (8,5).
    List<List<int>> realBoard() => [
          [8, 3, 9, 6, 7, 5, 4, 2, 1],
          [7, 6, 2, 1, 3, 4, 5, 8, 9],
          [1, 4, 5, 0, 9, 0, 6, 3, 7],
          [4, 8, 3, 7, 2, 1, 9, 6, 5],
          [9, 2, 7, 5, 4, 6, 8, 1, 3],
          [5, 1, 6, 3, 8, 9, 0, 0, 0],
          [0, 0, 8, 0, 6, 0, 1, 0, 0],
          [6, 9, 1, 0, 5, 0, 3, 0, 8],
          [0, 0, 4, 0, 1, 0, 0, 0, 6],
        ];

    List<List<Set<int>>> realCandidates() => candidatesFrom({
          [2, 3]: {2, 8},
          [2, 5]: {2, 8},
          [5, 6]: {2, 7},
          [5, 7]: {4, 7},
          [5, 8]: {2, 4},
          [6, 0]: {2, 3},
          [6, 1]: {5, 7},
          [6, 3]: {4, 9},
          [6, 5]: {3, 7},
          [6, 7]: {5, 9},
          [6, 8]: {2, 4},
          [7, 3]: {2, 4},
          [7, 5]: {2, 7},
          [7, 7]: {4, 7},
          [8, 0]: {2, 3},
          [8, 1]: {5, 7},
          [8, 3]: {8, 9},
          [8, 5]: {3, 7, 8},
          [8, 6]: {2, 7},
          [8, 7]: {5, 9},
        });

    test('fills the one cell with 3 candidates via the deadly-pattern '
        'argument', () {
      final hint = engine.findBugPlusOne(realBoard(), realCandidates());

      expect(hint, isNotNull);
      expect(hint!.technique, HintTechnique.bugPlusOne);
      expect(hint.type, HintType.reveal);
      expect(hint.row, 8);
      expect(hint.col, 5);
      expect(hint.value, 7);
      expect(hint.primaryCells, {const HintCell(8, 5)});
    });

    test('returns null on an empty board', () {
      expect(engine.findBugPlusOne(_emptyBoard()), isNull);
    });

    test('returns null when a second cell also has 3 candidates (not a '
        'clean BUG+1 shape)', () {
      final board = realBoard();
      board[6][2] = 0; // a second empty cell, in a box/row/col of its own
      final candidates = realCandidates();
      candidates[6][2] = {2, 4, 9}; // force a second 3-candidate cell
      expect(engine.findBugPlusOne(board, candidates), isNull);
    });

    test('returns null when every empty cell already has exactly 2 '
        'candidates (no exceptional cell to resolve)', () {
      // Two isolated 2-candidate cells, nowhere near each other, and
      // nothing else empty on the board — enough to fail the "find exactly
      // one 3-candidate cell" precondition without needing a globally
      // consistent deadly-pattern fixture.
      final board = _solvedGrid();
      board[0][6] = 0;
      board[4][4] = 0;
      final candidates = candidatesFrom({
        [0, 6]: {7, 8},
        [4, 4]: {1, 2},
      });
      expect(engine.findBugPlusOne(board, candidates), isNull);
    });

    test('returns null when excluding none of the extra cell\'s candidates '
        'completes a valid deadly pattern', () {
      // Same shape as the real fixture (one 3-candidate cell, rest 2), but
      // with one neighbor's candidates swapped to unrelated digits so no
      // removal choice at (8,5) makes every unit's digits pair up exactly
      // twice.
      final board = realBoard();
      final candidates = realCandidates();
      candidates[6][5] = {4, 5};
      expect(engine.findBugPlusOne(board, candidates), isNull);
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
        HintTechnique.lockedPair,
        HintTechnique.lockedTriple,
        HintTechnique.xWing,
        HintTechnique.nakedPair,
        HintTechnique.nakedTriple,
        HintTechnique.hiddenPair,
        HintTechnique.hiddenTriple,
        HintTechnique.nakedQuad,
        HintTechnique.hiddenQuad,
        HintTechnique.skyscraper,
        HintTechnique.twoStringKite,
        HintTechnique.turbotFish,
        HintTechnique.remotePair,
        HintTechnique.simpleColoring,
        HintTechnique.multiColoring,
        HintTechnique.xyWing,
        HintTechnique.xyzWing,
        HintTechnique.wWing,
        HintTechnique.swordfish,
        HintTechnique.finnedXWing,
        HintTechnique.sashimiXWing,
        HintTechnique.bugPlusOne,
        HintTechnique.xyChain,
        HintTechnique.jellyfish,
        HintTechnique.finnedSwordfish,
        HintTechnique.finnedJellyfish,
        HintTechnique.uniqueRectangleType1,
        HintTechnique.uniqueRectangleType2,
        HintTechnique.uniqueRectangleType3,
        HintTechnique.uniqueRectangleType4,
        HintTechnique.xChain,
        HintTechnique.aic,
        HintTechnique.groupedXChain,
        HintTechnique.groupedAic,
        HintTechnique.wxyzWing,
        HintTechnique.alsXZ,
        HintTechnique.sueDeCoq,
        HintTechnique.tripleFirework,
        HintTechnique.alsAic,
      ]);
    });

    test('returns null on a fully solved board', () {
      expect(engine.findHint(_solvedGrid()), isNull);
    });
  });
}
