part of '../hint_engine.dart';

/// A conjugate pair (strong link) for a single digit: the only two cells in
/// [unit] where that digit can go, so exactly one of them holds it. [unit]
/// is kept (not just its type) so the found pattern can highlight the two
/// linking units and so the geometry can be classified.
class _StrongLink {
  const _StrongLink(this.a, this.b, this.unit);

  final List<int> a;
  final List<int> b;
  final _Unit unit;
}

/// Skyscraper / 2-String Kite / Turbot Fish — three geometry variants of one
/// single-digit pattern: `f1 =strong= p1 ~weak~ p2 =strong= f2`. Because the
/// two strong links (conjugate pairs) are each "at least one end is the
/// digit" and the connecting weak link is "not both ends are the digit", the
/// alternation forces at least one of the two *free* ends f1/f2 to be the
/// digit — so any cell that sees both free ends can have the digit removed.
///
/// Unlike Simple Coloring (which only reasons *within* a single strong-link
/// component), this bridges a weak link between two separate conjugate pairs,
/// so it finds eliminations coloring misses. The three techniques differ only
/// in how the two strong links and their connecting weak link are laid out:
///  - Skyscraper: both strong links are lines of the same orientation (two
///    rows or two columns) joined by a shared perpendicular line. The
///    degenerate case where the free ends also align (same cross-line) is an
///    X-Wing, not a Skyscraper, and is rejected.
///  - 2-String Kite: one row strong link + one column strong link whose near
///    ends share a box.
///  - Turbot Fish: every other valid layout (a box strong link is involved,
///    or same-orientation lines joined through a box, etc.).
extension HintEngineSingleDigitChains on HintEngine {
  Hint? findSkyscraper(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findSingleDigitChain(resolved, l10n, HintTechnique.skyscraper);
  }

  Hint? findTwoStringKite(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findSingleDigitChain(resolved, l10n, HintTechnique.twoStringKite);
  }

  Hint? findTurbotFish(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findSingleDigitChain(resolved, l10n, HintTechnique.turbotFish);
  }

  /// Runs the shared strong-weak-strong search and returns the first pattern
  /// whose geometry classifies as [wantClass]. Digits 1-9 and units in
  /// [_allUnits] order are scanned deterministically so "first match wins".
  Hint? _findSingleDigitChain(
    List<List<Set<int>>> candidates,
    AppLocalizations? l10n,
    HintTechnique wantClass,
  ) {
    final resolvedL10n = _resolveL10n(l10n);
    for (var d = 1; d <= 9; d++) {
      final links = <_StrongLink>[];
      for (final unit in _allUnits()) {
        final cells = unit.cells
            .where((rc) => candidates[rc[0]][rc[1]].contains(d))
            .toList();
        if (cells.length != 2) continue;
        links.add(_StrongLink(cells[0], cells[1], unit));
      }

      for (var i = 0; i < links.length; i++) {
        for (var j = i + 1; j < links.length; j++) {
          final s1 = links[i];
          final s2 = links[j];
          for (var e1 = 0; e1 < 2; e1++) {
            final p1 = e1 == 0 ? s1.a : s1.b;
            final f1 = e1 == 0 ? s1.b : s1.a;
            for (var e2 = 0; e2 < 2; e2++) {
              final p2 = e2 == 0 ? s2.a : s2.b;
              final f2 = e2 == 0 ? s2.b : s2.a;

              // The four cells must be distinct (the two conjugate pairs can
              // share a cell — e.g. a cell in both a row and a column pair).
              final ids = {
                p1[0] * 9 + p1[1],
                f1[0] * 9 + f1[1],
                p2[0] * 9 + p2[1],
                f2[0] * 9 + f2[1],
              };
              if (ids.length != 4) continue;

              // The connecting weak link: the near ends must see each other.
              if (!_seeEachOther(p1, p2)) continue;

              final cls =
                  _classifySingleDigitChain(s1.unit.type, s2.unit.type, p1, p2, f1, f2);
              if (cls != wantClass) continue;

              final eliminations = <HintElimination>[];
              for (var r = 0; r < 9; r++) {
                for (var c = 0; c < 9; c++) {
                  if (ids.contains(r * 9 + c)) continue;
                  if (!candidates[r][c].contains(d)) continue;
                  if (_seeEachOther([r, c], f1) && _seeEachOther([r, c], f2)) {
                    eliminations.add(HintElimination(r, c, d));
                  }
                }
              }
              if (eliminations.isEmpty) continue;

              final (hr1, hc1, hb1) = _highlightFor(s1.unit);
              final (hr2, hc2, hb2) = _highlightFor(s2.unit);
              final cell1 = _cellDesc(f1[0], f1[1], resolvedL10n);
              final cell2 = _cellDesc(f2[0], f2[1], resolvedL10n);

              return Hint(
                technique: wantClass,
                type: HintType.eliminate,
                explanation:
                    _singleDigitChainExplanation(wantClass, d, cell1, cell2, resolvedL10n),
                primaryCells: {
                  HintCell(p1[0], p1[1]),
                  HintCell(f1[0], f1[1]),
                  HintCell(p2[0], p2[1]),
                  HintCell(f2[0], f2[1]),
                },
                secondaryCells:
                    eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
                highlightedRows: {...hr1, ...hr2},
                highlightedCols: {...hc1, ...hc2},
                highlightedBoxes: {...hb1, ...hb2},
                primaryDigits: {d},
                eliminations: eliminations,
                // f1 =strong= p1 ~weak~ p2 =strong= f2 — one digit
                // throughout, so every node carries d.
                chainLinks: [
                  HintChainLink(
                    from: HintChainNode.single(HintCell(f1[0], f1[1]), d),
                    to: HintChainNode.single(HintCell(p1[0], p1[1]), d),
                    strong: true,
                  ),
                  HintChainLink(
                    from: HintChainNode.single(HintCell(p1[0], p1[1]), d),
                    to: HintChainNode.single(HintCell(p2[0], p2[1]), d),
                    strong: false,
                  ),
                  HintChainLink(
                    from: HintChainNode.single(HintCell(p2[0], p2[1]), d),
                    to: HintChainNode.single(HintCell(f2[0], f2[1]), d),
                    strong: true,
                  ),
                ],
              );
            }
          }
        }
      }
    }
    return null;
  }

  /// Classifies a strong-weak-strong single-digit pattern by the unit types
  /// of its two strong links ([t1]/[t2]) and how the near ends [p1]/[p2]
  /// connect. Returns null for the X-Wing degeneracy (which the X-Wing
  /// technique already handles) so it's reported as neither.
  HintTechnique? _classifySingleDigitChain(
    _UnitType t1,
    _UnitType t2,
    List<int> p1,
    List<int> p2,
    List<int> f1,
    List<int> f2,
  ) {
    // The near ends connect through a line (shared row/column) or a box.
    final lineLink = p1[0] == p2[0] || p1[1] == p2[1];
    final bothRows = t1 == _UnitType.row && t2 == _UnitType.row;
    final bothCols = t1 == _UnitType.col && t2 == _UnitType.col;
    final rowAndCol = (t1 == _UnitType.row && t2 == _UnitType.col) ||
        (t1 == _UnitType.col && t2 == _UnitType.row);

    if ((bothRows || bothCols) && lineLink) {
      // Free ends aligned on the cross-line too => it's an X-Wing, not a
      // Skyscraper.
      if (bothRows && f1[1] == f2[1]) return null;
      if (bothCols && f1[0] == f2[0]) return null;
      return HintTechnique.skyscraper;
    }
    if (rowAndCol && !lineLink) {
      return HintTechnique.twoStringKite;
    }
    return HintTechnique.turbotFish;
  }

  String _singleDigitChainExplanation(
    HintTechnique technique,
    int digit,
    String cell1,
    String cell2,
    AppLocalizations l10n,
  ) =>
      switch (technique) {
        HintTechnique.twoStringKite =>
          l10n.explanationTwoStringKite(digit, cell1, cell2),
        HintTechnique.turbotFish =>
          l10n.explanationTurbotFish(digit, cell1, cell2),
        _ => l10n.explanationSkyscraper(digit, cell1, cell2),
      };
}
