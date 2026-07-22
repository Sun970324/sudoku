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
  lockedPair,
  lockedTriple,
  xWing,
  skyscraper,
  twoStringKite,
  turbotFish,
  remotePair,
  simpleColoring,
  xyWing,
  xyzWing,
  wWing,
  swordfish,
  finnedXWing,
  sashimiXWing,
  bugPlusOne,
  xyChain,
  jellyfish,
  finnedSwordfish,
  finnedJellyfish,
  uniqueRectangleType1,
  uniqueRectangleType2,
  uniqueRectangleType3,
  uniqueRectangleType4,
  xChain,
  aic,
  groupedXChain,
  groupedAic,
  wxyzWing,
  alsXZ,
  sueDeCoq,
  tripleFirework,
  alsAic,
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
      case HintTechnique.lockedPair:
        return l10n.techniqueLockedPair;
      case HintTechnique.lockedTriple:
        return l10n.techniqueLockedTriple;
      case HintTechnique.xWing:
        return l10n.techniqueXWing;
      case HintTechnique.skyscraper:
        return l10n.techniqueSkyscraper;
      case HintTechnique.twoStringKite:
        return l10n.techniqueTwoStringKite;
      case HintTechnique.turbotFish:
        return l10n.techniqueTurbotFish;
      case HintTechnique.remotePair:
        return l10n.techniqueRemotePair;
      case HintTechnique.simpleColoring:
        return l10n.techniqueSimpleColoring;
      case HintTechnique.xyWing:
        return l10n.techniqueXYWing;
      case HintTechnique.xyzWing:
        return l10n.techniqueXYZWing;
      case HintTechnique.wWing:
        return l10n.techniqueWWing;
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
      case HintTechnique.finnedSwordfish:
        return l10n.techniqueFinnedSwordfish;
      case HintTechnique.finnedJellyfish:
        return l10n.techniqueFinnedJellyfish;
      case HintTechnique.uniqueRectangleType1:
        return l10n.techniqueUniqueRectangleType1;
      case HintTechnique.uniqueRectangleType2:
        return l10n.techniqueUniqueRectangleType2;
      case HintTechnique.uniqueRectangleType3:
        return l10n.techniqueUniqueRectangleType3;
      case HintTechnique.uniqueRectangleType4:
        return l10n.techniqueUniqueRectangleType4;
      case HintTechnique.xChain:
        return l10n.techniqueXChain;
      case HintTechnique.aic:
        return l10n.techniqueAic;
      case HintTechnique.groupedXChain:
        return l10n.techniqueGroupedXChain;
      case HintTechnique.groupedAic:
        return l10n.techniqueGroupedAic;
      case HintTechnique.wxyzWing:
        return l10n.techniqueWXYZWing;
      case HintTechnique.alsXZ:
        return l10n.techniqueAlsXZ;
      case HintTechnique.sueDeCoq:
        return l10n.techniqueSueDeCoq;
      case HintTechnique.tripleFirework:
        return l10n.techniqueTripleFirework;
      case HintTechnique.alsAic:
        return l10n.techniqueAlsAic;
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
  // AIC core is deliberately LAST: it subsumes the Turbot family / XY-Chain,
  // so it must only surface chains those earlier techniques don't report.
  // The grouped variants sit after even that — they only report chains that
  // need a group node, i.e. ones the plain finders can't see.
  HintTechnique.xChain,
  HintTechnique.aic,
  HintTechnique.groupedXChain,
  HintTechnique.groupedAic,
  // The ALS family: recognizable fixed shapes first (WXYZ-Wing is the
  // bivalue+3-cell special case of ALS-XZ, so it must come before it),
  // then the full ALS chain search last — it subsumes the others' link
  // source.
  HintTechnique.wxyzWing,
  HintTechnique.alsXZ,
  HintTechnique.sueDeCoq,
  HintTechnique.tripleFirework,
  HintTechnique.alsAic,
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
  // Same tier as the naked subsets they're built from — a Locked Pair IS a
  // naked pair, just one that happens to sit in a box/line intersection.
  HintTechnique.lockedPair: Difficulty.hard,
  HintTechnique.lockedTriple: Difficulty.hard,
  HintTechnique.nakedPair: Difficulty.hard,
  HintTechnique.hiddenPair: Difficulty.hard,
  HintTechnique.nakedTriple: Difficulty.hard,
  HintTechnique.hiddenTriple: Difficulty.hard,
  HintTechnique.xWing: Difficulty.master,
  HintTechnique.skyscraper: Difficulty.master,
  HintTechnique.twoStringKite: Difficulty.master,
  HintTechnique.turbotFish: Difficulty.master,
  HintTechnique.swordfish: Difficulty.master,
  HintTechnique.jellyfish: Difficulty.master,
  HintTechnique.xyWing: Difficulty.master,
  HintTechnique.remotePair: Difficulty.master,
  HintTechnique.xyzWing: Difficulty.master,
  HintTechnique.wWing: Difficulty.master,
  HintTechnique.nakedQuad: Difficulty.expert,
  HintTechnique.hiddenQuad: Difficulty.expert,
  HintTechnique.simpleColoring: Difficulty.expert,
  HintTechnique.finnedXWing: Difficulty.expert,
  HintTechnique.sashimiXWing: Difficulty.expert,
  HintTechnique.bugPlusOne: Difficulty.expert,
  HintTechnique.xyChain: Difficulty.expert,
  // Hint-only (absent from [humanSolverTechniqueOrder]), so this tier never
  // actually classifies a generated puzzle — but every technique needs an
  // entry here regardless, and Expert is where they'd land if they ever
  // joined generation.
  HintTechnique.finnedSwordfish: Difficulty.expert,
  HintTechnique.finnedJellyfish: Difficulty.expert,
  HintTechnique.uniqueRectangleType1: Difficulty.expert,
  HintTechnique.uniqueRectangleType2: Difficulty.expert,
  HintTechnique.uniqueRectangleType3: Difficulty.expert,
  HintTechnique.uniqueRectangleType4: Difficulty.expert,
  // Hint-only (absent from [humanSolverTechniqueOrder]); Expert is where
  // they'd sit if they ever joined generation.
  HintTechnique.xChain: Difficulty.expert,
  HintTechnique.aic: Difficulty.expert,
  HintTechnique.groupedXChain: Difficulty.expert,
  HintTechnique.groupedAic: Difficulty.expert,
  HintTechnique.wxyzWing: Difficulty.expert,
  HintTechnique.alsXZ: Difficulty.expert,
  HintTechnique.sueDeCoq: Difficulty.expert,
  HintTechnique.tripleFirework: Difficulty.expert,
  HintTechnique.alsAic: Difficulty.expert,
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

  @override
  bool operator ==(Object other) =>
      other is HintElimination &&
      other.row == row &&
      other.col == col &&
      other.digit == digit;

  @override
  int get hashCode => Object.hash(row, col, digit);
}

/// One end of a chain link: candidate [digit] within [cells]. Almost always
/// a single cell; a *grouped* node — several cells of one unit that all hold
/// the digit and act as a single link end — carries more than one, which is
/// why this is a list rather than a bare [HintCell].
///
/// Note a node is a (cells, digit) pair, not just a cell: the same cell
/// appears as two different nodes when a chain passes *through* it on two
/// different digits (an XY-Chain's bivalue cell is exactly this), and that
/// distinction is what lets the overlay attach a link to a specific pencil
/// mark instead of the cell as a whole.
class HintChainNode {
  const HintChainNode(this.cells, this.digit);

  HintChainNode.single(HintCell cell, this.digit) : cells = [cell];

  final List<HintCell> cells;
  final int digit;

  @override
  bool operator ==(Object other) =>
      other is HintChainNode &&
      other.digit == digit &&
      _listEquals(other.cells, cells);

  @override
  int get hashCode => Object.hash(digit, Object.hashAll(cells));

  static bool _listEquals(List<HintCell> a, List<HintCell> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One inference step of a chain, joining two candidate-level nodes.
///
/// A [strong] link means "if [from] is false, [to] is true" (the two are the
/// only places its digit can go in some unit, or the only two candidates of
/// one cell) and is drawn as a solid line; a weak link means "[from] and
/// [to] cannot both be true" and is drawn dashed. Chains alternate between
/// the two.
class HintChainLink {
  const HintChainLink({
    required this.from,
    required this.to,
    required this.strong,
  });

  final HintChainNode from;
  final HintChainNode to;
  final bool strong;

  @override
  bool operator ==(Object other) =>
      other is HintChainLink &&
      other.from == from &&
      other.to == to &&
      other.strong == strong;

  @override
  int get hashCode => Object.hash(from, to, strong);
}

/// One stage of a hint's step-by-step walkthrough: the sentence narrating
/// it plus the slice of the hint's visualization revealed at that point.
/// The player pages through these with prev/next buttons in the hint sheet;
/// the board only draws what the current step declares. Built by
/// `buildHintSteps` when a hint is requested for display and kept on
/// [GameController] beside the hint (never ON the [Hint] — engine results
/// stay identical to what find* returned); a hint without steps is simply
/// drawn all at once, as before.
class HintStep {
  const HintStep({
    required this.text,
    this.cells = const {},
    this.rows = const {},
    this.cols = const {},
    this.boxes = const {},
    this.visibleLinks = 0,
    this.emphasisNodes = const [],
    this.showConclusion = false,
  });

  /// The one-line narration shown in the hint sheet for this step.
  final String text;

  /// Cells whose hint note-coloring (green / color group) is active during
  /// this step — a subset of the hint's own primary/color cells, so the
  /// walkthrough can introduce them one group at a time.
  final Set<HintCell> cells;

  /// Unit outlines drawn during this step (same indexing as
  /// [Hint.highlightedRows] and friends).
  final Set<int> rows;
  final Set<int> cols;
  final Set<int> boxes;

  /// How many of [Hint.chainLinks] (as a prefix) are drawn during this
  /// step. Link lists are ordered so that every step's visible set IS a
  /// prefix — branches that appear together are stored adjacently.
  final int visibleLinks;

  /// Candidates given an extra-bold ring this step — the "look here now"
  /// marker (e.g. the wing digit a case just forced).
  final List<HintChainNode> emphasisNodes;

  /// Whether the hint's conclusion visuals are shown: the red to-be-removed
  /// notes and convergence connectors of an eliminate hint, or the filled
  /// target cell of a reveal hint. Typically only the final step.
  final bool showConclusion;
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
    this.mainInfo,
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
    this.chainLinks = const [],
    this.elimSources,
    this.digitGroups = const [],
  });

  final HintTechnique technique;
  final HintType type;
  final String explanation;
  final Set<HintCell> primaryCells;
  final Set<HintCell> secondaryCells;

  /// A short "where" phrase (e.g. the unit the reasoning is confined to, or
  /// the digits involved) shown at the middle stage of the progressive hint
  /// reveal — between the bare technique name and the full [explanation].
  /// Null for techniques that have no useful summary short of the full
  /// sentence, in which case that stage is skipped.
  final String? mainInfo;

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

  /// For chain techniques only (XY-Chain, Skyscraper/2-String Kite/Turbot
  /// Fish): the chain's inference steps in the order they were followed, so
  /// the hint overlay can trace it link by link. Empty for every other
  /// technique — [primaryCells]/[colorGroupA]/[colorGroupB] are unordered
  /// sets, which is enough for those, but a chain's shape needs the order and
  /// the strong/weak alternation, which those sets don't preserve.
  ///
  /// Consecutive links share a node: `chainLinks[i].to == chainLinks[i+1]
  /// .from`. The chain's two ends — the nodes whose digit gets eliminated
  /// wherever both are seen — are `chainLinks.first.from` and
  /// `chainLinks.last.to`.
  final List<HintChainLink> chainLinks;

  /// The nodes the overlay draws its faint "convergence" connectors from —
  /// each one dashes toward every eliminated candidate its cells see, showing
  /// WHY that candidate dies. Null (the default) means "derive them from the
  /// chain": a linear chain's two ends, `chainLinks.first.from` and
  /// `chainLinks.last.to`. Set explicitly when that derivation is wrong:
  /// XYZ-Wing has THREE sources (both wings' z plus the pivot's own z),
  /// X-Wing's are its four corners, and Simple Coloring Rule 1 sets `[]` to
  /// draw none at all (its eliminations land ON the source cells themselves).
  final List<HintChainNode>? elimSources;

  /// Per-cluster candidate sets, for techniques whose walkthrough counts
  /// candidates against cells. Sue de Coq (the only user today) stores
  /// `[V, D, E]` — the crossing cells' union, the line ALS's digits, and
  /// the box ALS's digits, matching [primaryCells]/[colorGroupA]/
  /// [colorGroupB] in that order. Empty for every other technique.
  final List<Set<int>> digitGroups;

  /// The hint's conclusion in standard sudoku notation, shown alongside the
  /// full [explanation] at the last stage of the progressive reveal: a reveal
  /// is `r4c7 = 5`, an elimination is `r4c258<>7` per digit (cells sharing a
  /// row collapse into one column run, likewise for a column), joined by
  /// `, ` across digits.
  String get actionSummary {
    if (type == HintType.reveal) {
      return 'r${row! + 1}c${col! + 1} = $value';
    }
    final byDigit = <int, List<HintCell>>{};
    for (final e in eliminations) {
      byDigit.putIfAbsent(e.digit, () => []).add(HintCell(e.row, e.col));
    }
    final groups = <String>[];
    for (final digit in byDigit.keys.toList()..sort()) {
      final cells = byDigit[digit]!
        ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
      groups.add('${_compactCells(cells)}<>$digit');
    }
    return groups.join(', ');
  }

  /// `r4c258` when every cell shares a row, `r258c4` when they share a
  /// column, else one `rXcYZ` run per row joined by `,`.
  static String _compactCells(List<HintCell> cells) {
    if (cells.every((c) => c.row == cells.first.row)) {
      final cols = cells.map((c) => c.col + 1).join();
      return 'r${cells.first.row + 1}c$cols';
    }
    if (cells.every((c) => c.col == cells.first.col)) {
      final rows = cells.map((c) => c.row + 1).join();
      return 'r${rows}c${cells.first.col + 1}';
    }
    final byRow = <int, List<int>>{};
    for (final c in cells) {
      byRow.putIfAbsent(c.row, () => []).add(c.col);
    }
    return byRow.entries
        .map((e) => 'r${e.key + 1}c${e.value.map((c) => c + 1).join()}')
        .join(',');
  }

  /// A copy with [explanation] replaced — used to prepend a note about
  /// notes having been auto-corrected before this hint was found (see
  /// [GameController.requestHint]) without needing a full field-by-field
  /// copyWith for every other property.
  Hint withExplanation(String explanation) => Hint(
        technique: technique,
        type: type,
        explanation: explanation,
        primaryCells: primaryCells,
        mainInfo: mainInfo,
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
        chainLinks: chainLinks,
        elimSources: elimSources,
        digitGroups: digitGroups,
      );
}
