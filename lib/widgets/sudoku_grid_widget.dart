import 'package:flutter/material.dart';

import '../models/hint.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../state/game_controller.dart';
import '../theme/board_colors.dart';
import 'sudoku_cell_widget.dart';

class SudokuGridWidget extends StatelessWidget {
  const SudokuGridWidget({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    final hint = controller.activeHint;
    final hasUnitHighlight = hint != null &&
        (hint.highlightedRows.isNotEmpty ||
            hint.highlightedCols.isNotEmpty ||
            hint.highlightedBoxes.isNotEmpty);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: BoardColors.outerBorder(isDark), width: 2),
        ),
        child: Stack(
          children: [
            Column(
              children: List.generate(
                9,
                (row) => Expanded(
                  child: Row(
                    children: List.generate(
                      9,
                      (col) => Expanded(child: _buildCell(context, row, col)),
                    ),
                  ),
                ),
              ),
            ),
            if (hasUnitHighlight)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _UnitHighlightPainter(
                      rows: hint.highlightedRows,
                      cols: hint.highlightedCols,
                      boxes: hint.highlightedBoxes,
                      color: BoardColors.unitHighlightBorder(isDark),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(BuildContext context, int row, int col) {
    final isDark = BoardColors.isDark(context);
    final hint = controller.activeHint;
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

    final isHintFillTarget = hint != null &&
        hint.type == HintType.reveal &&
        hint.primaryCells.contains(cell);
    final isHintReasonCell = hint != null &&
        hint.type == HintType.reveal &&
        !isHintFillTarget &&
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
      hintRedNotes = {
        for (final e in hint.eliminations)
          if (e.row == row && e.col == col) e.digit,
      };
      final reasonDigits = {
        ...hint.eliminations.map((e) => e.digit),
        ...hint.primaryDigits,
      };
      final usesColorGroups =
          hint.colorGroupA.isNotEmpty || hint.colorGroupB.isNotEmpty;
      if (usesColorGroups) {
        if (hint.colorGroupA.contains(cell)) hintColorANotes = reasonDigits;
        if (hint.colorGroupB.contains(cell)) hintColorBNotes = reasonDigits;
      } else if (hint.primaryCells.contains(cell)) {
        hintGreenNotes = reasonDigits;
      }
    }

    final isConflictFlash = controller.conflictFlashCells.contains(cell);

    return Container(
      decoration: BoxDecoration(
        // The outer grid Container already draws the rightmost/bottommost
        // edge, so skip it here to avoid a doubled-up border line.
        border: Border(
          right: col == 8
              ? BorderSide.none
              : BorderSide(
                  width: (col + 1) % 3 == 0 ? 2 : 0.5,
                  color: BoardColors.innerBorder(isDark),
                ),
          bottom: row == 8
              ? BorderSide.none
              : BorderSide(
                  width: (row + 1) % 3 == 0 ? 2 : 0.5,
                  color: BoardColors.innerBorder(isDark),
                ),
        ),
      ),
      child: SudokuCellWidget(
        value: cellValue,
        isFixed: controller.isFixed(row, col),
        isSelected: isSelected,
        isWrong: controller.isWrong(row, col),
        isPeerHighlighted: isPeer,
        isSameValueHighlighted: isSameValue,
        isHintFillTarget: isHintFillTarget,
        isHintReasonCell: isHintReasonCell,
        isConflictFlash: isConflictFlash,
        notes: controller.notesAt(row, col),
        highlightedNotes: highlightedNotes,
        hintRedNotes: hintRedNotes,
        hintGreenNotes: hintGreenNotes,
        hintColorANotes: hintColorANotes,
        hintColorBNotes: hintColorBNotes,
        onTap: () {
          HapticService.selection();
          SoundService.click();
          controller.selectCell(row, col);
        },
      ),
    );
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
