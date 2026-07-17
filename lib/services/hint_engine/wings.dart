part of '../hint_engine.dart';

extension HintEngineWings on HintEngine {
  /// XYZ-Wing: like [findXYWing], but the pivot holds three candidates
  /// {x, y, z} rather than two, with wings {x, z} and {y, z} that both see
  /// it. Whichever of the three the pivot takes, z lands on the pivot or one
  /// of the wings — so a cell seeing ALL THREE loses z.
  ///
  /// The "all three" is the whole difference from XY-Wing, where a bivalue
  /// pivot can never be z itself and only the two wings need to be seen.
  Hint? findXYZWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXYZWing(resolved, l10n);
  }

  Hint? _findXYZWing(List<List<Set<int>>> candidates, AppLocalizations? l10n) {
    final resolvedL10n = _resolveL10n(l10n);
    for (var pr = 0; pr < 9; pr++) {
      for (var pc = 0; pc < 9; pc++) {
        final pivot = candidates[pr][pc];
        if (pivot.length != 3) continue;

        final wings = _peers(pr, pc)
            .where((rc) =>
                candidates[rc[0]][rc[1]].length == 2 &&
                candidates[rc[0]][rc[1]].every(pivot.contains))
            .toList();

        for (var i = 0; i < wings.length; i++) {
          for (var j = i + 1; j < wings.length; j++) {
            final w1 = wings[i];
            final w2 = wings[j];
            final c1 = candidates[w1[0]][w1[1]];
            final c2 = candidates[w2[0]][w2[1]];
            // {x,z} and {y,z} share exactly z and together span the pivot.
            final shared = c1.intersection(c2);
            if (shared.length != 1) continue;
            if (c1.union(c2).length != 3) continue;
            final z = shared.first;

            final eliminations = <HintElimination>[];
            for (var r = 0; r < 9; r++) {
              for (var c = 0; c < 9; c++) {
                if ((r == pr && c == pc) ||
                    (r == w1[0] && c == w1[1]) ||
                    (r == w2[0] && c == w2[1])) {
                  continue;
                }
                if (!candidates[r][c].contains(z)) continue;
                if (_seeEachOther([r, c], [pr, pc]) &&
                    _seeEachOther([r, c], w1) &&
                    _seeEachOther([r, c], w2)) {
                  eliminations.add(HintElimination(r, c, z));
                }
              }
            }
            if (eliminations.isEmpty) continue;

            return Hint(
              technique: HintTechnique.xyzWing,
              type: HintType.eliminate,
              explanation: resolvedL10n.explanationXYZWing(
                _cellDesc(pr, pc, resolvedL10n),
                (pivot.toList()..sort()).join(', '),
                _cellDesc(w1[0], w1[1], resolvedL10n),
                _cellDesc(w2[0], w2[1], resolvedL10n),
                z,
              ),
              primaryCells: {
                HintCell(pr, pc),
                HintCell(w1[0], w1[1]),
                HintCell(w2[0], w2[1]),
              },
              secondaryCells:
                  eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
              primaryDigits: pivot,
              eliminations: eliminations,
            );
          }
        }
      }
    }
    return null;
  }

  /// W-Wing: two non-peer cells that hold the same pair {a, b}, joined by a
  /// strong link on b — a unit where b has exactly two places, one seeing
  /// each cell. If both pair cells were b, the strong link's two ends would
  /// both be forced off b, leaving that unit no place for it. So at least one
  /// pair cell is a, and any cell seeing both loses a.
  ///
  /// Not reachable via [findXYChain] despite the family resemblance: the
  /// strong link's own cells need not be bivalue, and that search only ever
  /// steps through bivalue cells.
  Hint? findWWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findWWing(resolved, l10n);
  }

  Hint? _findWWing(List<List<Set<int>>> candidates, AppLocalizations? l10n) {
    final resolvedL10n = _resolveL10n(l10n);
    final bivalue = <List<int>>[
      for (var r = 0; r < 9; r++)
        for (var c = 0; c < 9; c++)
          if (candidates[r][c].length == 2) [r, c],
    ];

    for (var i = 0; i < bivalue.length; i++) {
      for (var j = i + 1; j < bivalue.length; j++) {
        final p1 = bivalue[i];
        final p2 = bivalue[j];
        final pair = candidates[p1[0]][p1[1]];
        // Both are bivalue, so containsAll is equality here.
        if (!pair.containsAll(candidates[p2[0]][p2[1]])) continue;
        // Two cells that see each other are a Naked Pair, not a W-Wing.
        if (_seeEachOther(p1, p2)) continue;
        final digits = pair.toList()..sort();

        for (final b in digits) {
          final a = digits.first == b ? digits[1] : digits.first;
          for (final unit in _allUnits()) {
            final places = unit.cells
                .where((rc) => candidates[rc[0]][rc[1]].contains(b))
                .toList();
            if (places.length != 2) continue;
            final e1 = places[0];
            final e2 = places[1];
            // The link must bridge the two pair cells without being one of
            // them — one end seeing each, either way round.
            final bridges = (_seeEachOther(e1, p1) && _seeEachOther(e2, p2)) ||
                (_seeEachOther(e1, p2) && _seeEachOther(e2, p1));
            if (!bridges) continue;
            if (places.any((rc) =>
                (rc[0] == p1[0] && rc[1] == p1[1]) ||
                (rc[0] == p2[0] && rc[1] == p2[1]))) {
              continue;
            }

            final eliminations = <HintElimination>[];
            for (var r = 0; r < 9; r++) {
              for (var c = 0; c < 9; c++) {
                if ((r == p1[0] && c == p1[1]) ||
                    (r == p2[0] && c == p2[1])) {
                  continue;
                }
                if (!candidates[r][c].contains(a)) continue;
                if (_seeEachOther([r, c], p1) && _seeEachOther([r, c], p2)) {
                  eliminations.add(HintElimination(r, c, a));
                }
              }
            }
            if (eliminations.isEmpty) continue;

            final (hRows, hCols, hBoxes) = _highlightFor(unit);
            return Hint(
              technique: HintTechnique.wWing,
              type: HintType.eliminate,
              explanation: resolvedL10n.explanationWWing(
                _cellDesc(p1[0], p1[1], resolvedL10n),
                _cellDesc(p2[0], p2[1], resolvedL10n),
                a,
                b,
                _unitDescription(unit, resolvedL10n),
              ),
              primaryCells: {
                HintCell(p1[0], p1[1]),
                HintCell(p2[0], p2[1]),
                HintCell(e1[0], e1[1]),
                HintCell(e2[0], e2[1]),
              },
              secondaryCells:
                  eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
              highlightedRows: hRows,
              highlightedCols: hCols,
              highlightedBoxes: hBoxes,
              primaryDigits: {a, b},
              eliminations: eliminations,
              chainLinks: [
                HintChainLink(
                  from: HintChainNode.single(HintCell(p1[0], p1[1]), a),
                  to: HintChainNode.single(HintCell(p1[0], p1[1]), b),
                  strong: true,
                ),
                HintChainLink(
                  from: HintChainNode.single(HintCell(p1[0], p1[1]), b),
                  to: HintChainNode.single(HintCell(e1[0], e1[1]), b),
                  strong: false,
                ),
                HintChainLink(
                  from: HintChainNode.single(HintCell(e1[0], e1[1]), b),
                  to: HintChainNode.single(HintCell(e2[0], e2[1]), b),
                  strong: true,
                ),
                HintChainLink(
                  from: HintChainNode.single(HintCell(e2[0], e2[1]), b),
                  to: HintChainNode.single(HintCell(p2[0], p2[1]), b),
                  strong: false,
                ),
                HintChainLink(
                  from: HintChainNode.single(HintCell(p2[0], p2[1]), b),
                  to: HintChainNode.single(HintCell(p2[0], p2[1]), a),
                  strong: true,
                ),
              ],
            );
          }
        }
      }
    }
    return null;
  }

  Hint? findXYWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXYWing(resolved, l10n);
  }

  Hint? _findXYWing(List<List<Set<int>>> candidates, AppLocalizations? l10n) {
    final resolvedL10n = _resolveL10n(l10n);
    for (var pr = 0; pr < 9; pr++) {
      for (var pc = 0; pc < 9; pc++) {
        final pivotCandidates = candidates[pr][pc];
        if (pivotCandidates.length != 2) continue;
        final pivotList = pivotCandidates.toList()..sort();
        final x = pivotList[0];
        final y = pivotList[1];

        final peers = _peers(pr, pc)
            .where((rc) => candidates[rc[0]][rc[1]].length == 2)
            .toList();

        for (var i = 0; i < peers.length; i++) {
          final w1 = peers[i];
          final w1Cands = candidates[w1[0]][w1[1]];
          final sharedW1 = w1Cands.intersection({x, y});
          if (sharedW1.length != 1) continue;
          final sharedDigitW1 = sharedW1.first;
          final z = w1Cands.difference({sharedDigitW1}).first;
          final otherPivotDigit = sharedDigitW1 == x ? y : x;

          for (var j = 0; j < peers.length; j++) {
            if (j == i) continue;
            final w2 = peers[j];
            final w2Cands = candidates[w2[0]][w2[1]];
            if (!(w2Cands.length == 2 &&
                w2Cands.contains(otherPivotDigit) &&
                w2Cands.contains(z))) {
              continue;
            }

            final eliminations = <HintElimination>[];
            for (var r = 0; r < 9; r++) {
              for (var c = 0; c < 9; c++) {
                if ((r == pr && c == pc) ||
                    (r == w1[0] && c == w1[1]) ||
                    (r == w2[0] && c == w2[1])) {
                  continue;
                }
                if (!candidates[r][c].contains(z)) continue;
                if (_seeEachOther([r, c], w1) && _seeEachOther([r, c], w2)) {
                  eliminations.add(HintElimination(r, c, z));
                }
              }
            }
            if (eliminations.isEmpty) continue;

            final pivotDesc = _cellDesc(pr, pc, resolvedL10n);
            final w1Desc = _cellDesc(w1[0], w1[1], resolvedL10n);
            final w2Desc = _cellDesc(w2[0], w2[1], resolvedL10n);

            return Hint(
              technique: HintTechnique.xyWing,
              type: HintType.eliminate,
              explanation: resolvedL10n.explanationXYWing(
                pivotDesc,
                x,
                y,
                w1Desc,
                sharedDigitW1,
                z,
                w2Desc,
                otherPivotDigit,
              ),
              primaryCells: {
                HintCell(pr, pc),
                HintCell(w1[0], w1[1]),
                HintCell(w2[0], w2[1]),
              },
              secondaryCells:
                  eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
              primaryDigits: {x, y},
              eliminations: eliminations,
            );
          }
        }
      }
    }
    return null;
  }

  /// Maximum XY-Chain path length (in cells) explored — a purely defensive
  /// backstop against a pathological, densely-interlinked bivalue subgraph
  /// blowing up search time. Any real elimination is found far short of
  /// this; it never affects legitimate results.
  static const _maxXYChainDepth = 25;

  /// XY-Chain: the multi-cell generalization of XY-Wing. A chain of
  /// bivalue cells, each linked to the next by a shared candidate digit
  /// (and by being peers), alternates which of its two candidates is
  /// "forced" at each step: if [current] is NOT [neededDigit], it must be
  /// its other candidate, which becomes the digit the next cell needs to
  /// continue the chain. If that forced alternation ever reaches a cell
  /// whose forced value is the original chain's target digit Z, then
  /// either the start cell is Z, or the end cell is Z — so any cell that
  /// peers BOTH ends and still has Z as a candidate can have it
  /// eliminated. Minimum chain length is 4 cells: length 2 is just a
  /// Naked Pair in disguise (two peer cells with identical candidate
  /// pairs), and length 3 is exactly an XY-Wing (the middle cell plays
  /// the pivot role) — both already handled by earlier, higher-priority
  /// techniques, so requiring length >= 4 keeps this a genuinely new
  /// capability rather than a slower rediscovery of existing hints.
  Hint? findXYChain(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
    AppLocalizations? l10n,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXYChain(resolved, l10n);
  }

  Hint? _findXYChain(List<List<Set<int>>> candidates, AppLocalizations? l10n) {
    final resolvedL10n = _resolveL10n(l10n);
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (candidates[r][c].length != 2) continue;
        final startCands = candidates[r][c].toList()..sort();
        for (var zIndex = 0; zIndex < 2; zIndex++) {
          final z = startCands[zIndex];
          final a = startCands[1 - zIndex];
          final hint = _extendXYChain(
              candidates,
              [r, c],
              a,
              z,
              [
                [r, c],
              ],
              resolvedL10n);
          if (hint != null) return hint;
        }
      }
    }
    return null;
  }

  Hint? _extendXYChain(
    List<List<Set<int>>> candidates,
    List<int> current,
    int neededDigit,
    int targetZ,
    List<List<int>> path,
    AppLocalizations l10n,
  ) {
    if (path.length >= _maxXYChainDepth) return null;

    final pathIndices = path.map((p) => p[0] * 9 + p[1]).toSet();
    final nextCells = <List<int>>{
      for (final p in _peers(current[0], current[1]))
        if (candidates[p[0]][p[1]].length == 2 &&
            candidates[p[0]][p[1]].contains(neededDigit) &&
            !pathIndices.contains(p[0] * 9 + p[1]))
          p,
    }.toList();

    for (final next in nextCells) {
      final nextCands = candidates[next[0]][next[1]];
      final otherDigit = nextCands.firstWhere((d) => d != neededDigit);
      final newPath = [...path, next];

      if (otherDigit == targetZ && newPath.length >= 4) {
        final hint = _buildXYChainHint(candidates, newPath, targetZ, l10n);
        if (hint != null) return hint;
      }

      final deeper = _extendXYChain(
          candidates, next, otherDigit, targetZ, newPath, l10n);
      if (deeper != null) return deeper;
    }
    return null;
  }

  Hint? _buildXYChainHint(
    List<List<Set<int>>> candidates,
    List<List<int>> path,
    int z,
    AppLocalizations l10n,
  ) {
    final start = path.first;
    final end = path.last;
    final chainIndices = path.map((p) => p[0] * 9 + p[1]).toSet();

    final eliminations = <HintElimination>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (chainIndices.contains(r * 9 + c)) continue;
        if (!candidates[r][c].contains(z)) continue;
        if (_seeEachOther([r, c], start) && _seeEachOther([r, c], end)) {
          eliminations.add(HintElimination(r, c, z));
        }
      }
    }
    if (eliminations.isEmpty) return null;

    final chainDesc =
        path.map((p) => _cellDesc(p[0], p[1], l10n)).join(' - ');
    final colorGroupA = <HintCell>{
      for (var i = 0; i < path.length; i += 2) HintCell(path[i][0], path[i][1]),
    };
    final colorGroupB = <HintCell>{
      for (var i = 1; i < path.length; i += 2) HintCell(path[i][0], path[i][1]),
    };
    // Every digit that actually appears along the chain, not just the
    // target z — each link cell's OWN pair of candidates is what carries
    // the chain, so both matter, not only the digit eliminated at the end.
    final chainDigits = <int>{};
    for (final p in path) {
      chainDigits.addAll(candidates[p[0]][p[1]]);
    }

    // An XY-Chain alternates *within* and *between* cells, so each bivalue
    // cell is two nodes, not one: the strong link is the cell's own pair
    // ("not z here means a here"), and the weak link is the shared digit
    // reaching the next cell. Walking it that way is what lets the overlay
    // attach each link to the pencil mark it actually reasons about —
    // `(C1,z) =strong= (C1,a) ~weak~ (C2,a) =strong= (C2,d2) ~weak~ ...`,
    // ending on `(Cn,z)`, so the chain's two ends are both z.
    HintCell cellAt(int i) => HintCell(path[i][0], path[i][1]);
    final chainLinks = <HintChainLink>[];
    var carry = candidates[start[0]][start[1]].firstWhere((d) => d != z);
    chainLinks.add(HintChainLink(
      from: HintChainNode.single(cellAt(0), z),
      to: HintChainNode.single(cellAt(0), carry),
      strong: true,
    ));
    for (var i = 0; i + 1 < path.length; i++) {
      final next = path[i + 1];
      chainLinks.add(HintChainLink(
        from: HintChainNode.single(cellAt(i), carry),
        to: HintChainNode.single(cellAt(i + 1), carry),
        strong: false,
      ));
      final other =
          candidates[next[0]][next[1]].firstWhere((d) => d != carry);
      chainLinks.add(HintChainLink(
        from: HintChainNode.single(cellAt(i + 1), carry),
        to: HintChainNode.single(cellAt(i + 1), other),
        strong: true,
      ));
      carry = other;
    }

    return Hint(
      technique: HintTechnique.xyChain,
      type: HintType.eliminate,
      explanation: l10n.explanationXYChain(chainDesc, z),
      primaryCells: path.map((p) => HintCell(p[0], p[1])).toSet(),
      secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      colorGroupA: colorGroupA,
      colorGroupB: colorGroupB,
      primaryDigits: chainDigits,
      eliminations: eliminations,
      chainLinks: chainLinks,
    );
  }
}
