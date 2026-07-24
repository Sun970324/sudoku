import 'dart:math';

import '../../models/difficulty.dart';
import '../../models/hint.dart';
import '../../models/sudoku_grid.dart';
import '../../models/sudoku_puzzle.dart';
import 'board_generator.dart';
import 'clue_remover.dart';
import 'difficulty_evaluator.dart';
import 'human_solver.dart';
import 'minimalizer.dart';

/// The dig depths (target given-counts) probed per solved board, tuned to an
/// item's tier. A technique of tier T only surfaces on boards sparse enough to
/// actually *need* tier-T reasoning: dense boards solve by singles and can
/// never show it, so harder items skip the dense depths (measured 0% hit for
/// X-Wing/fish/AIC at 55/42 givens — pure wasted solves).
///
/// But past a point, going *sparser* backfires for the top tiers: a very
/// sparse board (≤24 givens) solved with the full expert ceiling
/// (chains/ALS) costs seconds per solve — measured ~10–16s/board at 22–24
/// givens, which swamps the higher hit rate. So master/expert stay in a
/// moderate band (~26–33 givens) where the technique still appears without
/// the solve-cost blowup. (Truly rare expert boards are better pre-mined into
/// the bundle than found on demand — see tool/generate_technique_boards.dart.)
///
/// This depth tuning is the one deliberate deviation from HoDoKu, whose
/// LEARNING generator digs every board to minimal: HoDoKu's bit-based solver
/// makes full solves of minimal boards nearly free, while this app's chain/ALS
/// finders are the measured cost above — the acceptance semantics
/// ([boardShowsItem]) are HoDoKu's, only the boards probed differ.
List<int> digTargetsFor(Difficulty tier) {
  switch (tier) {
    case Difficulty.beginner:
    case Difficulty.easy:
      return const [55, 42, 35, 30];
    case Difficulty.medium:
      return const [44, 38, 33, 29];
    case Difficulty.hard:
      return const [38, 33, 30, 28];
    case Difficulty.master:
      return const [35, 32, 30, 28];
    case Difficulty.expert:
      return const [33, 31, 29, 28];
  }
}

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

/// HoDoKu's LEARNING acceptance (ref/release2.2.0
/// BackgroundGenerator.generate): solve [board] with the FULL engine —
/// [minableOrder], no tier cap — and accept iff the solve finishes AND
/// [item]'s technique (one of a group of interchangeable ones) appears in
/// the path. Because the solver is strictly cheapest-first, [item] fires
/// exactly where it is the cheapest idea that works, so a harder technique
/// can never steal its spot; dropping the old tier cap only rescues boards
/// that showed the item but then needed one harder step to FINISH — pure
/// yield. (The stricter "unsolvable without it" notion was measured to be
/// near-impossible for most techniques — they substitute for each other —
/// so contains-in-path is the practical bar, exactly HoDoKu's.)
bool boardShowsItem(
  Set<HintTechnique> item,
  List<List<int>> board, {
  HumanSolver Function(List<HintTechnique>)? solverFor,
}) {
  final make = solverFor ?? (o) => HumanSolver(techniqueOrder: o);
  final result = make(minableOrder).solve(board);
  return result.solved && result.history.any(item.contains);
}

/// HoDoKu's PRACTISING acceptance: [boardShowsItem]'s contains-check plus
/// the board's evaluated overall tier must equal [difficulty] — a playable
/// puzzle at the player's chosen level whose solve path features the
/// practiced technique. (Level match is what separates PRACTISING from
/// LEARNING in BackgroundGenerator.generate.)
bool boardShowsItemAtDifficulty(
  Set<HintTechnique> item,
  List<List<int>> board,
  Difficulty difficulty, {
  HumanSolver Function(List<HintTechnique>)? solverFor,
}) {
  final make = solverFor ?? (o) => HumanSolver(techniqueOrder: o);
  final result = make(minableOrder).solve(board);
  if (!result.solved || !result.history.any(item.contains)) return false;
  return DifficultyEvaluator().evaluate(result).highestDifficulty ==
      difficulty;
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
  final targets = digTargetsFor(difficulty);

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
    for (final target in targets) {
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
