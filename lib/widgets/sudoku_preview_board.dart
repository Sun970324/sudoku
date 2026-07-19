import 'package:flutter/material.dart';

import '../models/sudoku_puzzle.dart';
import '../theme/app_theme.dart';
import '../theme/board_colors.dart';
import 'sudoku_grid_lines.dart';

/// A static rendering of [puzzle]'s starting board — no notes/hint/mistake
/// state, just the givens, plus a purely visual tap-to-highlight selection
/// (no editing, no navigation). Used for the home screen's difficulty-picker
/// preview. A `null` [puzzle] (the next one is still being generated)
/// renders as an empty grid rather than leaving the caller to show a
/// loading placeholder instead.
class SudokuPreviewBoard extends StatefulWidget {
  const SudokuPreviewBoard({super.key, required this.puzzle});

  final SudokuPuzzle? puzzle;

  @override
  State<SudokuPreviewBoard> createState() => _SudokuPreviewBoardState();
}

class _SudokuPreviewBoardState extends State<SudokuPreviewBoard> {
  int? _selectedRow;
  int? _selectedCol;

  @override
  void didUpdateWidget(covariant SudokuPreviewBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different puzzle (difficulty scrolled to a new one) makes any
    // carried-over selection meaningless — drop it rather than highlighting
    // an unrelated cell in the new board.
    if (oldWidget.puzzle != widget.puzzle) {
      _selectedRow = null;
      _selectedCol = null;
    }
  }

  void _onCellTap(int row, int col) {
    setState(() {
      if (_selectedRow == row && _selectedCol == col) {
        _selectedRow = null;
        _selectedCol = null;
      } else {
        _selectedRow = row;
        _selectedCol = col;
      }
    });
  }

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
          // Painted as a single overlay (instead of a Border per cell) so
          // every line is pixel-snapped consistently — see
          // SudokuGridLinesPainter for why. IgnorePointer is required here:
          // CustomPaint.hitTestSelf defaults to true for any painter that
          // doesn't override hitTest, so without it this overlay (being on
          // top) swallows every tap before it reaches the cells' own
          // GestureDetectors underneath.
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
    final value = widget.puzzle?.puzzle.get(row, col) ?? 0;
    final isSelected = row == _selectedRow && col == _selectedCol;
    final selectedRow = _selectedRow;
    final selectedCol = _selectedCol;
    final isPeer = !isSelected &&
        selectedRow != null &&
        selectedCol != null &&
        (selectedRow == row ||
            selectedCol == col ||
            (selectedRow ~/ 3 == row ~/ 3 && selectedCol ~/ 3 == col ~/ 3));
    final selectedValue = selectedRow == null || selectedCol == null
        ? null
        : widget.puzzle?.puzzle.get(selectedRow, selectedCol);
    final isSameValue = !isSelected && value != 0 && value == selectedValue;
    final Color background;
    if (isSelected || isSameValue) {
      background = BoardColors.cellSelected(isDark);
    } else if (isPeer) {
      background = BoardColors.cellPeer(isDark);
    } else {
      background = BoardColors.cellDefault(isDark);
    }
    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      child: Container(
        color: background,
        child: value == 0
            ? null
            : Center(
                // Same fontSize as SudokuCellWidget's value text — cell
                // sizes between this preview and the real grid are now kept
                // equal, so matching the raw size here (rather than
                // FittedBox-scaling from the default) renders identically.
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontFamily: AppTheme.systemFontFamily,
                    fontSize: 28,
                    color: BoardColors.textFixed(isDark),
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                ),
              ),
      ),
    );
  }
}
