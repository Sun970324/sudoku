import 'dart:math';

import '../../models/difficulty.dart';
import '../../models/hint.dart';
import '../../models/sudoku_grid.dart';
import '../../models/sudoku_puzzle.dart';
import 'board_generator.dart';
import 'clue_remover.dart';
import 'human_solver.dart';
import 'minimalizer.dart';

/// Digs one solved board to several depths — shallow boards produce
/// singles-only solve paths, deep minimalized ones the hard families.
const digTargets = [55, 42, 35, 30];

/// Every technique that can be mined, ordered easiest → hardest: the
/// generation order, then the hint-only techniques (all Expert, absent from
/// [humanSolverTechniqueOrder]). BUG+1 is excluded — its precondition never
/// arises on fresh candidates.
final minableOrder = List<HintTechnique>.unmodifiable([
  ...humanSolverTechniqueOrder,
  HintTechnique.finnedSwordfish,
  HintTechnique.finnedJellyfish,
  HintTechnique.groupedXChain,
  HintTechnique.groupedAic,
  HintTechnique.sueDeCoq,
  HintTechnique.tripleFirework,
  HintTechnique.alsAic,
  HintTechnique.aic,
]);

int _tierRank(HintTechnique t) =>
    Difficulty.values.indexOf(techniqueDifficulty[t]!);

/// One entry in the technique-practice list: either a single technique or a
/// group of mutually-substitutable ones (grouped so a board that shows any
/// member counts — e.g. Naked/Hidden Quad are two views of the same shape,
/// and the single-digit chains subsume one another). [id] is the stable key
/// for storage and l10n. BUG+1 is intentionally absent.
class PracticeItem {
  const PracticeItem(this.id, this.techniques);

  final String id;
  final Set<HintTechnique> techniques;
}

const practiceItems = <PracticeItem>[
  PracticeItem('fullHouse', {HintTechnique.fullHouse}),
  PracticeItem('nakedSingle', {HintTechnique.nakedSingle}),
  PracticeItem('hiddenSingle', {HintTechnique.hiddenSingle}),
  PracticeItem('intersectionPointing', {HintTechnique.intersectionPointing}),
  PracticeItem('intersectionClaiming', {HintTechnique.intersectionClaiming}),
  PracticeItem('lockedSubset',
      {HintTechnique.lockedPair, HintTechnique.lockedTriple}),
  PracticeItem('nakedPair', {HintTechnique.nakedPair}),
  PracticeItem('hiddenPair', {HintTechnique.hiddenPair}),
  // Naked/Hidden Triple grouped: Hidden Triple alone is rare (the naked
  // complement usually resolves the same cells first).
  PracticeItem('triple',
      {HintTechnique.nakedTriple, HintTechnique.hiddenTriple}),
  PracticeItem('xWing', {HintTechnique.xWing}),
  PracticeItem('singleDigitChain', {
    HintTechnique.skyscraper,
    HintTechnique.twoStringKite,
    HintTechnique.turbotFish,
    HintTechnique.xChain,
    HintTechnique.simpleColoring,
  }),
  PracticeItem('xyWing', {HintTechnique.xyWing}),
  PracticeItem('remotePair', {HintTechnique.remotePair}),
  PracticeItem('xyzWing', {HintTechnique.xyzWing}),
  PracticeItem('wWing', {HintTechnique.wWing}),
  // Swordfish/Jellyfish grouped: Jellyfish alone is very rare, Swordfish
  // common — the group surfaces quickly on the Swordfish side.
  PracticeItem('fish', {HintTechnique.swordfish, HintTechnique.jellyfish}),
  PracticeItem('finnedFish', {
    HintTechnique.finnedXWing,
    HintTechnique.sashimiXWing,
    HintTechnique.finnedSwordfish,
    HintTechnique.finnedJellyfish,
  }),
  PracticeItem('quad', {HintTechnique.nakedQuad, HintTechnique.hiddenQuad}),
  PracticeItem('uniqueRectangle', {
    HintTechnique.uniqueRectangleType1,
    HintTechnique.uniqueRectangleType2,
    HintTechnique.uniqueRectangleType3,
    HintTechnique.uniqueRectangleType4,
  }),
  PracticeItem('xyChain', {HintTechnique.xyChain}),
  PracticeItem('wxyzWing', {HintTechnique.wxyzWing}),
  PracticeItem('alsXZ', {HintTechnique.alsXZ}),
  PracticeItem('sueDeCoq', {HintTechnique.sueDeCoq}),
  PracticeItem('tripleFirework', {HintTechnique.tripleFirework}),
  PracticeItem('groupedChain',
      {HintTechnique.groupedXChain, HintTechnique.groupedAic}),
  PracticeItem('aic', {HintTechnique.aic, HintTechnique.alsAic}),
];

/// Whether solving [board] with only the techniques up to [item]'s tier
/// naturally USES [item] (a single technique, or a group of interchangeable
/// ones): the board solves within that difficulty ceiling AND the item's
/// technique actually appears in the solve. Capping at the item's tier —
/// not the full engine — means it isn't quietly resolved by a harder
/// technique the learner hasn't met; the board is a genuine practice case
/// for [item]. (The stricter "unsolvable without it" notion was measured to
/// be near-impossible for most techniques — they substitute for each other
/// — so this is the practical bar.)
bool boardShowsItem(
  Set<HintTechnique> item,
  List<List<int>> board, {
  HumanSolver Function(List<HintTechnique>)? solverFor,
}) {
  final tier = item.map(_tierRank).reduce(max);
  final ceiling = [
    for (final t in minableOrder)
      if (_tierRank(t) <= tier) t,
  ];
  final make = solverFor ?? (o) => HumanSolver(techniqueOrder: o);
  final result = make(ceiling).solve(board);
  return result.solved && result.history.any(item.contains);
}

/// Mines one puzzle that shows [item] per [boardShowsItem] — the refill
/// source behind the technique-practice queue. Scans up to [maxSeeds]
/// random boards (each probed at several dig depths) and returns null when
/// the budget runs out; the caller treats that as "retry later".
SudokuPuzzle? mineTechniqueBoard(
  Set<HintTechnique> item, {
  int maxSeeds = 600,
  Random? random,
}) {
  final rng = random ?? Random();
  final solverCache = <String, HumanSolver>{};
  HumanSolver solverFor(List<HintTechnique> order) => solverCache.putIfAbsent(
      order.map((t) => t.index).join(','),
      () => HumanSolver(techniqueOrder: order));
  final difficulty = techniqueDifficulty[item.reduce(
      (a, b) => _tierRank(a) >= _tierRank(b) ? a : b)]!;

  SudokuPuzzle? tryBoard(List<List<int>> board, List<List<int>> solution) {
    if (!boardShowsItem(item, board, solverFor: solverFor)) return null;
    return SudokuPuzzle(
      puzzle: SudokuGrid(board.map((r) => List<int>.from(r)).toList()),
      solution: SudokuGrid(solution.map((r) => List<int>.from(r)).toList()),
      fixedMask: List.generate(
          9, (r) => List.generate(9, (c) => board[r][c] != 0)),
      difficulty: difficulty,
    );
  }

  for (var i = 0; i < maxSeeds; i++) {
    final solution = BoardGenerator(random: rng).generateSolvedBoard();
    for (final target in digTargets) {
      final dug = ClueRemover(random: rng).removeClues(solution, target);
      final found = tryBoard(dug, solution);
      if (found != null) return found;
    }
    final minimal = Minimalizer(random: rng)
        .minimalize(ClueRemover(random: rng).removeClues(solution, 24));
    final found = tryBoard(minimal, solution);
    if (found != null) return found;
  }
  return null;
}
