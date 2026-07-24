import 'dart:math';

import '../../models/hint.dart';
import '../../models/sudoku_grid.dart';
import '../../models/sudoku_puzzle.dart';
import '../sudoku_solver.dart';
import 'board_generator.dart';
import 'human_solver.dart';

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

/// The technique set a category's practice board is solved with: every
/// technique in [category] or any easier one — the "ceiling". Ordered
/// **category-major** (all of an easier category before any of a harder one),
/// then by solver priority within a category. This matters: [minableOrder]
/// priority is NOT category-monotonic (e.g. Naked Pair, a Subset, is tried
/// before Locked Triple, an Intersection), so a plain minableOrder solve could
/// reach for a [category] technique when an easier category would have
/// finished — making [boardRequiresCategory] misjudge. Category-major order
/// exhausts every easier idea first, so "the solve needed [category]" is real.
List<HintTechnique> categoryCeilingOrder(TechniqueCategory category) {
  final included = [
    for (final t in minableOrder)
      if (techniqueCategory[t]!.index <= category.index) t,
  ];
  included.sort((a, b) {
    final byCategory =
        techniqueCategory[a]!.index.compareTo(techniqueCategory[b]!.index);
    if (byCategory != 0) return byCategory;
    return minableOrder.indexOf(a).compareTo(minableOrder.indexOf(b));
  });
  return included;
}

/// Whether [board] is a genuine practice case for [category]: it solves using
/// only [category]'s ceiling AND the hardest category it actually needs is
/// exactly [category] (not an easier one). Because the solver is
/// cheapest-first, the ceiling reaching into [category] means nothing easier
/// sufficed — so the category is really required, the HoDoKu practising bar
/// applied per-category instead of per-single-technique.
bool boardRequiresCategory(
  TechniqueCategory category,
  List<List<int>> board, {
  HumanSolver Function(List<HintTechnique>)? solverFor,
}) {
  final make = solverFor ?? (o) => HumanSolver(techniqueOrder: o);
  final result = make(categoryCeilingOrder(category)).solve(board);
  if (!result.solved) return false;
  final maxRank = result.history
      .map((t) => techniqueCategory[t]!.index)
      .fold(-1, (a, b) => a > b ? a : b);
  return maxRank == category.index;
}

/// Mines one puzzle that's a genuine practice case for [category] (see
/// [boardRequiresCategory]) — the refill source behind the category-based
/// practice queue. Digs each solved board *within the category ceiling* down
/// to the sparsest still-solvable form, so the result is a real puzzle you
/// work through with that category's ideas — e.g. a Singles board is a genuine
/// easy sudoku solvable by singles alone, not a near-complete grid with one
/// Full House. Returns null when [maxSeeds] is exhausted (caller retries
/// later).
SudokuPuzzle? mineCategoryBoard(
  TechniqueCategory category, {
  int maxSeeds = 400,
  Random? random,
}) {
  final rng = random ?? Random();
  final ceiling = HumanSolver(techniqueOrder: categoryCeilingOrder(category));
  final uniqueness = SudokuSolver();
  final difficulty = categoryDifficulty(category);

  for (var seed = 0; seed < maxSeeds; seed++) {
    final solution = BoardGenerator(random: rng).generateSolvedBoard();
    final dug = _digWithinCeiling(solution, rng, uniqueness, ceiling);
    final result = ceiling.solve(dug);
    if (!result.solved) continue;
    final maxRank = result.history
        .map((t) => techniqueCategory[t]!.index)
        .fold(-1, (a, b) => a > b ? a : b);
    if (maxRank != category.index) continue; // an easier category cracks it
    return SudokuPuzzle(
      puzzle: SudokuGrid(dug.map((r) => List<int>.from(r)).toList()),
      solution: SudokuGrid(solution.map((r) => List<int>.from(r)).toList()),
      fixedMask:
          List.generate(9, (r) => List.generate(9, (c) => dug[r][c] != 0)),
      difficulty: difficulty,
    );
  }
  return null;
}

/// Single-pass blind dig (HoDoKu's `generateInitPos` shape): try every cell
/// once in random order, keeping a removal only while the board stays
/// uniquely solvable AND still solvable within [ceiling]. Lands at the
/// sparsest board that ceiling can crack — the hardest such board, most
/// likely to actually need the top of the ceiling.
List<List<int>> _digWithinCeiling(
  List<List<int>> solution,
  Random rng,
  SudokuSolver uniqueness,
  HumanSolver ceiling,
) {
  final puzzle = solution.map((r) => List<int>.from(r)).toList();
  final cells = [for (var i = 0; i < 81; i++) i]..shuffle(rng);
  for (final cell in cells) {
    final r = cell ~/ 9, c = cell % 9;
    final backup = puzzle[r][c];
    if (backup == 0) continue;
    puzzle[r][c] = 0;
    if (uniqueness.countSolutions(puzzle, limit: 2) == 1 &&
        ceiling.solve(puzzle).solved) {
      continue; // keep it removed
    }
    puzzle[r][c] = backup; // undo
  }
  return puzzle;
}
