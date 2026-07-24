import '../l10n/generated/app_localizations.dart';
import '../models/hint.dart';

/// Builds the step-by-step walkthrough for [hint] — the [HintStep] list the
/// hint sheet pages through with prev/next (see `GameScreen`). Everything is
/// derived from the hint's own visualization fields: chain techniques read
/// their actors (pivot, wings, bridge, path...) out of the links' fixed
/// per-technique order, the rest work from the highlighted units and cells
/// — so no engine changes are needed here.
///
/// Chain techniques narrate link by link; the non-chain families get a
/// two-step "where to look" → conclusion shape whose final text is the
/// hint's own [Hint.explanation]. Each list ends with a conclusion step
/// whose [HintStep.showConclusion] is true — the full visualization the
/// pre-step UI always showed.
List<HintStep> buildHintSteps(Hint hint, AppLocalizations l10n) {
  // Chain techniques index into chainLinks positionally; a hand-built hint
  // without links (test fakes) simply gets no walkthrough.
  const chainTechniques = {
    HintTechnique.xyWing,
    HintTechnique.xyzWing,
    HintTechnique.wWing,
    HintTechnique.xyChain,
    HintTechnique.remotePair,
    HintTechnique.skyscraper,
    HintTechnique.twoStringKite,
    HintTechnique.turbotFish,
    HintTechnique.simpleColoring,
    HintTechnique.xWing,
    HintTechnique.xChain,
    HintTechnique.aic,
    HintTechnique.groupedXChain,
    HintTechnique.groupedAic,
    HintTechnique.wxyzWing,
    HintTechnique.alsXZ,
    HintTechnique.alsAic,
  };
  if (chainTechniques.contains(hint.technique) && hint.chainLinks.isEmpty) {
    return const [];
  }
  return switch (hint.technique) {
    HintTechnique.xyWing => _xyWingSteps(hint, l10n),
    HintTechnique.xyzWing => _xyzWingSteps(hint, l10n),
    HintTechnique.wWing => _wWingSteps(hint, l10n),
    HintTechnique.xyChain => _xyChainSteps(hint, l10n),
    HintTechnique.xChain ||
    HintTechnique.aic ||
    HintTechnique.groupedXChain ||
    HintTechnique.groupedAic ||
    HintTechnique.wxyzWing ||
    HintTechnique.alsXZ ||
    HintTechnique.alsAic =>
      _aicSteps(hint, l10n),
    HintTechnique.remotePair => _remotePairSteps(hint, l10n),
    HintTechnique.skyscraper ||
    HintTechnique.twoStringKite ||
    HintTechnique.turbotFish =>
      _singleDigitChainSteps(hint, l10n),
    HintTechnique.simpleColoring ||
    HintTechnique.multiColoring =>
      _simpleColoringSteps(hint, l10n),
    HintTechnique.xWing => _xWingSteps(hint, l10n),
    // The per-family guards below mirror the chain guard above: a
    // hand-built hint missing the fields a family reads (test fakes) gets
    // no walkthrough instead of a crash.
    HintTechnique.fullHouse => _hasUnit(hint)
        ? _revealSteps(
            hint, l10n.hintStepFullHouseIntro(_unitDesc(hint, l10n)))
        : const [],
    HintTechnique.nakedSingle => hint.primaryCells.isEmpty
        ? const []
        : _revealSteps(
            hint,
            l10n.hintStepNakedSingleIntro(
                _cellDesc(hint.primaryCells.first, l10n))),
    HintTechnique.hiddenSingle => hint.value == null
        ? const []
        : _revealSteps(hint, l10n.hintStepHiddenSingleIntro(hint.value!)),
    HintTechnique.bugPlusOne => _revealSteps(hint, l10n.hintStepBugIntro),
    HintTechnique.nakedPair ||
    HintTechnique.nakedTriple ||
    HintTechnique.nakedQuad ||
    HintTechnique.lockedPair ||
    HintTechnique.lockedTriple =>
      _subsetSteps(hint, l10n, hidden: false),
    HintTechnique.hiddenPair ||
    HintTechnique.hiddenTriple ||
    HintTechnique.hiddenQuad =>
      _subsetSteps(hint, l10n, hidden: true),
    HintTechnique.intersectionPointing ||
    HintTechnique.intersectionClaiming =>
      _intersectionSteps(hint, l10n),
    HintTechnique.swordfish ||
    HintTechnique.jellyfish ||
    HintTechnique.finnedXWing ||
    HintTechnique.sashimiXWing ||
    HintTechnique.finnedSwordfish ||
    HintTechnique.finnedJellyfish =>
      _fishSteps(hint, l10n),
    HintTechnique.uniqueRectangleType1 ||
    HintTechnique.uniqueRectangleType2 ||
    HintTechnique.uniqueRectangleType3 ||
    HintTechnique.uniqueRectangleType4 =>
      _urSteps(hint, l10n),
    HintTechnique.sueDeCoq => hint.colorGroupA.isEmpty ||
            hint.colorGroupB.isEmpty ||
            hint.digitGroups.length != 3
        ? const []
        : _sueDeCoqSteps(hint, l10n),
    HintTechnique.tripleFirework => hint.highlightedRows.isEmpty ||
            hint.highlightedCols.isEmpty ||
            hint.primaryCells.length != 3
        ? const []
        : _fireworkSteps(hint, l10n),
  };
}

String _cellDesc(HintCell cell, AppLocalizations l10n) =>
    l10n.unitCell(cell.row + 1, cell.col + 1);

HintCell _fromCell(HintChainLink link) => link.from.cells.first;
HintCell _toCell(HintChainLink link) => link.to.cells.first;

/// Links: (w1,z)=(w1,x) ~ (pivot,x) = (pivot,y) ~ (w2,y) = (w2,z).
List<HintStep> _xyWingSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final pivot = _fromCell(links[2]);
  final x = links[2].from.digit;
  final y = links[2].to.digit;
  final w1 = _fromCell(links[0]);
  final w2 = _toCell(links[4]);
  final z = links[0].from.digit;
  final pivotDesc = _cellDesc(pivot, l10n);

  final sorted = [x, y]..sort();
  return [
    HintStep(
      text: l10n.hintStepXYWingPivot(pivotDesc, sorted[0], sorted[1]),
      cells: {pivot},
      emphasisNodes: [
        HintChainNode.single(pivot, x),
        HintChainNode.single(pivot, y),
      ],
    ),
    HintStep(
      text: l10n.hintStepWingCase(x, _cellDesc(w1, l10n), z),
      cells: {pivot, w1},
      visibleLinks: 2,
      emphasisNodes: [HintChainNode.single(w1, z)],
    ),
    HintStep(
      text: l10n.hintStepWingCase(y, _cellDesc(w2, l10n), z),
      cells: {pivot, w1, w2},
      visibleLinks: 5,
      emphasisNodes: [HintChainNode.single(w2, z)],
    ),
    HintStep(
      text: l10n.hintStepXYWingConclusion(z),
      cells: hint.primaryCells,
      visibleLinks: 5,
      emphasisNodes: [
        HintChainNode.single(w1, z),
        HintChainNode.single(w2, z),
      ],
      showConclusion: true,
    ),
  ];
}

/// Links: (w1,z)=(w1,x) ~ (pivot,x), (pivot,y) ~ (w2,y)=(w2,z) — two
/// branches, no in-pivot link. The pivot's own z is the third case.
List<HintStep> _xyzWingSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final pivot = _toCell(links[1]);
  final x = links[1].to.digit;
  final y = links[2].from.digit;
  final w1 = _fromCell(links[0]);
  final w2 = _toCell(links[3]);
  final z = links[0].from.digit;
  final digits = (hint.primaryDigits.toList()..sort()).join(', ');

  return [
    HintStep(
      text: l10n.hintStepXYZWingPivot(_cellDesc(pivot, l10n), digits),
      cells: {pivot},
      emphasisNodes: [
        for (final d in hint.primaryDigits.toList()..sort())
          HintChainNode.single(pivot, d),
      ],
    ),
    HintStep(
      text: l10n.hintStepWingCase(x, _cellDesc(w1, l10n), z),
      cells: {pivot, w1},
      visibleLinks: 2,
      emphasisNodes: [HintChainNode.single(w1, z)],
    ),
    HintStep(
      text: l10n.hintStepWingCase(y, _cellDesc(w2, l10n), z),
      cells: {pivot, w1, w2},
      visibleLinks: 4,
      emphasisNodes: [HintChainNode.single(w2, z)],
    ),
    HintStep(
      text: l10n.hintStepXYZWingPivotZ(z),
      cells: {pivot, w1, w2},
      visibleLinks: 4,
      emphasisNodes: [HintChainNode.single(pivot, z)],
    ),
    HintStep(
      text: l10n.hintStepXYZWingConclusion(z),
      cells: hint.primaryCells,
      visibleLinks: 4,
      emphasisNodes: [
        HintChainNode.single(w1, z),
        HintChainNode.single(w2, z),
        HintChainNode.single(pivot, z),
      ],
      showConclusion: true,
    ),
  ];
}

/// Links: (p1,a)=(p1,b) ~ (e1,b) = (e2,b) ~ (p2,b)=(p2,a).
List<HintStep> _wWingSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final p1 = _fromCell(links[0]);
  final a = links[0].from.digit;
  final b = links[0].to.digit;
  final e1 = _fromCell(links[2]);
  final e2 = _toCell(links[2]);
  final p2 = _toCell(links[4]);

  final unitDesc = _unitDesc(hint, l10n);
  return [
    HintStep(
      text: l10n.hintStepWWingPair(
          _cellDesc(p1, l10n), _cellDesc(p2, l10n), a, b),
      cells: {p1, p2},
      emphasisNodes: [
        HintChainNode.single(p1, a),
        HintChainNode.single(p1, b),
        HintChainNode.single(p2, a),
        HintChainNode.single(p2, b),
      ],
    ),
    HintStep(
      text: l10n.hintStepWWingBridge(unitDesc, b),
      cells: {p1, p2, e1, e2},
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      boxes: hint.highlightedBoxes,
      visibleLinks: 3,
      emphasisNodes: [
        HintChainNode.single(e1, b),
        HintChainNode.single(e2, b),
      ],
    ),
    HintStep(
      text: l10n.hintStepWWingForced(unitDesc, a, b),
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      boxes: hint.highlightedBoxes,
      visibleLinks: 5,
      emphasisNodes: [
        HintChainNode.single(p1, a),
        HintChainNode.single(p2, a),
      ],
    ),
    HintStep(
      text: l10n.hintStepWWingConclusion(a),
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      boxes: hint.highlightedBoxes,
      visibleLinks: 5,
      showConclusion: true,
    ),
  ];
}

bool _hasUnit(Hint hint) =>
    hint.highlightedRows.isNotEmpty ||
    hint.highlightedCols.isNotEmpty ||
    hint.highlightedBoxes.isNotEmpty;

/// The localized description of the single unit a hint highlights — used
/// where exactly one unit is ever set (W-Wing's bridge, Full House's unit).
String _unitDesc(Hint hint, AppLocalizations l10n) {
  if (hint.highlightedRows.isNotEmpty) {
    return l10n.unitRow(hint.highlightedRows.first + 1);
  }
  if (hint.highlightedCols.isNotEmpty) {
    return l10n.unitCol(hint.highlightedCols.first + 1);
  }
  return _boxDesc(hint.highlightedBoxes.first, l10n);
}

String _boxDesc(int box, AppLocalizations l10n) {
  final boxRow = box ~/ 3;
  final boxCol = box % 3;
  return l10n.unitBox(box + 1, boxRow * 3 + 1, boxRow * 3 + 3, boxCol * 3 + 1,
      boxCol * 3 + 3);
}

/// Every highlighted unit, joined — a locked subset outlines its line AND
/// its box, everything else one unit.
String _unitsDesc(Hint hint, AppLocalizations l10n) => [
      for (final r in hint.highlightedRows.toList()..sort())
        l10n.unitRow(r + 1),
      for (final c in hint.highlightedCols.toList()..sort())
        l10n.unitCol(c + 1),
      for (final b in hint.highlightedBoxes.toList()..sort())
        _boxDesc(b, l10n),
    ].join(', ');

/// Links alternate in-cell strong / between-cell weak, starting and ending
/// with a strong: cell i's in-cell link sits at index 2i, the weak hop into
/// cell i+1 at index 2i+1.
List<HintStep> _xyChainSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final start = _fromCell(links[0]);
  final z = links[0].from.digit;
  final a = links[0].to.digit;
  final cellCount = (links.length + 1) ~/ 2;

  final steps = <HintStep>[
    HintStep(
      text: l10n.hintStepChainStart(_cellDesc(start, l10n), z, a),
      cells: {start},
      visibleLinks: 1,
      emphasisNodes: [HintChainNode.single(start, a)],
    ),
  ];

  final shown = <HintCell>{start};
  for (var i = 1; i < cellCount; i++) {
    final strong = links[2 * i];
    final cell = _fromCell(strong);
    final carry = strong.from.digit;
    final next = strong.to.digit;
    shown.add(cell);
    steps.add(HintStep(
      text: l10n.hintStepChainHop(_cellDesc(cell, l10n), carry, next),
      cells: {...shown},
      visibleLinks: 2 * i + 1,
      emphasisNodes: [HintChainNode.single(cell, next)],
    ));
  }

  final end = _toCell(links.last);
  steps.add(HintStep(
    text: l10n.hintStepChainConclusion(z),
    cells: hint.primaryCells,
    visibleLinks: links.length,
    emphasisNodes: [
      HintChainNode.single(start, z),
      HintChainNode.single(end, z),
    ],
    showConclusion: true,
  ));
  return steps;
}

/// X-Chain / general AIC, narrated hop by hop. Each link's wording is
/// picked from its geometry (in-cell, single target, or multi-cell set
/// target) but states only what happens — the strong/weak-link theory
/// behind it is deliberately not spelled out (it made every step twice as
/// long; removed on request).
///
/// The walkthrough runs the "suppose the start is false" direction: each
/// step consumes one weak+strong pair (the assumption propagating one hop),
/// then an either-ends step flips the assumption, then the conclusion.
List<HintStep> _aicSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;

  // A grouped node (several candidates acting as one link) is described by
  // listing its cells, and gets the "one of the cluster" strong wording —
  // the weak wording already reads correctly for every cell of a group.
  String nodeDesc(HintChainNode node) =>
      node.cells.map((c) => _cellDesc(c, l10n)).join('·');

  String strongText(HintChainLink link) {
    if (link.to.cells.length > 1) {
      return l10n.hintStepAicStrongGroup(nodeDesc(link.to), link.to.digit);
    }
    return link.from.cells.length == 1 &&
            link.from.cells.first == link.to.cells.first
        ? l10n.hintStepAicStrongCell(link.to.digit)
        : l10n.hintStepAicStrongUnit(nodeDesc(link.to), link.to.digit);
  }

  String weakText(HintChainLink link) =>
      link.from.cells.length == 1 &&
              link.from.cells.first == link.to.cells.first
          ? l10n.hintStepAicWeakCell(link.to.digit)
          : l10n.hintStepAicWeakUnit(nodeDesc(link.to), link.to.digit);

  final start = links.first.from;
  final shown = <HintCell>{...start.cells, ...links.first.to.cells};

  final startText = start.cells.length > 1
      ? l10n.hintStepAicStartGroup(nodeDesc(start), start.digit)
      : l10n.hintStepAicStart(nodeDesc(start), start.digit);
  final steps = <HintStep>[
    // "Suppose the start is not its digit" + the first strong link firing.
    HintStep(
      text: '$startText ${strongText(links.first)}',
      cells: {...shown},
      visibleLinks: 1,
      emphasisNodes: [links.first.to],
    ),
  ];

  // Each weak+strong pair propagates the assumption one hop further.
  for (var j = 1; j + 1 < links.length; j += 2) {
    shown.addAll(links[j].to.cells);
    shown.addAll(links[j + 1].to.cells);
    steps.add(HintStep(
      text: '${weakText(links[j])} ${strongText(links[j + 1])}',
      cells: {...shown},
      visibleLinks: j + 2,
      emphasisNodes: [links[j + 1].to],
    ));
  }

  final ends = [links.first.from, links.last.to];
  steps.add(HintStep(
    text: l10n.hintStepAicEitherEnds(
      nodeDesc(ends[0]),
      ends[0].digit,
      nodeDesc(ends[1]),
      ends[1].digit,
    ),
    cells: hint.primaryCells,
    visibleLinks: links.length,
    emphasisNodes: ends,
  ));
  steps.add(HintStep(
    text: l10n.hintStepAicConclusion,
    cells: hint.primaryCells,
    visibleLinks: links.length,
    emphasisNodes: ends,
    showConclusion: true,
  ));
  return steps;
}

/// Same link layout as an XY-Chain, but the narrative leans on the shared
/// pair and the alternation instead of walking every hop.
List<HintStep> _remotePairSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final start = _fromCell(links[0]);
  final a = links[0].from.digit;
  final b = links[0].to.digit;
  final end = _toCell(links.last);

  return [
    HintStep(
      text: l10n.hintStepRemotePairIntro(a, b),
      cells: hint.primaryCells,
    ),
    HintStep(
      text: l10n.hintStepRemotePairAlternate(a, b),
      cells: hint.primaryCells,
      visibleLinks: links.length,
    ),
    HintStep(
      text: l10n.hintStepRemotePairEnds(a, b),
      cells: hint.primaryCells,
      visibleLinks: links.length,
      emphasisNodes: [
        HintChainNode.single(start, a),
        HintChainNode.single(start, b),
        HintChainNode.single(end, a),
        HintChainNode.single(end, b),
      ],
    ),
    HintStep(
      text: l10n.hintStepRemotePairConclusion(a, b),
      cells: hint.primaryCells,
      visibleLinks: links.length,
      showConclusion: true,
    ),
  ];
}

/// Links: (f1)=(p1) ~ (p2) = (f2), one digit throughout.
List<HintStep> _singleDigitChainSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final f1 = _fromCell(links[0]);
  final p1 = _toCell(links[0]);
  final p2 = _fromCell(links[2]);
  final f2 = _toCell(links[2]);
  final d = links[0].from.digit;

  HintStep step(String text, Set<HintCell> cells, int visibleLinks,
          List<HintChainNode> emphasis,
          {bool showConclusion = false}) =>
      HintStep(
        text: text,
        cells: cells,
        rows: hint.highlightedRows,
        cols: hint.highlightedCols,
        boxes: hint.highlightedBoxes,
        visibleLinks: visibleLinks,
        emphasisNodes: emphasis,
        showConclusion: showConclusion,
      );

  return [
    step(
      l10n.hintStepSingleDigitStrong1(
          d, _cellDesc(f1, l10n), _cellDesc(p1, l10n)),
      {f1, p1},
      1,
      [HintChainNode.single(f1, d), HintChainNode.single(p1, d)],
    ),
    step(
      l10n.hintStepSingleDigitStrong2(
          d, _cellDesc(p2, l10n), _cellDesc(f2, l10n)),
      hint.primaryCells,
      3,
      [HintChainNode.single(p1, d), HintChainNode.single(p2, d)],
    ),
    step(
      l10n.hintStepSingleDigitForced(
          d, _cellDesc(f1, l10n), _cellDesc(f2, l10n)),
      hint.primaryCells,
      3,
      [HintChainNode.single(f1, d), HintChainNode.single(f2, d)],
    ),
    step(
      l10n.hintStepSingleDigitConclusion(d),
      hint.primaryCells,
      3,
      const [],
      showConclusion: true,
    ),
  ];
}

/// Rule 1 carries the conjugate edges plus a final weak "clash" link and
/// suppresses convergence sources; Rule 2 is edges only with sources — that
/// difference (empty vs non-empty [Hint.elimSources]) tells them apart.
List<HintStep> _simpleColoringSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final d = links.first.from.digit;
  final allCells = {...hint.colorGroupA, ...hint.colorGroupB};
  final isRule1 = (hint.elimSources ?? const []).isEmpty;

  if (!isRule1) {
    return [
      HintStep(
        text: l10n.hintStepColoringChain(d),
        cells: allCells,
        visibleLinks: links.length,
      ),
      HintStep(
        text: l10n.hintStepColoringRule2Conclusion(d),
        cells: allCells,
        visibleLinks: links.length,
        showConclusion: true,
      ),
    ];
  }

  final clash = links.last;
  return [
    HintStep(
      text: l10n.hintStepColoringChain(d),
      cells: allCells,
      visibleLinks: links.length - 1,
    ),
    HintStep(
      text: l10n.hintStepColoringRule1Clash(
        d,
        _cellDesc(_fromCell(clash), l10n),
        _cellDesc(_toCell(clash), l10n),
      ),
      cells: allCells,
      visibleLinks: links.length,
      emphasisNodes: [clash.from, clash.to],
    ),
    HintStep(
      text: l10n.hintStepColoringRule1Conclusion(d),
      cells: allCells,
      visibleLinks: links.length,
      showConclusion: true,
    ),
  ];
}

/// Links: the two strong rails along the base lines (rows when each rail's
/// cells share a row, else columns).
List<HintStep> _xWingSteps(Hint hint, AppLocalizations l10n) {
  final links = hint.chainLinks;
  final d = links.first.from.digit;
  final rowBased =
      _fromCell(links.first).row == _toCell(links.first).row;

  final rows = hint.highlightedRows.toList()..sort();
  final cols = hint.highlightedCols.toList()..sort();
  final rowsDesc = rows.map((r) => l10n.unitRow(r + 1)).join(', ');
  final colsDesc = cols.map((c) => l10n.unitCol(c + 1)).join(', ');
  final linesDesc = rowBased ? rowsDesc : colsDesc;
  final crossDesc = rowBased ? colsDesc : rowsDesc;
  final crossUnitName = rowBased ? l10n.wordColumns : l10n.wordRows;

  final cornerNodes = [
    for (final cell in hint.primaryCells) HintChainNode.single(cell, d),
  ];
  return [
    HintStep(
      text: l10n.hintStepXWingLines(d, linesDesc),
      cells: hint.primaryCells,
      rows: rowBased ? hint.highlightedRows : const {},
      cols: rowBased ? const {} : hint.highlightedCols,
      visibleLinks: 2,
      emphasisNodes: cornerNodes,
    ),
    HintStep(
      text: l10n.hintStepXWingRect(d, crossDesc),
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      visibleLinks: 2,
      emphasisNodes: cornerNodes,
    ),
    HintStep(
      text: l10n.hintStepXWingConclusion(d, crossUnitName),
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      visibleLinks: 2,
      showConclusion: true,
    ),
  ];
}

/// Reveal-type walkthrough (Full House / Naked Single / Hidden Single /
/// BUG+1): the "where to look" [intro] with the reason cells first, then
/// the hint's own explanation with the target cell lit up.
List<HintStep> _revealSteps(Hint hint, String intro) => [
      HintStep(
        text: intro,
        cells: hint.secondaryCells,
        rows: hint.highlightedRows,
        cols: hint.highlightedCols,
        boxes: hint.highlightedBoxes,
      ),
      HintStep(
        text: hint.explanation,
        cells: {...hint.secondaryCells, ...hint.primaryCells},
        rows: hint.highlightedRows,
        cols: hint.highlightedCols,
        boxes: hint.highlightedBoxes,
        showConclusion: true,
      ),
    ];

/// Naked/locked subsets ("these cells hold only these digits") and hidden
/// subsets ("these digits fit only in these cells") share one shape: the
/// group first, the explanation's conclusion second.
List<HintStep> _subsetSteps(Hint hint, AppLocalizations l10n,
    {required bool hidden}) {
  final digits = (hint.primaryDigits.toList()..sort()).join(', ');
  final unitDesc = _unitsDesc(hint, l10n);
  final count = hint.primaryCells.length;
  return [
    HintStep(
      text: hidden
          ? l10n.hintStepHiddenSubsetIntro(count, digits, unitDesc)
          : l10n.hintStepNakedSubsetIntro(count, digits, unitDesc),
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      boxes: hint.highlightedBoxes,
    ),
    HintStep(
      text: hint.explanation,
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      boxes: hint.highlightedBoxes,
      showConclusion: true,
    ),
  ];
}

/// Pointing outlines its source box first, claiming its source line; the
/// unit the eliminations land on joins at the conclusion.
List<HintStep> _intersectionSteps(Hint hint, AppLocalizations l10n) {
  if (hint.eliminations.isEmpty ||
      hint.highlightedBoxes.isEmpty ||
      (hint.highlightedRows.isEmpty && hint.highlightedCols.isEmpty)) {
    return const [];
  }
  final d = hint.eliminations.first.digit;
  final boxDesc = _boxDesc(hint.highlightedBoxes.first, l10n);
  final lineDesc = hint.highlightedRows.isNotEmpty
      ? l10n.unitRow(hint.highlightedRows.first + 1)
      : l10n.unitCol(hint.highlightedCols.first + 1);
  final pointing = hint.technique == HintTechnique.intersectionPointing;
  return [
    HintStep(
      text: pointing
          ? l10n.hintStepPointingIntro(d, boxDesc, lineDesc)
          : l10n.hintStepClaimingIntro(d, lineDesc, boxDesc),
      cells: hint.primaryCells,
      rows: pointing ? const {} : hint.highlightedRows,
      cols: pointing ? const {} : hint.highlightedCols,
      boxes: pointing ? hint.highlightedBoxes : const {},
    ),
    HintStep(
      text: hint.explanation,
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      boxes: hint.highlightedBoxes,
      showConclusion: true,
    ),
  ];
}

/// Swordfish/Jellyfish and the finned variants: base lines first, the full
/// lattice with the explanation second. The base lines are whichever
/// highlighted orientation the eliminations do NOT sit on — a row-based
/// fish eliminates along its cover columns, outside the base rows.
List<HintStep> _fishSteps(Hint hint, AppLocalizations l10n) {
  if (hint.eliminations.isEmpty ||
      (hint.highlightedRows.isEmpty && hint.highlightedCols.isEmpty)) {
    return const [];
  }
  final d = hint.eliminations.first.digit;
  final rowBased =
      hint.eliminations.every((e) => !hint.highlightedRows.contains(e.row));
  final baseRows = rowBased ? hint.highlightedRows : const <int>{};
  final baseCols = rowBased ? const <int>{} : hint.highlightedCols;
  final linesDesc = [
    for (final r in baseRows.toList()..sort()) l10n.unitRow(r + 1),
    for (final c in baseCols.toList()..sort()) l10n.unitCol(c + 1),
  ].join(', ');
  return [
    HintStep(
      text: l10n.hintStepFishIntro(d, linesDesc),
      cells: hint.primaryCells,
      rows: baseRows,
      cols: baseCols,
    ),
    HintStep(
      text: hint.explanation,
      cells: hint.primaryCells,
      rows: hint.highlightedRows,
      cols: hint.highlightedCols,
      showConclusion: true,
    ),
  ];
}

/// Sue de Coq: the crowded crossing cells, then each Almost Locked Set —
/// line side, box side — then the full explanation with the eliminations.
/// Every step spells out the concrete count argument (these N cells hold
/// exactly these digits — M kinds) with the per-cluster digit sets the
/// finder stored in [Hint.digitGroups] as `[V, D, E]`.
List<HintStep> _sueDeCoqSteps(Hint hint, AppLocalizations l10n) {
  String cellsDesc(Set<HintCell> cells) =>
      cells.map((c) => _cellDesc(c, l10n)).join('·');
  String digitsDesc(Set<int> digits) =>
      (digits.toList()..sort()).join('·');
  final units = (
    rows: hint.highlightedRows,
    cols: hint.highlightedCols,
    boxes: hint.highlightedBoxes,
  );
  final v = hint.digitGroups[0], d = hint.digitGroups[1];
  final e = hint.digitGroups[2];
  return [
    HintStep(
      text: l10n.hintStepSueDeCoqIntro(cellsDesc(hint.primaryCells),
          hint.primaryCells.length, digitsDesc(v), v.length),
      cells: hint.primaryCells,
      rows: units.rows,
      cols: units.cols,
      boxes: units.boxes,
    ),
    HintStep(
      text: l10n.hintStepSueDeCoqLine(cellsDesc(hint.colorGroupA),
          hint.colorGroupA.length, digitsDesc(d), d.length),
      cells: {...hint.primaryCells, ...hint.colorGroupA},
      rows: units.rows,
      cols: units.cols,
      boxes: units.boxes,
    ),
    HintStep(
      text: l10n.hintStepSueDeCoqBox(cellsDesc(hint.colorGroupB),
          hint.colorGroupB.length, digitsDesc(e), e.length),
      cells: {...hint.primaryCells, ...hint.colorGroupA, ...hint.colorGroupB},
      rows: units.rows,
      cols: units.cols,
      boxes: units.boxes,
    ),
    HintStep(
      text: hint.explanation,
      cells: {...hint.primaryCells, ...hint.colorGroupA, ...hint.colorGroupB},
      rows: units.rows,
      cols: units.cols,
      boxes: units.boxes,
      showConclusion: true,
    ),
  ];
}

/// Triple Firework: the row spray, the column spray, the forced triple on
/// the cross + wings, then the explanation with the eliminations.
List<HintStep> _fireworkSteps(Hint hint, AppLocalizations l10n) {
  final r = hint.highlightedRows.first;
  final c = hint.highlightedCols.first;
  final cross = HintCell(r, c);
  final rowWing =
      hint.primaryCells.firstWhere((p) => p.row == r && p != cross);
  final colWing =
      hint.primaryCells.firstWhere((p) => p.col == c && p != cross);
  final digits = (hint.primaryDigits.toList()..sort()).join('·');
  final tripleDesc = [cross, rowWing, colWing]
      .map((cell) => _cellDesc(cell, l10n))
      .join('·');
  // The full spray, enumerated in line order so the player can check the
  // confinement cell by cell.
  final rowSpray = (hint.colorGroupA.toList()
        ..sort((a, b) => a.col - b.col))
      .map((cell) => _cellDesc(cell, l10n))
      .join('·');
  final colSpray = (hint.colorGroupB.toList()
        ..sort((a, b) => a.row - b.row))
      .map((cell) => _cellDesc(cell, l10n))
      .join('·');
  return [
    HintStep(
      text: l10n.hintStepFireworkRow(
          digits, rowSpray, _cellDesc(rowWing, l10n)),
      cells: hint.colorGroupA,
      rows: {r},
      boxes: hint.highlightedBoxes,
    ),
    HintStep(
      text: l10n.hintStepFireworkCol(
          digits, colSpray, _cellDesc(colWing, l10n)),
      cells: {...hint.colorGroupA, ...hint.colorGroupB},
      rows: {r},
      cols: {c},
      boxes: hint.highlightedBoxes,
    ),
    HintStep(
      text: l10n.hintStepFireworkTriple(tripleDesc, digits),
      cells: hint.primaryCells,
      rows: {r},
      cols: {c},
      boxes: hint.highlightedBoxes,
    ),
    HintStep(
      text: hint.explanation,
      cells: {...hint.colorGroupA, ...hint.colorGroupB},
      rows: {r},
      cols: {c},
      boxes: hint.highlightedBoxes,
      showConclusion: true,
    ),
  ];
}

/// Unique Rectangles: the deadly-pattern rectangle first (one digit-free
/// intro fits all four types), each type's own explanation second.
List<HintStep> _urSteps(Hint hint, AppLocalizations l10n) => [
      HintStep(
        text: l10n.hintStepURIntro,
        cells: hint.primaryCells,
        rows: hint.highlightedRows,
        cols: hint.highlightedCols,
        boxes: hint.highlightedBoxes,
      ),
      HintStep(
        text: hint.explanation,
        cells: hint.primaryCells,
        rows: hint.highlightedRows,
        cols: hint.highlightedCols,
        boxes: hint.highlightedBoxes,
        showConclusion: true,
      ),
    ];
