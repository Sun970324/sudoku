import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/generation/human_solver.dart';

// Classic example solved grid (also used in sudoku_solver_test.dart).
const _solved = [
  [5, 3, 4, 6, 7, 8, 9, 1, 2],
  [6, 7, 2, 1, 9, 5, 3, 4, 8],
  [1, 9, 8, 3, 4, 2, 5, 6, 7],
  [8, 5, 9, 7, 6, 1, 4, 2, 3],
  [4, 2, 6, 8, 5, 3, 7, 9, 1],
  [7, 1, 3, 9, 2, 4, 8, 5, 6],
  [9, 6, 1, 5, 3, 7, 2, 8, 4],
  [2, 8, 7, 4, 1, 9, 6, 3, 5],
  [3, 4, 5, 2, 8, 6, 1, 7, 9],
];

List<List<int>> _emptyBoard() => List.generate(9, (_) => List.filled(9, 0));

void main() {
  test('fully solves a puzzle where every gap is a lone missing cell in '
      'its row/column/box (Full House chain)', () {
    // Three isolated single-cell gaps, spread across different rows,
    // columns, and boxes so they never interact.
    final board = _solved.map((row) => List<int>.from(row)).toList();
    board[0][0] = 0;
    board[4][4] = 0;
    board[8][8] = 0;

    final result = HumanSolver().solve(board);

    expect(result.solved, isTrue);
    expect(result.board, equals(_solved));
    expect(result.history, everyElement(HintTechnique.fullHouse));
    expect(result.history, hasLength(3));
    expect(result.techniqueCounts, {HintTechnique.fullHouse: 3});
  });

  test('narrows candidates via an eliminate-type technique but still gets '
      'stuck (solved=false) with the board left unchanged, when nothing '
      'ever unlocks a full solve', () {
    // Same fixture used for findIntersectionPointing in hint_engine_test —
    // sparse enough that Intersection Pointing keeps finding fresh digits
    // to strike (three different ones, confirmed via the actual run) but
    // never enough to unlock a Naked/Hidden Single anywhere on this
    // otherwise near-empty board.
    final board = _emptyBoard();
    board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
    board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];

    final result = HumanSolver().solve(board);

    expect(result.solved, isFalse);
    expect(result.history, isNotEmpty);
    expect(result.history, everyElement(HintTechnique.intersectionPointing));
    // Eliminate-type techniques only narrow candidates, never the board.
    expect(result.board, equals(board));
  });

  test('an eliminate-type technique narrows candidates enough to unlock a '
      'subsequent reveal-type technique, proving the tracked candidate '
      'grid actually carries forward between loop iterations', () {
    // Same Intersection Pointing box fixture as above (digit 5 confined to
    // row 0 within box (0,0)), plus (0,3) shaped (via row/column givens)
    // to have exactly two candidates, {5, 9}, before the elimination.
    // Confirmed by running this exact fixture: once Intersection Pointing
    // strikes 5 from (0,3), it collapses to a Naked Single on 9 — if
    // HumanSolver recomputed candidates fresh from the board on every
    // iteration (ignoring its own prior elimination), this would never
    // happen, since the board itself never changes when an eliminate-type
    // technique fires.
    final board = _emptyBoard();
    board[1] = [1, 2, 3, 0, 0, 0, 0, 0, 0];
    board[2] = [4, 6, 7, 0, 0, 0, 0, 0, 0];
    board[0] = [0, 0, 0, 0, 1, 2, 3, 4, 6]; // row exclusion narrows (0,3)
    board[4][3] = 7; // column exclusion narrows (0,3) further
    board[5][3] = 8; // ...down to exactly {5, 9}

    final result = HumanSolver().solve(board);

    expect(result.history.first, HintTechnique.intersectionPointing);
    expect(result.history, contains(HintTechnique.nakedSingle));
    expect(result.board[0][3], 9);
  });

  test('gets stuck partway (solved=false) but keeps whatever progress '
      'singles alone could make', () {
    // Row 0 has a genuine naked single at (0,0) (candidates {1}), but the
    // rest of the board is otherwise empty and far too underconstrained
    // for singles to finish it off.
    final board = _emptyBoard();
    board[0] = [0, 2, 3, 4, 5, 6, 7, 8, 0];
    board[1][0] = 9;

    final result = HumanSolver().solve(board);

    expect(result.solved, isFalse);
    expect(result.history, isNotEmpty);
    expect(result.board[0][0], 1);
  });

  test('Simple Coloring narrows candidates enough to unlock a subsequent '
      'Naked Single, on a real generated puzzle', () {
    // A genuine puzzle produced by BoardGenerator + ClueRemover (22 givens)
    // where singles/intersections/hidden-pair alone stall out and Simple
    // Coloring is the technique that breaks the stall — confirmed by
    // running this exact board: history[10] is simpleColoring and
    // history[11] is an immediately-following nakedSingle, and the puzzle
    // goes on to fully solve. Hand-crafting an equivalent board from
    // scratch turned out to be impractical (a 2-3 cell conjugate pattern
    // confined to one box/line is always also solvable by Intersection
    // Pointing/Claiming, which is tried first — a real generated puzzle is
    // what actually needs Simple Coloring).
    final board = [
      [0, 0, 1, 0, 0, 0, 0, 8, 0],
      [6, 0, 0, 0, 0, 4, 0, 0, 2],
      [0, 2, 0, 9, 0, 0, 7, 0, 0],
      [0, 0, 0, 0, 1, 6, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 4, 0, 1],
      [0, 0, 0, 0, 3, 2, 0, 6, 0],
      [4, 0, 6, 3, 0, 0, 0, 0, 0],
      [3, 1, 0, 0, 0, 0, 5, 7, 0],
      [0, 8, 5, 0, 0, 0, 0, 0, 4],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isTrue);
    expect(result.history, contains(HintTechnique.simpleColoring));
    final coloringIndex =
        result.history.indexOf(HintTechnique.simpleColoring);
    expect(result.history[coloringIndex + 1], HintTechnique.nakedSingle);
  });

  test('XY-Wing narrows candidates enough to unlock a subsequent Naked '
      'Single, on a real generated puzzle', () {
    // Same approach as the Simple Coloring test above — a genuine puzzle
    // from BoardGenerator + ClueRemover (21 givens) where XY-Wing is the
    // technique that breaks a stall, found by searching generated puzzles
    // rather than hand-building one (XY-Wing has to survive every earlier
    // technique including Simple Coloring itself, making a hand-built
    // fixture even less practical than Simple Coloring's). Confirmed by
    // running this exact board: history[40] is xyWing and history[41] is
    // an immediately-following nakedSingle, and the puzzle goes on to
    // fully solve.
    final board = [
      [2, 0, 0, 0, 3, 0, 6, 0, 7],
      [0, 0, 1, 0, 0, 0, 0, 0, 0],
      [7, 0, 0, 0, 0, 0, 3, 0, 4],
      [6, 0, 0, 0, 0, 0, 0, 3, 0],
      [0, 7, 0, 0, 0, 0, 0, 9, 0],
      [0, 0, 0, 0, 4, 0, 0, 0, 8],
      [0, 5, 0, 0, 0, 3, 9, 6, 0],
      [0, 1, 7, 5, 0, 0, 0, 0, 0],
      [0, 0, 8, 0, 0, 9, 5, 0, 0],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isTrue);
    expect(result.history, contains(HintTechnique.xyWing));
    final wingIndex = result.history.indexOf(HintTechnique.xyWing);
    expect(result.history[wingIndex + 1], HintTechnique.nakedSingle);
  });

  test('Swordfish narrows candidates before the solver gets stuck, on a '
      'real generated puzzle', () {
    // A genuine puzzle from BoardGenerator + ClueRemover (20 givens) where
    // singles/intersections alone stall out and Swordfish is the last
    // technique that still finds something before the solver runs out of
    // known techniques entirely — confirmed by running this exact board:
    // history's last entry (index 18 of 19) is swordfish, and solved is
    // false (nothing beyond Swordfish is implemented yet to finish it).
    final board = [
      [2, 0, 0, 4, 0, 0, 1, 0, 7],
      [0, 0, 0, 8, 0, 0, 0, 2, 0],
      [7, 0, 4, 0, 0, 5, 0, 0, 0],
      [1, 0, 8, 0, 2, 7, 0, 0, 0],
      [0, 0, 0, 9, 4, 0, 6, 0, 2],
      [0, 0, 0, 6, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 1, 3],
      [0, 0, 0, 0, 6, 0, 5, 0, 0],
      [0, 3, 7, 0, 0, 0, 0, 0, 0],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isFalse);
    expect(result.history, isNotEmpty);
    expect(result.history.last, HintTechnique.swordfish);
  });

  test('Finned X-Wing narrows candidates before the solver gets stuck, on '
      'a real generated puzzle', () {
    // A genuine puzzle (18 givens) where the solver progresses through
    // singles/intersections, then Finned X-Wing fires (twice) before
    // getting stuck — confirmed by running this exact board: history ends
    // with two consecutive finnedXWing entries and solved is false.
    final board = [
      [1, 0, 0, 0, 0, 0, 0, 0, 0],
      [2, 0, 0, 8, 6, 0, 0, 0, 1],
      [0, 9, 0, 0, 0, 7, 0, 0, 0],
      [0, 0, 0, 0, 0, 3, 0, 8, 0],
      [5, 0, 0, 0, 2, 0, 0, 0, 9],
      [3, 0, 0, 0, 0, 0, 0, 0, 4],
      [6, 0, 5, 0, 0, 4, 0, 0, 0],
      [9, 0, 0, 0, 0, 1, 4, 0, 5],
      [0, 1, 4, 5, 7, 0, 0, 0, 2],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isFalse);
    expect(result.history, contains(HintTechnique.finnedXWing));
  });

  test('Sashimi X-Wing narrows candidates enough to unlock a subsequent '
      'Naked Single, on a real generated puzzle', () {
    // A genuine puzzle (17 givens) where Sashimi X-Wing is the technique
    // that breaks a stall — confirmed by running this exact board:
    // history[45] is sashimiXWing and history[46] is an
    // immediately-following nakedSingle, and the puzzle goes on to fully
    // solve.
    final board = [
      [0, 0, 0, 1, 0, 5, 4, 0, 0],
      [0, 0, 0, 0, 0, 4, 3, 5, 0],
      [0, 6, 0, 0, 0, 0, 2, 0, 0],
      [0, 2, 0, 4, 7, 0, 0, 3, 0],
      [0, 0, 0, 0, 0, 0, 8, 0, 9],
      [0, 8, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 8, 2, 0, 0, 0, 7, 0],
      [6, 3, 0, 5, 0, 0, 0, 0, 0],
      [0, 4, 2, 0, 3, 7, 5, 0, 0],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isTrue);
    expect(result.history, contains(HintTechnique.sashimiXWing));
    final sashimiIndex = result.history.indexOf(HintTechnique.sashimiXWing);
    expect(result.history[sashimiIndex + 1], HintTechnique.nakedSingle);
  });

  test('XY-Chain narrows candidates enough to unlock a subsequent Naked '
      'Single, on a real generated puzzle', () {
    // A genuine puzzle (18 givens) where XY-Chain is the technique that
    // breaks a stall after Simple Coloring/Intersection Claiming/XY-Wing
    // all stop finding anything new — confirmed by running this exact
    // board: history[50] is xyChain and history[51] is an
    // immediately-following nakedSingle, and the puzzle goes on to fully
    // solve.
    final board = [
      [0, 2, 0, 0, 7, 0, 1, 0, 0],
      [9, 0, 0, 0, 1, 0, 0, 8, 0],
      [0, 1, 0, 5, 0, 0, 0, 7, 0],
      [8, 0, 0, 0, 6, 0, 0, 3, 0],
      [0, 0, 3, 0, 0, 0, 5, 1, 0],
      [0, 4, 0, 0, 0, 1, 0, 6, 0],
      [0, 0, 0, 0, 0, 3, 8, 0, 0],
      [0, 8, 0, 7, 0, 0, 0, 5, 0],
      [6, 0, 0, 0, 0, 9, 3, 0, 0],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isTrue);
    expect(result.history, contains(HintTechnique.xyChain));
    final chainIndex = result.history.indexOf(HintTechnique.xyChain);
    expect(result.history[chainIndex + 1], HintTechnique.nakedSingle);
  });

  test('does not mutate the input board', () {
    final board = _solved.map((row) => List<int>.from(row)).toList();
    board[0][0] = 0;
    final original = board.map((row) => List<int>.from(row)).toList();

    HumanSolver().solve(board);

    expect(board, equals(original));
  });
}
