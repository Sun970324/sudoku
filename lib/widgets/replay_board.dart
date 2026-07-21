import 'package:flutter/material.dart';

import '../models/sudoku_puzzle.dart';
import '../theme/app_theme.dart';
import '../theme/board_colors.dart';
import 'sudoku_grid_lines.dart';

/// A static, read-only rendering of one reconstructed replay step: committed
/// values (coloured given / correct / wrong) and pencil-mark notes, with the
/// just-changed cell tinted. No gestures, no editing — see ReplayPlayerScreen.
class ReplayBoard extends StatelessWidget {
  const ReplayBoard({
    super.key,
    required this.puzzle,
    required this.board,
    required this.notes,
    this.highlight,
  });

  final SudokuPuzzle puzzle;
  final List<List<int>> board;
  final List<List<Set<int>>> notes;

  /// The cell the current step just changed, tinted to draw the eye — null for
  /// steps without a single-cell change (auto-memo, hint eliminations).
  final ({int row, int col})? highlight;

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          Column(
            children: List.generate(
              9,
              (row) => Expanded(
                child: Row(
                  children: List.generate(
                    9,
                    (col) => Expanded(child: _buildCell(isDark, row, col)),
                  ),
                ),
              ),
            ),
          ),
          // Single pixel-snapped line overlay (see SudokuPreviewBoard); the
          // board takes no input so no IgnorePointer is strictly needed, but it
          // keeps the painter from ever intercepting a parent's gesture.
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
        ],
      ),
    );
  }

  Widget _buildCell(bool isDark, int row, int col) {
    final value = board[row][col];
    final isHighlight =
        highlight != null && highlight!.row == row && highlight!.col == col;
    final background = isHighlight
        ? BoardColors.cellSelected(isDark)
        : BoardColors.cellDefault(isDark);

    Widget? content;
    if (value != 0) {
      final Color color;
      if (puzzle.isFixed(row, col)) {
        color = BoardColors.textFixed(isDark);
      } else if (value == puzzle.solutionValue(row, col)) {
        color = BoardColors.textEntered(isDark);
      } else {
        color = BoardColors.textWrong(isDark);
      }
      content = Center(
        child: Text(
          '$value',
          style: TextStyle(
            fontFamily: AppTheme.systemFontFamily,
            fontSize: 28,
            color: color,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
    } else if (notes[row][col].isNotEmpty) {
      content = _buildNotes(isDark, notes[row][col]);
    }

    return Container(color: background, child: content);
  }

  Widget _buildNotes(bool isDark, Set<int> cellNotes) {
    final color = BoardColors.noteText(isDark);
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Column(
        children: List.generate(
          3,
          (r) => Expanded(
            child: Row(
              children: List.generate(3, (c) {
                final digit = r * 3 + c + 1;
                return Expanded(
                  child: cellNotes.contains(digit)
                      ? Center(
                          child: FittedBox(
                            child: Text(
                              '$digit',
                              style: TextStyle(
                                  fontSize: 10, color: color, height: 1.0),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
