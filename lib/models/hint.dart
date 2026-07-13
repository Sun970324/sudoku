import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import 'difficulty.dart';

enum HintTechnique {
  fullHouse,
  nakedSingle,
  hiddenSingle,
  nakedPair,
  nakedTriple,
  nakedQuad,
  hiddenPair,
  hiddenTriple,
  hiddenQuad,
  intersectionPointing,
  intersectionClaiming,
  xWing,
  simpleColoring,
  xyWing,
  swordfish,
  finnedXWing,
  sashimiXWing,
  bugPlusOne,
  xyChain,
  jellyfish,
  uniqueRectangleType1,
  uniqueRectangleType2,
  uniqueRectangleType3,
  uniqueRectangleType4,
}

extension HintTechniqueInfo on HintTechnique {
  /// Requires a [BuildContext] since the display name is localized — see
  /// [AppLocalizations]. Note this is only the technique's *name*; the
  /// per-hint [Hint.explanation] sentence is generated deep in the solver
  /// (see `hint_engine.dart` and its part files) and is not yet localized.
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case HintTechnique.fullHouse:
        return l10n.techniqueFullHouse;
      case HintTechnique.nakedSingle:
        return l10n.techniqueNakedSingle;
      case HintTechnique.hiddenSingle:
        return l10n.techniqueHiddenSingle;
      case HintTechnique.nakedPair:
        return l10n.techniqueNakedPair;
      case HintTechnique.nakedTriple:
        return l10n.techniqueNakedTriple;
      case HintTechnique.nakedQuad:
        return l10n.techniqueNakedQuad;
      case HintTechnique.hiddenPair:
        return l10n.techniqueHiddenPair;
      case HintTechnique.hiddenTriple:
        return l10n.techniqueHiddenTriple;
      case HintTechnique.hiddenQuad:
        return l10n.techniqueHiddenQuad;
      case HintTechnique.intersectionPointing:
        return l10n.techniqueIntersectionPointing;
      case HintTechnique.intersectionClaiming:
        return l10n.techniqueIntersectionClaiming;
      case HintTechnique.xWing:
        return l10n.techniqueXWing;
      case HintTechnique.simpleColoring:
        return l10n.techniqueSimpleColoring;
      case HintTechnique.xyWing:
        return l10n.techniqueXYWing;
      case HintTechnique.swordfish:
        return l10n.techniqueSwordfish;
      case HintTechnique.finnedXWing:
        return l10n.techniqueFinnedXWing;
      case HintTechnique.sashimiXWing:
        return l10n.techniqueSashimiXWing;
      case HintTechnique.bugPlusOne:
        return l10n.techniqueBugPlusOne;
      case HintTechnique.xyChain:
        return l10n.techniqueXYChain;
      case HintTechnique.jellyfish:
        return l10n.techniqueJellyfish;
      case HintTechnique.uniqueRectangleType1:
        return l10n.techniqueUniqueRectangleType1;
      case HintTechnique.uniqueRectangleType2:
        return l10n.techniqueUniqueRectangleType2;
      case HintTechnique.uniqueRectangleType3:
        return l10n.techniqueUniqueRectangleType3;
      case HintTechnique.uniqueRectangleType4:
        return l10n.techniqueUniqueRectangleType4;
    }
  }
}

/// Fixed order the hint engine tries techniques in, from easiest to
/// hardest to spot as a human solver. This is the order the app's own
/// roadmap was built and requested in, not necessarily the exact ordering
/// other solver guides use (e.g. Naked/Hidden Pair/Triple are often rated
/// easier than X-Wing elsewhere, but are deliberately tried after it here).
const hintTechniqueOrder = [
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
  HintTechnique.bugPlusOne,
  HintTechnique.xyChain,
  HintTechnique.jellyfish,
  HintTechnique.uniqueRectangleType1,
  HintTechnique.uniqueRectangleType2,
  HintTechnique.uniqueRectangleType3,
  HintTechnique.uniqueRectangleType4,
];

/// Which [Difficulty] tier each technique belongs to, per generator.md's
/// classification. This is the single place a technique's tier is
/// declared — [DifficultyEvaluator] and [SudokuGenerator] both read from
/// this map and never hard-code a technique→tier association themselves,
/// so adding a new technique here (plus its `find*` in [HintEngine] and its
/// slot in [humanSolverTechniqueOrder]) is enough to make it flow through
/// generation without touching either module's logic.
const techniqueDifficulty = <HintTechnique, Difficulty>{
  HintTechnique.fullHouse: Difficulty.easy,
  HintTechnique.nakedSingle: Difficulty.easy,
  HintTechnique.hiddenSingle: Difficulty.medium,
  HintTechnique.intersectionPointing: Difficulty.medium,
  HintTechnique.intersectionClaiming: Difficulty.medium,
  HintTechnique.nakedPair: Difficulty.hard,
  HintTechnique.hiddenPair: Difficulty.hard,
  HintTechnique.nakedTriple: Difficulty.hard,
  HintTechnique.hiddenTriple: Difficulty.hard,
  HintTechnique.xWing: Difficulty.master,
  HintTechnique.swordfish: Difficulty.master,
  HintTechnique.jellyfish: Difficulty.master,
  HintTechnique.xyWing: Difficulty.master,
  HintTechnique.nakedQuad: Difficulty.expert,
  HintTechnique.hiddenQuad: Difficulty.expert,
  HintTechnique.simpleColoring: Difficulty.expert,
  HintTechnique.finnedXWing: Difficulty.expert,
  HintTechnique.sashimiXWing: Difficulty.expert,
  HintTechnique.bugPlusOne: Difficulty.expert,
  HintTechnique.xyChain: Difficulty.expert,
  HintTechnique.uniqueRectangleType1: Difficulty.expert,
  HintTechnique.uniqueRectangleType2: Difficulty.expert,
  HintTechnique.uniqueRectangleType3: Difficulty.expert,
  HintTechnique.uniqueRectangleType4: Difficulty.expert,
};

enum HintType { reveal, eliminate }

class HintCell {
  const HintCell(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is HintCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class HintElimination {
  const HintElimination(this.row, this.col, this.digit);

  final int row;
  final int col;
  final int digit;
}

/// A single hint found by [HintEngine]. Reveal-type hints (Full House,
/// Naked Single, Hidden Single) point at one cell with a definite answer
/// via [row]/[col]/[value]. Eliminate-type hints (Naked/Hidden
/// Pair/Triple/Quad, Intersection Pointing/Claiming, X-Wing, Simple
/// Coloring, XY-Wing, Swordfish, Finned/Sashimi X-Wing, XY-Chain,
/// Jellyfish, Unique Rectangle Type 1-4) instead carry a list of candidate
/// digits that can be removed from specific cells' notes via
/// [eliminations].
class Hint {
  const Hint({
    required this.technique,
    required this.type,
    required this.explanation,
    required this.primaryCells,
    this.secondaryCells = const {},
    this.colorGroupA = const {},
    this.colorGroupB = const {},
    this.highlightedRows = const {},
    this.highlightedCols = const {},
    this.highlightedBoxes = const {},
    this.primaryDigits = const {},
    this.row,
    this.col,
    this.value,
    this.eliminations = const [],
  });

  final HintTechnique technique;
  final HintType type;
  final String explanation;
  final Set<HintCell> primaryCells;
  final Set<HintCell> secondaryCells;

  /// For Simple Coloring / XY-Chain only: the two "opposite state" groups
  /// of the coloring/chain pattern (the two sides of a conjugate-chain
  /// 2-coloring, or the alternating links of an XY-Chain path). Empty for
  /// every other technique, which has no such bipartition. A/B is an
  /// arbitrary label, not a semantic distinction — unlike primary/secondary
  /// there is no "cause vs effect" meaning here, just "the two sides."
  final Set<HintCell> colorGroupA;
  final Set<HintCell> colorGroupB;

  /// For unit-confined techniques (Full House, Hidden Single, Naked/Hidden
  /// Pair/Triple/Quad, Intersection Pointing/Claiming, X-Wing, Swordfish,
  /// Jellyfish, Finned/Sashimi X-Wing, Unique Rectangle Type 1-4): the
  /// specific row/column/box index (or indices) the reasoning is confined
  /// to, so the board can draw an emphasized border around them. Empty for
  /// techniques that reason about cell-to-cell relationships instead of a
  /// whole unit (Naked Single, Simple Coloring, XY-Wing, XY-Chain). Row/col
  /// indices are 0-8; box indices are 0-8 as `boxRow * 3 + boxCol`.
  final Set<int> highlightedRows;
  final Set<int> highlightedCols;
  final Set<int> highlightedBoxes;

  /// Extra digits (beyond [eliminations]' own digits) to highlight
  /// wherever they appear as notes within [primaryCells] (or within
  /// [colorGroupA]/[colorGroupB], for techniques that use those instead).
  /// Needed whenever a primary cell's own meaningful candidates aren't
  /// simply "whatever gets eliminated" — XY-Wing's pivot cell (its {x, y}
  /// aren't eliminated anywhere, but they're exactly why the technique
  /// works), Naked/Hidden Pair/Triple/Quad (the group's own shared digit
  /// set — Hidden subsets eliminate OTHER candidates FROM the group cells,
  /// so [eliminations] alone would highlight the wrong digits there), and
  /// XY-Chain (every digit along the chain, not just the one digit being
  /// eliminated at the far end). Empty for techniques where [eliminations]
  /// already names every digit worth highlighting.
  final Set<int> primaryDigits;

  final int? row;
  final int? col;
  final int? value;

  final List<HintElimination> eliminations;

  /// A copy with [explanation] replaced — used to prepend a note about
  /// notes having been auto-corrected before this hint was found (see
  /// [GameController.requestHint]) without needing a full field-by-field
  /// copyWith for every other property.
  Hint withExplanation(String explanation) => Hint(
        technique: technique,
        type: type,
        explanation: explanation,
        primaryCells: primaryCells,
        secondaryCells: secondaryCells,
        colorGroupA: colorGroupA,
        colorGroupB: colorGroupB,
        highlightedRows: highlightedRows,
        highlightedCols: highlightedCols,
        highlightedBoxes: highlightedBoxes,
        primaryDigits: primaryDigits,
        row: row,
        col: col,
        value: value,
        eliminations: eliminations,
      );
}
