import 'package:flutter/material.dart';

import '../models/sudoku_puzzle.dart';
import '../theme/board_colors.dart';

/// A static, non-interactive rendering of [puzzle]'s starting board — no
/// selection/notes/hint/mistake state and no tap handling, just the givens.
/// Used for the home screen's difficulty-picker preview.
class SudokuPreviewBoard extends StatelessWidget {
  const SudokuPreviewBoard({super.key, required this.puzzle});

  final SudokuPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: BoardColors.outerBorder(isDark), width: 2),
        ),
        child: Column(
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
      ),
    );
  }

  Widget _buildCell(bool isDark, int row, int col) {
    final value = puzzle.puzzle.get(row, col);
    return Container(
      decoration: BoxDecoration(
        color: BoardColors.cellDefault(isDark),
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
      child: value == 0
          ? null
          : Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: BoardColors.textFixed(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
    );
  }
}
