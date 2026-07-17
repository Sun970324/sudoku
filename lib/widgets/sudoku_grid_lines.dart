import 'package:flutter/material.dart';

/// Fills the given [Size] with a 9x9 sudoku grid's lines in a single pass —
/// the inner separators (3x3 box lines and thin cell lines) with
/// anti-aliasing off, so each snaps to a whole device pixel instead of 81
/// independently-rounded per-cell `Border`s (that left some lines fading out
/// or blurry depending on where each cell's fractional edge landed).
///
/// [outerColor] is optional: when null the outer border is left to the
/// caller. The in-game grid (see `GameScreen`) does exactly that — it wraps
/// this painter in a [DecoratedBox] with a rounded [Border.all] and a
/// slightly smaller [ClipRRect]. Drawing a SQUARE outer border here too would
/// push its sharp corners outside that rounded clip, which is what left the
/// four corners looking broken. The home-screen preview board has no such
/// rounded frame, so it passes [outerColor] and this paints its (square,
/// unclipped) border.
class SudokuGridLinesPainter extends CustomPainter {
  const SudokuGridLinesPainter({
    required this.innerColor,
    this.outerColor,
  });

  final Color innerColor;
  final Color? outerColor;

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

    final outer = outerColor;
    if (outer != null) {
      // Four filled bands that overlap at the corners, so no corner can gap
      // (unlike a stroked rect or four butt-jointed lines). Anti-aliasing is
      // left on so a fractional board size doesn't drop the outermost
      // sub-pixel edge; the 2px thickness keeps it from fading the way a 1px
      // hairline would.
      const border = 2.0;
      final outerPaint = Paint()..color = outer;
      canvas
        ..drawRect(Rect.fromLTWH(0, 0, size.width, border), outerPaint)
        ..drawRect(
            Rect.fromLTWH(0, size.height - border, size.width, border),
            outerPaint)
        ..drawRect(Rect.fromLTWH(0, 0, border, size.height), outerPaint)
        ..drawRect(
            Rect.fromLTWH(size.width - border, 0, border, size.height),
            outerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SudokuGridLinesPainter old) =>
      old.innerColor != innerColor || old.outerColor != outerColor;
}
