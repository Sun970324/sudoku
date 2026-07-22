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
    // A genuine puzzle produced by BoardGenerator + ClueRemover +
    // Minimalizer where Simple Coloring is the technique that breaks a stall
    // even though every single-digit chain technique (Skyscraper, 2-String
    // Kite, Turbot Fish) and Remote Pair are all tried before it — confirmed
    // by running this exact board: history[45] is simpleColoring, history[46]
    // is an immediately-following nakedSingle, and the puzzle goes on to
    // fully solve. Hand-crafting an equivalent board from scratch turned out
    // to be impractical (a 2-3 cell conjugate pattern confined to one
    // box/line is always also solvable by an earlier technique — a real
    // generated puzzle is what actually needs Simple Coloring).
    //
    // The previous board here was retired when Remote Pair was added ahead of
    // Simple Coloring and preempted it — the deliberate "more specific
    // deduction wins" effect, same as when the Turbot family landed. Replaced
    // by re-mining rather than by reordering the engine to suit the test.
    final board = [
      [0, 1, 6, 3, 8, 0, 0, 0, 0],
      [0, 0, 0, 6, 0, 0, 0, 0, 0],
      [9, 0, 0, 0, 4, 0, 0, 0, 0],
      [0, 5, 0, 8, 0, 0, 0, 0, 2],
      [1, 0, 0, 0, 2, 0, 0, 0, 6],
      [0, 0, 0, 0, 1, 6, 9, 0, 0],
      [0, 0, 0, 0, 9, 0, 4, 0, 0],
      [0, 8, 7, 2, 0, 0, 0, 0, 1],
      [0, 0, 2, 1, 6, 0, 0, 0, 5],
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
    // A genuine puzzle (BoardGenerator + ClueRemover 24 + Minimalizer, seed
    // 80020) whose solve history includes Swordfish — confirmed by running
    // this exact board. Asserts `contains` rather than `last`: once the
    // fixed-shape ALS/chain techniques (X-Chain, WXYZ-Wing, ALS-XZ) were
    // promoted into generation they sit after Swordfish, so "Swordfish is
    // the final technique" is no longer a stable property — that Swordfish
    // fires at all is the point.
    final board = [
      [7, 0, 0, 1, 5, 3, 0, 0, 0],
      [0, 0, 0, 0, 0, 9, 0, 7, 0],
      [0, 9, 0, 0, 7, 0, 0, 0, 8],
      [6, 7, 0, 0, 0, 0, 0, 0, 9],
      [2, 0, 1, 0, 0, 0, 8, 0, 0],
      [0, 0, 0, 3, 0, 0, 2, 0, 0],
      [4, 0, 2, 0, 0, 0, 1, 8, 0],
      [0, 0, 5, 0, 0, 2, 0, 0, 4],
      [0, 0, 0, 0, 4, 0, 0, 0, 0],
    ];

    final result = HumanSolver().solve(board);

    expect(result.history, contains(HintTechnique.swordfish));
  });

  test('Finned X-Wing narrows candidates before the solver gets stuck, on '
      'a real generated puzzle', () {
    // A genuine puzzle (BoardGenerator + ClueRemover 24 + Minimalizer, seed
    // 80019) whose solve history includes Finned X-Wing — confirmed by
    // running this exact board. Re-mined after the fixed-shape ALS/chain
    // techniques were promoted into generation (they preempted the old
    // fixture's route to Finned X-Wing).
    final board = [
      [0, 0, 0, 0, 0, 4, 0, 0, 9],
      [0, 4, 0, 5, 0, 0, 0, 0, 7],
      [0, 5, 9, 0, 0, 1, 0, 0, 0],
      [7, 0, 0, 0, 2, 0, 0, 0, 0],
      [1, 2, 0, 0, 0, 0, 3, 0, 0],
      [0, 0, 6, 0, 0, 0, 0, 1, 5],
      [0, 7, 0, 0, 3, 0, 9, 0, 0],
      [9, 0, 0, 0, 0, 0, 0, 3, 0],
      [0, 0, 0, 7, 0, 0, 4, 0, 1],
    ];

    final result = HumanSolver().solve(board);

    expect(result.history, contains(HintTechnique.finnedXWing));
  });

  test('Sashimi X-Wing narrows candidates enough to unlock a subsequent '
      'Naked Single, on a real generated puzzle', () {
    // A genuine puzzle where Sashimi X-Wing is the technique that breaks a
    // stall even with the single-digit chain techniques (Skyscraper,
    // 2-String Kite, Turbot Fish) tried before it — confirmed by running
    // this exact board: history[16] is sashimiXWing and history[17] is an
    // immediately-following nakedSingle, and the puzzle goes on to fully
    // solve.
    final board = [
      [0, 8, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 1, 0, 6, 8, 0, 0, 0],
      [0, 0, 5, 0, 0, 1, 2, 0, 0],
      [0, 0, 2, 0, 0, 0, 4, 3, 0],
      [0, 7, 0, 0, 8, 2, 6, 0, 0],
      [5, 0, 0, 0, 7, 3, 0, 0, 8],
      [0, 0, 7, 0, 2, 0, 0, 0, 6],
      [9, 0, 0, 0, 0, 0, 0, 1, 0],
      [0, 0, 0, 0, 9, 7, 5, 0, 0],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isTrue);
    expect(result.history, contains(HintTechnique.sashimiXWing));
    final sashimiIndex = result.history.indexOf(HintTechnique.sashimiXWing);
    expect(result.history[sashimiIndex + 1], HintTechnique.nakedSingle);
  });

  test('BUG+1 fills the one cell with 3 candidates on a real generated '
      'puzzle, and the solve goes on to complete', () {
    // Same approach as the other hard-technique tests above — found by
    // digging a real BoardGenerator grid (via ClueRemover + Minimalizer,
    // 22-given target) and checking whether the resulting solve history
    // ever used bugPlusOne, rather than hand-building a fixture (BUG+1
    // requires literally every other empty cell on the whole board to
    // already have exactly 2 real candidates, not just a local pattern —
    // by far the least practical of these to construct by hand). Confirmed
    // by running this exact board: bugPlusOne fires exactly once, at
    // row 8/col 5 (0-indexed), filling it with 7 — the cell's 3 real
    // candidates there are {3, 7, 8} — and the puzzle goes on to fully
    // solve afterward.
    final board = [
      [0, 3, 0, 0, 7, 5, 4, 0, 0],
      [0, 0, 2, 1, 3, 0, 0, 8, 0],
      [1, 0, 0, 0, 0, 0, 0, 0, 7],
      [0, 0, 0, 0, 2, 0, 0, 6, 5],
      [0, 2, 7, 5, 0, 0, 0, 1, 3],
      [0, 0, 0, 0, 0, 9, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [6, 9, 0, 0, 0, 0, 3, 0, 0],
      [0, 0, 4, 0, 1, 0, 0, 0, 0],
    ];

    final result = HumanSolver().solve(board);

    expect(result.solved, isTrue);
    expect(result.techniqueCounts[HintTechnique.bugPlusOne], 1);
    expect(result.board[8][5], 7);
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
