import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/l10n/generated/app_localizations.dart';
import 'package:sudoku/models/hint.dart';
import 'package:sudoku/services/hint_engine.dart';
import 'package:sudoku/services/hint_step_builder.dart';
import 'package:sudoku/services/sudoku_solver.dart';

List<List<int>> _emptyBoard() => List.generate(9, (_) => List.filled(9, 0));

/// Same sparse-candidates fixture helper as hint_engine_test.dart — builds
/// exactly the cells a technique cares about.
List<List<Set<int>>> candidatesFrom(Map<List<int>, Set<int>> cells) {
  final grid = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
  cells.forEach((rc, digits) => grid[rc[0]][rc[1]] = digits);
  return grid;
}

/// The structural contract every walkthrough must satisfy: at least two
/// steps, narration on each, the visible-links prefix only ever grows (and
/// stays within the chain), and exactly the final step reveals the
/// eliminations — it is the "everything at once" view the pre-step UI
/// always showed.
void _expectWellFormedSteps(Hint hint, List<HintStep> steps) {
  expect(steps.length, greaterThanOrEqualTo(2));
  for (final step in steps) {
    expect(step.text, isNotEmpty);
    expect(step.visibleLinks, lessThanOrEqualTo(hint.chainLinks.length));
  }
  for (var i = 0; i + 1 < steps.length; i++) {
    expect(steps[i].visibleLinks, lessThanOrEqualTo(steps[i + 1].visibleLinks),
        reason: 'a step never hides links the previous step already showed');
    expect(steps[i].showConclusion, isFalse,
        reason: 'only the final step shows the eliminations');
  }
  expect(steps.last.showConclusion, isTrue);
}

void main() {
  final engine = HintEngine();
  final l10n = lookupAppLocalizations(const Locale('ko'));

  test('XY-Wing: pivot intro, one step per wing case, then the conclusion',
      () {
    final hint = engine.findXYWing(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2},
          [0, 4]: {1, 3},
          [4, 0]: {2, 3},
          [4, 4]: {3, 9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(4));
    // The intro shows the pivot alone, before any links.
    expect(steps.first.visibleLinks, 0);
    expect(steps.first.cells, hasLength(1));
    // Each wing case puts its bold marker on that wing's z.
    expect(steps[1].emphasisNodes.single.digit, 3);
    expect(steps[2].emphasisNodes.single.digit, 3);
  });

  test('XYZ-Wing: adds the pivot-is-z case before the conclusion', () {
    final hint = engine.findXYZWing(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2, 3},
          [0, 1]: {1, 3},
          [1, 0]: {2, 3},
          [1, 1]: {3, 8},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(5));
    // The fourth step is the pivot's own z — its bold marker sits on the
    // pivot cell, which no wing-case step touches.
    expect(steps[3].emphasisNodes.single.cells.single, const HintCell(0, 0));
    expect(steps[3].emphasisNodes.single.digit, 3);
  });

  test('W-Wing: pair, bridge (with its unit outlined), forcing, conclusion',
      () {
    final hint = engine.findWWing(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2},
          [4, 4]: {1, 2},
          [0, 8]: {2, 5},
          [4, 8]: {2, 6},
          [0, 4]: {1, 7},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(4));
    // The pair intro shows no unit yet; the bridge step outlines the
    // bridge's unit (column 9 here).
    expect(steps.first.cols, isEmpty);
    expect(steps[1].cols, {8});
  });

  test('XY-Chain: start, one hop per further cell, conclusion', () {
    final hint = engine.findXYChain(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2},
          [0, 4]: {2, 3},
          [4, 4]: {3, 4},
          [4, 0]: {1, 4},
          [2, 0]: {1, 9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    final cellCount = (hint.chainLinks.length + 1) ~/ 2;
    expect(steps, hasLength(cellCount + 1));
    // The start step shows exactly the start cell's own strong link.
    expect(steps.first.visibleLinks, 1);
    expect(steps.first.cells, hasLength(1));
  });

  test('Remote Pair: intro, alternation, opposite ends, conclusion', () {
    final hint = engine.findRemotePair(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2},
          [0, 4]: {1, 2},
          [5, 4]: {1, 2},
          [5, 7]: {1, 2},
          [0, 7]: {1, 2, 9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(4));
    // The ends step bold-marks both candidates of both end cells.
    expect(steps[2].emphasisNodes, hasLength(4));
  });

  test('Skyscraper: strong link, second strong link, forcing, conclusion',
      () {
    final hint = engine.findSkyscraper(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {4, 5},
          [0, 3]: {4, 6},
          [8, 0]: {4, 7},
          [8, 5]: {4, 8},
          [1, 5]: {4, 9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(4));
    expect(steps.first.visibleLinks, 1);
    expect(steps[1].visibleLinks, 3);
  });

  test('Simple Coloring Rule 1: chain, clash, conclusion', () {
    final hint = engine.findSimpleColoring(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {9},
          [0, 2]: {9},
          [2, 2]: {9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(3));
    // The chain intro hides the final clash link; the clash step adds it.
    expect(steps.first.visibleLinks, hint.chainLinks.length - 1);
    expect(steps[1].visibleLinks, hint.chainLinks.length);
  });

  test('Simple Coloring Rule 2: chain, then the trap conclusion', () {
    final hint = engine.findSimpleColoring(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {9},
          [0, 1]: {9},
          [2, 2]: {9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
  });

  test('X-Wing: base lines first, then the crossing lines, then the '
      'conclusion', () {
    final board = _emptyBoard();
    board[0] = [1, 2, 0, 3, 4, 5, 0, 6, 8];
    board[3] = [1, 2, 0, 3, 4, 5, 0, 6, 8];
    final hint = engine.findXWing(board)!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(3));
    // Row-based: the intro outlines only the two base rows; the rectangle
    // step adds the crossing columns.
    expect(steps.first.rows, {0, 3});
    expect(steps.first.cols, isEmpty);
    expect(steps[1].cols, {2, 6});
  });

  test('Full House: the near-full unit first, then the reveal', () {
    final board = SudokuSolver()
        .solve(_emptyBoard())!
        .map((row) => List<int>.from(row))
        .toList();
    board[0][0] = 0;
    final hint = engine.findFullHouse(board)!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
    // The intro shows the unit's filled cells but NOT the target yet.
    expect(steps.first.cells, hint.secondaryCells);
    expect(steps.last.text, hint.explanation);
  });

  test('Hidden Single: reveal walkthrough built from the hint value', () {
    final hint = engine.findHiddenSingle(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {9},
          [0, 1]: {1, 2},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
  });

  test('Naked Pair: the group intro, then the conclusion', () {
    final hint = engine.findNakedPair(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2},
          [0, 1]: {1, 2},
          [0, 5]: {1, 7},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
    expect(steps.first.cells, hint.primaryCells);
    expect(steps.last.text, hint.explanation);
  });

  test('Hidden Pair: uses the hidden-subset intro shape', () {
    final hint = engine.findHiddenPair(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2, 5},
          [0, 1]: {1, 2, 6},
          [0, 2]: {5, 6},
          [0, 3]: {7, 8},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
  });

  test('Intersection pointing: source box outlined first, line joins at '
      'the conclusion', () {
    final hint = engine.findIntersectionPointing(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 7},
          [0, 1]: {2, 7},
          [0, 5]: {3, 7},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
    expect(steps.first.boxes, isNotEmpty);
    expect(steps.first.rows, isEmpty);
    expect(steps.last.rows, {0});
  });

  test('Swordfish: base rows outlined first, cover columns join at the '
      'conclusion', () {
    final hint = engine.findSwordfish(
        _emptyBoard(),
        candidatesFrom({
          [0, 1]: {1, 7},
          [0, 4]: {2, 7},
          [3, 4]: {3, 7},
          [3, 7]: {4, 7},
          [6, 1]: {5, 7},
          [6, 7]: {6, 7},
          [5, 4]: {7, 9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
    expect(steps.first.rows, {0, 3, 6});
    expect(steps.first.cols, isEmpty);
    expect(steps.last.cols, isNotEmpty);
  });

  test('Unique Rectangle Type 1: rectangle intro, then the type-specific '
      'conclusion', () {
    final hint = engine.findUniqueRectangleType1(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2},
          [0, 3]: {1, 2},
          [1, 0]: {1, 2},
          [1, 3]: {1, 2, 5},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(2));
    expect(steps.last.text, hint.explanation);
  });

  test('a chain technique hint without links gets no walkthrough', () {
    final hint = Hint(
      technique: HintTechnique.skyscraper,
      type: HintType.eliminate,
      explanation: 'fake',
      primaryCells: {const HintCell(0, 0)},
    );

    expect(buildHintSteps(hint, l10n), isEmpty);
  });

  test('X-Chain: start, one step per weak+strong hop, either-ends, then the '
      'conclusion — each step explains why its link is strong or weak', () {
    // The Skyscraper-shaped 4-node X-Chain fixture (3 links).
    final hint = engine.findXChain(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {4},
          [0, 3]: {4},
          [8, 0]: {4},
          [8, 5]: {4},
          [1, 5]: {4, 7},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    // 3 links = start(strong) + 1 weak/strong pair + either-ends + conclusion.
    expect(steps, hasLength(4));
    expect(steps[0].visibleLinks, 1);
    expect(steps[1].visibleLinks, 3);
    // Every link here joins two DIFFERENT cells, so the narration must use
    // the unit-based reasons ("자리가 딱 두 곳" / "같은 구역"), never the
    // bivalue in-cell ones.
    expect(steps[0].text, contains('두 곳'));
    expect(steps[1].text, contains('같은 구역'));
    // The either-ends step names both endpoints' digits.
    expect(steps[2].text, contains('4'));
  });

  test('AIC with a bivalue hop narrates the in-cell strong-link reason', () {
    // r7c6={1,9} bridges two bilocation links through an in-cell strong
    // link: r7c4(1) =S= r7c6(1) ~W~[in-cell] r7c6(9) =S= r9c5(9). Built as
    // a hand fixture shaped like the mined demo board's chain.
    final hint = engine.findAic(
        _emptyBoard(),
        candidatesFrom({
          [6, 3]: {1},
          [6, 5]: {1, 9},
          [8, 4]: {9},
          [8, 5]: {9, 5},
          [8, 3]: {1, 5},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    // Some hop must be narrated with an in-cell reason (bivalue strong link
    // "후보가 딱 두 개" or in-cell weak link "숫자가 하나만") — that's what
    // distinguishes a genuine AIC walkthrough from an X-Chain's.
    expect(
      steps.any((s) =>
          s.text.contains('후보가 딱 두 개') || s.text.contains('하나만')),
      isTrue,
      reason: 'an AIC crossing a bivalue cell must explain the in-cell link',
    );
  });

  test('Sue de Coq: crossing intro, line ALS, box ALS, then the conclusion',
      () {
    final hint = engine.findSueDeCoq(
        _emptyBoard(),
        candidatesFrom({
          [0, 0]: {1, 2, 3},
          [0, 1]: {2, 3, 4},
          [0, 5]: {1, 4},
          [0, 7]: {1, 5},
          [1, 2]: {2, 3},
          [2, 1]: {3, 9},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(4));
    // The walkthrough grows one cluster at a time: crossing → +line ALS →
    // +box ALS.
    expect(steps[0].cells, hint.primaryCells);
    expect(steps[1].cells, containsAll(hint.colorGroupA));
    expect(steps[2].cells, containsAll(hint.colorGroupB));
    expect(steps[1].text, contains('거의-잠긴'));
  });

  test('Triple Firework: row spray, column spray, the forced triple, then '
      'the conclusion', () {
    final hint = engine.findTripleFirework(
        _emptyBoard(),
        candidatesFrom({
          [4, 3]: {1, 2},
          [4, 4]: {1, 2, 3},
          [4, 5]: {3, 7},
          [4, 8]: {1, 3, 5},
          [3, 4]: {2, 3},
          [5, 4]: {1, 2},
          [8, 4]: {2, 3, 6},
          [3, 3]: {1, 8},
        }))!;

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(4));
    // Wings are named in their line's step; the triple step names all three
    // cells and all three digits.
    expect(steps[0].text, contains('5행9열'));
    expect(steps[1].text, contains('9행5열'));
    expect(steps[2].text, contains('1·2·3'));
    expect(steps[2].cells, hint.primaryCells);
  });

  test('grouped chain names every cell of a group node and uses the '
      '"one of the cluster" strong wording', () {
    // A real grouped X-Chain shape, hand-built so the group's position in
    // the walkthrough is deterministic: r8c7 = r8c0 ~ r0c0 = {r0c6,r0c7},
    // the final strong link landing on the two-cell group.
    const group = HintChainNode([HintCell(0, 6), HintCell(0, 7)], 1);
    final hint = Hint(
      technique: HintTechnique.groupedXChain,
      type: HintType.eliminate,
      explanation: '',
      primaryCells: {
        const HintCell(8, 7), const HintCell(8, 0), const HintCell(0, 0), //
        const HintCell(0, 6), const HintCell(0, 7),
      },
      primaryDigits: const {1},
      eliminations: const [HintElimination(1, 7, 1)],
      chainLinks: [
        HintChainLink(
            from: HintChainNode.single(const HintCell(8, 7), 1),
            to: HintChainNode.single(const HintCell(8, 0), 1),
            strong: true),
        HintChainLink(
            from: HintChainNode.single(const HintCell(8, 0), 1),
            to: HintChainNode.single(const HintCell(0, 0), 1),
            strong: false),
        HintChainLink(
            from: HintChainNode.single(const HintCell(0, 0), 1),
            to: group,
            strong: true),
      ],
    );

    final steps = buildHintSteps(hint, l10n);

    _expectWellFormedSteps(hint, steps);
    expect(steps, hasLength(4));
    // The hop landing on the group must say "one of the cluster", not the
    // single-cell "this cell must be" wording, and must list both cells.
    expect(steps[1].text, contains('묶음 중 하나'));
    expect(steps[1].text, contains('1행7열·1행8열'));
    // The either-ends step names the group end by all of its cells too.
    expect(steps[2].text, contains('1행7열·1행8열'));
  });
}
