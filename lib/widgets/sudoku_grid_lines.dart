import 'package:flutter/material.dart';

/// Fills the given [Size] with a 9x9 sudoku grid's lines (outer border, 3x3
/// box separators, thin cell separators) in a single pass with
/// anti-aliasing off, so each line snaps to a whole device pixel instead of
/// 81 independently-rounded per-cell `Border`s — the latter approach left
/// some lines fading out or looking blurry depending on where each cell's
/// fractional edge landed.
class SudokuGridLinesPainter extends CustomPainter {
  const SudokuGridLinesPainter({
    required this.outerColor,
    required this.innerColor,
  });

  final Color outerColor;
  final Color innerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / 9;
    final cellH = size.height / 9;
    final thinPaint = Paint()
      ..color = innerColor
      ..strokeWidth = 1
      ..isAntiAlias = false;
    final thickPaint = Paint()
      ..color = innerColor
      ..strokeWidth = 2
      ..isAntiAlias = false;
    final outerPaint = Paint()
      ..color = outerColor
      ..strokeWidth = 2
      ..isAntiAlias = false;

    for (var i = 0; i <= 9; i++) {
      final paint = (i == 0 || i == 9)
          ? outerPaint
          : (i % 3 == 0 ? thickPaint : thinPaint);
      final x = i * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = i * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SudokuGridLinesPainter old) =>
      old.outerColor != outerColor || old.innerColor != innerColor;
}
