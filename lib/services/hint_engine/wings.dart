part of '../hint_engine.dart';

extension HintEngineWings on HintEngine {
  Hint? findXYWing(
    List<List<int>> board, [
    List<List<Set<int>>>? candidates,
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXYWing(resolved);
  }

  Hint? _findXYWing(List<List<Set<int>>> candidates) {
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

            final pivotDesc = '${pr + 1}행${pc + 1}열';
            final w1Desc = '${w1[0] + 1}행${w1[1] + 1}열';
            final w2Desc = '${w2[0] + 1}행${w2[1] + 1}열';

            return Hint(
              technique: HintTechnique.xyWing,
              type: HintType.eliminate,
              explanation: '피벗 칸 $pivotDesc의 후보는 $x, $y 두 개예요. 날개 칸 '
                  '$w1Desc는 $sharedDigitW1 아니면 $z, $w2Desc는 '
                  '$otherPivotDigit 아니면 $z예요. 피벗이 $sharedDigitW1이면 '
                  '$w1Desc가, 피벗이 $otherPivotDigit이면 $w2Desc가 $z가 '
                  '되므로, 어느 쪽이든 두 날개를 모두 보는 칸에서는 $z를 '
                  '후보에서 지울 수 있습니다.',
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
  ]) {
    final resolved = candidates ?? _freshCandidates(board);
    return _findXYChain(resolved);
  }

  Hint? _findXYChain(List<List<Set<int>>> candidates) {
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
              ]);
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
        final hint = _buildXYChainHint(candidates, newPath, targetZ);
        if (hint != null) return hint;
      }

      final deeper =
          _extendXYChain(candidates, next, otherDigit, targetZ, newPath);
      if (deeper != null) return deeper;
    }
    return null;
  }

  Hint? _buildXYChainHint(
    List<List<Set<int>>> candidates,
    List<List<int>> path,
    int z,
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

    final chainDesc = path.map((p) => '${p[0] + 1}행${p[1] + 1}열').join(' - ');
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

    return Hint(
      technique: HintTechnique.xyChain,
      type: HintType.eliminate,
      explanation: '$chainDesc 순서로 이어지는 칸들은 후보가 둘씩뿐이라, 사슬 '
          '한쪽 끝이 $z가 아니면 반대쪽 끝이 $z가 될 수밖에 없어요. 그래서 '
          '사슬 양쪽 끝을 모두 보는 칸에서는 $z를 후보에서 지울 수 있습니다.',
      primaryCells: path.map((p) => HintCell(p[0], p[1])).toSet(),
      secondaryCells: eliminations.map((e) => HintCell(e.row, e.col)).toSet(),
      colorGroupA: colorGroupA,
      colorGroupB: colorGroupB,
      primaryDigits: chainDigits,
      eliminations: eliminations,
    );
  }
}
