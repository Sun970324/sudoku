import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/hint.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../state/game_controller.dart';
import '../theme/board_colors.dart';
import 'sudoku_cell_widget.dart';
import 'sudoku_grid_lines.dart';

/// Control point for the quadratic bow given to a chain's weak links, so
/// they read as distinct from the straight strong links and two links
/// between the same pair of candidates don't overdraw each other.
///
/// Bows perpendicular to [from]->[to] by 12% of the link's length, capped at
/// half a cell. Two details carry their weight:
///
/// * The normal is flipped to a canonical direction (downward, or rightward
///   when it is horizontal) rather than following each link's own winding,
///   so a link and its reverse bow the *same* way instead of crossing.
/// * A control point that would land outside [gridSize] bows inward
///   instead, keeping chains that hug an edge on the board.
///
/// Kept top-level and pure — a curve is impractical to assert on through a
/// rendered widget, but this is trivially testable in isolation.
@visibleForTesting
Offset curveControlPoint(
  Offset from,
  Offset to,
  double cellW,
  Size gridSize,
) {
  final mid = (from + to) / 2;
  final delta = to - from;
  final len = delta.distance;
  if (len == 0) return mid;

  var nx = -delta.dy / len;
  var ny = delta.dx / len;
  if (ny < 0 || (ny == 0 && nx < 0)) {
    nx = -nx;
    ny = -ny;
  }

  final offset = math.min(len * 0.12, cellW * 0.5);
  final margin = cellW * 0.15;
  final cp = mid + Offset(nx, ny) * offset;
  final outside = cp.dx < margin ||
      cp.dx > gridSize.width - margin ||
      cp.dy < margin ||
      cp.dy > gridSize.height - margin;
  return outside ? mid - Offset(nx, ny) * offset : cp;
}

class SudokuGridWidget extends StatefulWidget {
  const SudokuGridWidget({super.key, required this.controller});

  final GameController controller;

  @override
  State<SudokuGridWidget> createState() => _SudokuGridWidgetState();
}

class _SudokuGridWidgetState extends State<SudokuGridWidget> {
  GameController get controller => widget.controller;

  // Manual double-tap tracking (instead of GestureDetector.onDoubleTap) so
  // a plain single tap never pays Flutter's ~300ms tap/double-tap
  // disambiguation delay — that delay would apply to every tap on a cell
  // wired with onDoubleTap, i.e. every cell down to its last candidate,
  // which is exactly the cell players tap most.
  DateTime? _lastTapTime;
  int? _lastTapRow;
  int? _lastTapCol;
  static const _doubleTapThreshold = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    final hint = controller.visualizedHint;
    // With a step walkthrough active, the current step decides which units
    // are outlined (introducing them one at a time); otherwise the hint's
    // full sets are shown at once, as before.
    final step = controller.currentHintStep;
    final unitRows = step?.rows ?? hint?.highlightedRows ?? const <int>{};
    final unitCols = step?.cols ?? hint?.highlightedCols ?? const <int>{};
    final unitBoxes = step?.boxes ?? hint?.highlightedBoxes ?? const <int>{};
    final hasUnitHighlight =
        unitRows.isNotEmpty || unitCols.isNotEmpty || unitBoxes.isNotEmpty;
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.biggest.width / 9;
          return GestureDetector(
            // Deliberately no tap callbacks here — each cell keeps its own
            // GestureDetector(onTap: ...) for a plain tap. The gesture
            // arena lets that child tap recognizer win when there's no
            // movement (preserving the existing tap-to-toggle behavior
            // untouched) and lets this pan recognizer win once the finger
            // moves past the touch slop, so a drag is never also read as a
            // tap on the cell it started in.
            onPanStart: (details) => _handleDragSelect(
                details.localPosition, cellSize,
                playSound: true),
            onPanUpdate: (details) => _handleDragSelect(
                details.localPosition, cellSize,
                playSound: false),
            child: Stack(
              children: [
                Column(
                  children: List.generate(
                    9,
                    (row) => Expanded(
                      child: Row(
                        children: List.generate(
                          9,
                          (col) =>
                              Expanded(child: _buildCell(context, row, col)),
                        ),
                      ),
                    ),
                  ),
                ),
                // Painted as a single overlay (instead of a Border per cell)
                // so every line is pixel-snapped consistently — 81 separate
                // anti-aliased hairline borders each round sub-pixel cell
                // offsets differently, which is what made some lines fade
                // out or blur on Android.
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: SudokuGridLinesPainter(
                        innerColor: BoardColors.innerBorder(isDark),
                        outerColor: BoardColors.outerBorder(isDark),
                      ),
                    ),
                  ),
                ),
                if (hasUnitHighlight)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _UnitHighlightPainter(
                          rows: unitRows,
                          cols: unitCols,
                          boxes: unitBoxes,
                          color: BoardColors.unitHighlightBorder(isDark),
                        ),
                      ),
                    ),
                  ),
                if (hint != null &&
                    (hint.chainLinks.isNotEmpty ||
                        (step?.emphasisNodes.isNotEmpty ?? false)))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _HintArrowPainter(
                          hint: hint,
                          step: step,
                          color: BoardColors.hintArrow(isDark),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Converts a drag position (relative to the grid, [cellSize] square each)
  /// into a (row, col) and selects it — clamped to the grid bounds, so
  /// dragging past an edge just keeps the edge-most cell selected. No-op
  /// (including no haptic/sound) if the finger is still over the
  /// already-selected cell, so lingering within one cell during a drag
  /// doesn't repeatedly fire feedback. [playSound] is true only for the
  /// initial touch ([onPanStart]) — subsequent cells crossed while
  /// dragging ([onPanUpdate]) still get haptic feedback and update the
  /// selection, but stay silent, so a fast sweep doesn't retrigger the
  /// click sound on every cell.
  void _handleDragSelect(Offset localPosition, double cellSize,
      {required bool playSound}) {
    final row = (localPosition.dy / cellSize).floor().clamp(0, 8);
    final col = (localPosition.dx / cellSize).floor().clamp(0, 8);
    if (row == controller.selectedRow && col == controller.selectedCol) {
      return;
    }
    HapticService.selection();
    if (playSound) SoundService.click();
    controller.selectCellForDrag(row, col);
  }

  Widget _buildCell(BuildContext context, int row, int col) {
    final hint = controller.visualizedHint;
    final cell = HintCell(row, col);

    // While a hint is showing, selection-driven highlighting (selected
    // cell, its peers, same-value cells, same-value note highlights) is
    // suppressed entirely so only the hint's own red/green cues are
    // visible — otherwise a leftover selection blends confusingly with
    // the hint's coloring.
    final selectedRow = hint == null ? controller.selectedRow : null;
    final selectedCol = hint == null ? controller.selectedCol : null;
    final isSelected = selectedRow == row && selectedCol == col;
    final isPeer = !isSelected &&
        selectedRow != null &&
        selectedCol != null &&
        (selectedRow == row ||
            selectedCol == col ||
            (selectedRow ~/ 3 == row ~/ 3 && selectedCol ~/ 3 == col ~/ 3));
    final selectedValue = hint == null ? controller.selectedValue : null;
    final cellValue = controller.valueAt(row, col);

    // A reveal walkthrough introduces its reason cells first and holds the
    // fill-target highlight back until the conclusion step; without steps
    // everything shows at once, as before.
    final revealStep = hint != null && hint.type == HintType.reveal
        ? controller.currentHintStep
        : null;
    final isHintFillTarget = hint != null &&
        hint.type == HintType.reveal &&
        (revealStep == null || revealStep.showConclusion) &&
        hint.primaryCells.contains(cell);
    final isHintReasonCell = hint != null &&
        hint.type == HintType.reveal &&
        !isHintFillTarget &&
        (revealStep == null || revealStep.cells.contains(cell)) &&
        hint.secondaryCells.contains(cell);

    final isSameValue =
        !isSelected && cellValue != 0 && cellValue == selectedValue;
    final highlightedNotes = {
      if (selectedValue != null) selectedValue,
    };

    var hintRedNotes = const <int>{};
    var hintGreenNotes = const <int>{};
    var hintColorANotes = const <int>{};
    var hintColorBNotes = const <int>{};
    if (hint != null && hint.type == HintType.eliminate) {
      // During a step walkthrough, the current step decides which cells'
      // reason coloring is active and whether the red to-be-removed marks
      // are shown yet; without steps everything is visible at once.
      final step = controller.currentHintStep;
      final cellActive = step == null || step.cells.contains(cell);
      if (step == null || step.showConclusion) {
        hintRedNotes = {
          for (final e in hint.eliminations)
            if (e.row == row && e.col == col) e.digit,
        };
      }
      final reasonDigits = {
        ...hint.eliminations.map((e) => e.digit),
        ...hint.primaryDigits,
      };
      final usesColorGroups =
          hint.colorGroupA.isNotEmpty || hint.colorGroupB.isNotEmpty;
      if (usesColorGroups) {
        if (cellActive && hint.colorGroupA.contains(cell)) {
          hintColorANotes = reasonDigits;
        }
        if (cellActive && hint.colorGroupB.contains(cell)) {
          hintColorBNotes = reasonDigits;
        }
      } else if (cellActive && hint.primaryCells.contains(cell)) {
        hintGreenNotes = reasonDigits;
      }
    }

    final isConflictFlash = controller.conflictFlashCells.contains(cell);
    final notes = controller.notesAt(row, col);

    return SudokuCellWidget(
      value: cellValue,
      isFixed: controller.isFixed(row, col),
      isSelected: isSelected,
      isWrong: controller.isWrong(row, col),
      isPeerHighlighted: isPeer,
      isSameValueHighlighted: isSameValue,
      isHintFillTarget: isHintFillTarget,
      isHintReasonCell: isHintReasonCell,
      isConflictFlash: isConflictFlash,
      notes: notes,
      highlightedNotes: highlightedNotes,
      hintRedNotes: hintRedNotes,
      hintGreenNotes: hintGreenNotes,
      hintColorANotes: hintColorANotes,
      hintColorBNotes: hintColorBNotes,
      onTap: () => _onCellTap(row, col, notes),
    );
  }

  /// Single onTap handler covering both plain selection and "double tap a
  /// cell with exactly one candidate note to commit it" — done by hand
  /// (comparing consecutive tap timestamps) instead of also wiring
  /// GestureDetector.onDoubleTap, since a widget with both callbacks makes
  /// every single tap wait out the double-tap disambiguation window before
  /// firing. Plain taps must stay instant.
  void _onCellTap(int row, int col, Set<int> notes) {
    final now = DateTime.now();
    final isDoubleTap = row == _lastTapRow &&
        col == _lastTapCol &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapThreshold;
    _lastTapRow = row;
    _lastTapCol = col;
    _lastTapTime = now;

    if (isDoubleTap && notes.length == 1) {
      // A cell left with exactly one candidate note is, in practice,
      // already solved — commits it directly instead of requiring
      // select-then-tap-the-number-pad. Reuses selectCellForDrag (not
      // selectCell) so this never toggles the cell back to unselected if
      // it already happened to be the active one.
      HapticService.selection();
      SoundService.click();
      controller.selectCellForDrag(row, col);
      controller.inputValue(notes.single);
      _lastTapTime = null;
      return;
    }

    HapticService.selection();
    SoundService.click();
    controller.selectCell(row, col);
  }
}

/// Draws an emphasized rectangle around each highlighted row/column/box —
/// one `drawRect` per unit, so multiple simultaneously-highlighted units
/// (e.g. X-Wing's 2 rows + 2 cols) naturally overlap into a lattice rather
/// than needing per-cell edge-merging logic.
class _UnitHighlightPainter extends CustomPainter {
  const _UnitHighlightPainter({
    required this.rows,
    required this.cols,
    required this.boxes,
    required this.color,
  });

  final Set<int> rows;
  final Set<int> cols;
  final Set<int> boxes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 9;
    final cellH = size.height / 9;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;
    for (final r in rows) {
      canvas.drawRect(Rect.fromLTWH(0, r * cellH, size.width, cellH), paint);
    }
    for (final c in cols) {
      canvas.drawRect(Rect.fromLTWH(c * cellW, 0, cellW, size.height), paint);
    }
    for (final b in boxes) {
      canvas.drawRect(
        Rect.fromLTWH(
          (b % 3) * 3 * cellW,
          (b ~/ 3) * 3 * cellH,
          3 * cellW,
          3 * cellH,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UnitHighlightPainter old) =>
      old.rows != rows ||
      old.cols != cols ||
      old.boxes != boxes ||
      old.color != color;
}

/// Draws the chain overlay for a chain-based eliminate hint — XY-Chain and
/// the single-digit chains (Skyscraper / 2-String Kite / Turbot Fish), i.e.
/// the ones that carry a [Hint.chainPath]. Fish/subset/pointing/wing/UR hints
/// draw no overlay. The chain is a polyline through each node's candidate
/// position (a single-digit chain routes to that digit's note slot; a
/// multi-digit XY-Chain routes to cell centers), with **strong links solid
/// and weak links dashed** ([Hint.chainStrongLinks]), a ring at each node,
/// and a faint dashed connector from each convergence source (the chain's
/// two ends, unless [Hint.elimSources] overrides them) to the candidate(s)
/// it helps eliminate. Same square [Size] as the other overlays, so
/// `cellW = size.width / 9`, `cellH = size.height / 9` map identically.
class _HintArrowPainter extends CustomPainter {
  const _HintArrowPainter({required this.hint, this.step, required this.color});

  final Hint hint;

  /// The walkthrough step currently shown, or null to draw the whole hint
  /// at once. A step limits the links to a prefix ([HintStep.visibleLinks]),
  /// gates the convergence connectors behind [HintStep.showConclusion],
  /// and adds bold emphasis rings at [HintStep.emphasisNodes].
  final HintStep? step;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final links = step == null
        ? hint.chainLinks
        : hint.chainLinks.take(step!.visibleLinks).toList();
    final emphasis = step?.emphasisNodes ?? const <HintChainNode>[];
    if (links.isEmpty && emphasis.isEmpty) return;
    final cellW = size.width / 9;
    final cellH = size.height / 9;
    // Kept under a sixth of a cell so a ring stays within its own candidate
    // slot (slots are a third of a cell) instead of bleeding into its
    // neighbours' — chains now anchor per-candidate, not per-cell.
    final radius = cellW * 0.15;

    // Every link end names its own digit, so a node always resolves to a
    // specific pencil mark. A grouped node (several cells acting as one
    // end) anchors at the centroid of its candidates.
    Offset node(HintChainNode n) {
      var sum = Offset.zero;
      for (final c in n.cells) {
        sum += _candidateCenter(c.row, c.col, n.digit, cellW, cellH);
      }
      return sum / n.cells.length.toDouble();
    }

    final linkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = color;

    for (final link in links) {
      final from = node(link.from);
      final to = node(link.to);
      final dir = to - from;
      final len = dir.distance;
      if (len < 1) continue;
      // Stop the segment at the node rings so it doesn't cross the digits —
      // but never trim away the whole link. Two nodes in the SAME cell (an
      // XY-Chain's own bivalue link) sit only a third of a cell apart, which
      // is less than two ring radii, so trimming by the full radius would
      // silently drop exactly the links that explain the chain.
      final u = dir / len;
      final trim = math.min(radius, len * 0.3);
      final a = from + u * trim;
      final b = to - u * trim;
      if (link.strong) {
        canvas.drawLine(a, b, linkPaint);
      } else {
        final cp = curveControlPoint(a, b, cellW, size);
        _drawDashedPath(
          canvas,
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(cp.dx, cp.dy, b.dx, b.dy),
          linkPaint,
        );
      }
    }

    // Convergence sources: the nodes whose "at least one of these is true"
    // conclusion kills the eliminated candidates. A linear chain's are its
    // two ends; hints whose sources aren't derivable that way (XYZ-Wing's
    // pivot z, X-Wing's four corners) name them via [Hint.elimSources].
    // Always derived from the FULL chain — a step's prefix slice must not
    // change which nodes count as the conclusion's sources.
    final sources = hint.elimSources ??
        (hint.chainLinks.isEmpty
            ? const <HintChainNode>[]
            : [hint.chainLinks.first.from, hint.chainLinks.last.to]);
    final showConclusion = step == null || step!.showConclusion;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    for (final n in {
      for (final link in links) ...[link.from, link.to],
      if (showConclusion) ...sources,
    }) {
      canvas.drawCircle(node(n), radius, ringPaint);
    }

    // Bold rings on the step's "look here now" candidates, drawn over the
    // regular ones.
    if (emphasis.isNotEmpty) {
      final emphasisPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..color = color;
      for (final n in emphasis) {
        canvas.drawCircle(node(n), radius * 1.15, emphasisPaint);
      }
    }

    if (!showConclusion) return;

    // Faint dashed connectors from the sources to each eliminated candidate
    // they see (the "this cell sees them all" conclusion).
    final elimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55);
    for (final e in hint.eliminations) {
      final target = _candidateCenter(e.row, e.col, e.digit, cellW, cellH);
      for (final source in _sourcesFor(e, sources.toSet(), node, target)) {
        final from = node(source);
        final dir = target - from;
        final len = dir.distance;
        if (len < radius + 3) continue;
        final u = dir / len;
        _drawDashedPath(
          canvas,
          Path()
            ..moveTo((from + u * radius).dx, (from + u * radius).dy)
            ..lineTo((target - u * 3).dx, (target - u * 3).dy),
          elimPaint,
        );
      }
    }
  }

  /// Which of [sources] get a convergence connector to elimination [e]. Only
  /// nodes whose every cell sees [e]'s cell (and isn't it) qualify at all.
  /// When the hint carries color groups (Simple Coloring), qualifying
  /// sources collapse to the single nearest one per group — a Rule 2
  /// elimination is seen by potentially the whole component, and one line
  /// from each color says "sees both colors" without burying the board.
  /// Sources in neither group (every other technique) are all kept.
  Iterable<HintChainNode> _sourcesFor(
    HintElimination e,
    Set<HintChainNode> sources,
    Offset Function(HintChainNode) node,
    Offset target,
  ) {
    final seeing = sources.where((s) =>
        !s.cells.any((c) => c.row == e.row && c.col == e.col) &&
        s.cells.every((c) => _sees(c.row, c.col, e.row, e.col)));
    if (hint.colorGroupA.isEmpty && hint.colorGroupB.isEmpty) return seeing;

    HintChainNode? nearestA;
    HintChainNode? nearestB;
    final rest = <HintChainNode>[];
    for (final s in seeing) {
      final group = s.cells.every(hint.colorGroupA.contains)
          ? hint.colorGroupA
          : s.cells.every(hint.colorGroupB.contains)
              ? hint.colorGroupB
              : null;
      if (group == null) {
        rest.add(s);
      } else if (identical(group, hint.colorGroupA)) {
        if (nearestA == null ||
            (node(s) - target).distance < (node(nearestA) - target).distance) {
          nearestA = s;
        }
      } else {
        if (nearestB == null ||
            (node(s) - target).distance < (node(nearestB) - target).distance) {
          nearestB = s;
        }
      }
    }
    return [if (nearestA != null) nearestA, if (nearestB != null) nearestB, ...rest];
  }

  /// Center of candidate [digit]'s slot in the cell's 3x3 notes grid
  /// (row-major, digit d at sub-row (d-1)~/3, sub-col (d-1)%3), matching
  /// `_NotesGrid` in sudoku_cell_widget.dart.
  Offset _candidateCenter(
          int row, int col, int digit, double cellW, double cellH) =>
      Offset(
        (col + ((digit - 1) % 3 + 0.5) / 3) * cellW,
        (row + ((digit - 1) ~/ 3 + 0.5) / 3) * cellH,
      );

  bool _sees(int r1, int c1, int r2, int c2) =>
      !(r1 == r2 && c1 == c2) &&
      (r1 == r2 || c1 == c2 || (r1 ~/ 3 == r2 ~/ 3 && c1 ~/ 3 == c2 ~/ 3));

  /// Dashes any [path], straight or curved — [ui.PathMetric.extractPath]
  /// walks it by arc length, which a point-to-point dash loop can't do once
  /// the segment is a bezier.
  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HintArrowPainter old) =>
      old.hint != hint || old.step != step || old.color != color;
}
