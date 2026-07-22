import '../models/difficulty.dart';
import '../models/hint.dart';
import '../models/sudoku_grid.dart';
import '../models/sudoku_puzzle.dart';
import '../services/sudoku_solver.dart';

/// A concrete puzzle known to contain an Alternating Inference Chain, for the
/// debug-only "AIC 힌트 데모" entry. Mined offline (seeded generator) so it
/// loads instantly. Its AIC uses a bivalue intra-cell hop — a genuine AIC
/// beyond a plain X-Chain:
///   r7c4(1) =S= r7c6(1) ~W~ r7c6(9) =S= r9c5(9)  =>  r9c5 loses 1
///
/// Debug builds only — nothing in a release build references this.
const _aicGivens = <List<int>>[
  [0, 0, 0, 6, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 8, 0, 2, 0],
  [4, 1, 8, 0, 0, 7, 0, 0, 0],
  [0, 0, 1, 9, 0, 3, 0, 0, 0],
  [0, 6, 0, 0, 0, 0, 4, 5, 0],
  [0, 9, 0, 0, 7, 0, 0, 0, 1],
  [6, 7, 0, 0, 8, 0, 0, 0, 0],
  [9, 0, 0, 0, 0, 0, 0, 1, 4],
  [0, 0, 0, 0, 0, 2, 0, 0, 0],
];

SudokuPuzzle aicDemoPuzzle() => _demoPuzzle(_aicGivens);

/// A puzzle mined (seed 9075, real generator pipeline) so that NO plain
/// X-Chain/AIC exists but a Grouped X-Chain does — the debug bug icon's
/// fallback therefore lands on the grouped finder. Its chain runs through
/// three group nodes, one link even group-to-group:
///   r6c4(3) =S= r5c4·r5c6(3) ~W~ r5c1·r5c3(3) =S= r6c1·r6c3(3)
///     =>  r6c8 and r6c9 lose 3
const _groupedGivens = <List<int>>[
  [0, 0, 0, 0, 7, 0, 0, 1, 0],
  [2, 0, 0, 0, 3, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 1, 0, 0, 5],
  [4, 0, 7, 6, 0, 2, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 8, 2],
  [0, 8, 0, 0, 0, 4, 7, 0, 0],
  [5, 0, 0, 0, 0, 0, 0, 6, 0],
  [0, 0, 0, 7, 0, 0, 9, 0, 0],
  [0, 3, 9, 0, 0, 0, 8, 0, 7],
];

SudokuPuzzle groupedChainDemoPuzzle() => _demoPuzzle(_groupedGivens);

/// Boards mined (real generator pipeline, seeds 70000 / 70001 / 40184) so
/// each ALS-family finder fires on fresh notes with a sound elimination.
/// The demo bug icon asks the picked technique's finder DIRECTLY (see
/// [GameScreen.debugDemoTechnique]), so unlike [_groupedGivens] these need
/// no "nothing earlier fires" condition — one board can serve two demos.
const _alsXzGivens = <List<int>>[
  [0, 0, 5, 1, 0, 0, 0, 0, 0],
  [8, 0, 6, 0, 0, 0, 1, 0, 0],
  [4, 0, 0, 0, 0, 5, 0, 8, 0],
  [0, 0, 9, 2, 0, 0, 0, 1, 0],
  [0, 0, 0, 0, 0, 0, 2, 0, 0],
  [0, 0, 0, 0, 0, 4, 3, 0, 7],
  [0, 0, 0, 0, 0, 9, 0, 0, 5],
  [0, 0, 0, 0, 4, 8, 0, 0, 2],
  [3, 6, 0, 0, 7, 0, 0, 0, 0],
];

const _wxyzGivens = <List<int>>[
  [0, 9, 5, 0, 0, 0, 0, 0, 0],
  [1, 0, 0, 5, 0, 6, 0, 7, 4],
  [4, 0, 0, 0, 8, 0, 0, 0, 0],
  [0, 6, 0, 0, 0, 9, 0, 0, 0],
  [2, 0, 0, 0, 3, 5, 0, 0, 8],
  [0, 0, 7, 0, 0, 1, 0, 0, 2],
  [0, 3, 9, 0, 0, 0, 0, 6, 0],
  [0, 1, 0, 2, 0, 0, 0, 0, 5],
  [7, 0, 0, 0, 0, 0, 0, 0, 0],
];

const _fireworkGivens = <List<int>>[
  [2, 0, 0, 0, 0, 0, 3, 0, 8],
  [5, 0, 3, 0, 9, 0, 0, 0, 0],
  [0, 7, 0, 2, 0, 0, 0, 0, 0],
  [3, 0, 5, 0, 0, 0, 0, 2, 0],
  [4, 0, 9, 0, 8, 6, 0, 0, 0],
  [0, 6, 0, 4, 0, 0, 0, 0, 0],
  [0, 0, 0, 8, 1, 9, 6, 4, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 2],
  [0, 0, 0, 6, 0, 3, 0, 0, 1],
];

/// The demo board for one ALS-family technique (any other technique maps
/// to the ALS-XZ board — its general chains fire there too).
SudokuPuzzle alsDemoPuzzle(HintTechnique technique) =>
    _demoPuzzle(switch (technique) {
      HintTechnique.wxyzWing || HintTechnique.sueDeCoq => _wxyzGivens,
      HintTechnique.tripleFirework => _fireworkGivens,
      _ => _alsXzGivens,
    });

SudokuPuzzle _demoPuzzle(List<List<int>> board) {
  final givens = board.map((row) => List<int>.from(row)).toList();
  final solution = SudokuSolver().solve(givens)!;
  return SudokuPuzzle(
    puzzle: SudokuGrid(givens),
    solution: SudokuGrid(solution),
    fixedMask: List.generate(
        9, (r) => List.generate(9, (c) => givens[r][c] != 0)),
    difficulty: Difficulty.expert,
  );
}
