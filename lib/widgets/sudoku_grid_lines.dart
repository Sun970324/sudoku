import 'package:flutter/material.dart';

/// Fills the given [Size] with a 9x9 sudoku grid's lines: the inner
/// separators (3x3 box lines and thin cell lines) plus a square outer frame
/// — deliberately NOT rounded — around the whole grid. All drawn in a single
/// pass with anti-aliasing off, so every line snaps to a whole device pixel
/// instead of 81 independently-rounded per-cell `Border`s (that left some
/// lines fading out or blurry depending on where each cell's fractional
/// edge landed).
class SudokuGridLinesPainter extends CustomPainter {
  const SudokuGridLinesPainter({
    required this.innerColor,
    required this.outerColor,
  });

  final Color innerColor;
  final Color outerColor;

  static const _outerStrokeWidth = 2.0;

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

    for (var i = 1; i < 9; i++) {
      final paint = i % 3 == 0 ? thickPaint : thinPaint;
      final x = i * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      final y = i * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Square frame around the whole grid. A single stroked rect (rather
    // than four separate line segments) joins its own corners automatically
    // — no corner-gap workaround needed. Inset by half the stroke width so
    // the full stroke paints within [size] instead of being clipped by
    // whatever bounds the parent hands this painter.
    final outerPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _outerStrokeWidth
      ..isAntiAlias = false;
    canvas.drawRect(
      Rect.fromLTWH(
        _outerStrokeWidth / 2,
        _outerStrokeWidth / 2,
        size.width - _outerStrokeWidth,
        size.height - _outerStrokeWidth,
      ),
      outerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SudokuGridLinesPainter old) =>
      old.innerColor != innerColor || old.outerColor != outerColor;
}
