import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A compact single-series line chart of a player's rating over time.
/// Single series, so no legend — the card title names it; only the first
/// and last points are directly labelled (never every point): each end's
/// rating above, and the earliest/latest race date below. [values] is the
/// full chronological series including the pre-first-race baseline, and must
/// hold at least two points. [dates] is aligned with [values] (same length),
/// with a null for the baseline point, which precedes any real race.
class RatingTrendChart extends StatelessWidget {
  const RatingTrendChart({
    super.key,
    required this.values,
    required this.dates,
    required this.color,
    this.height = 140,
  });

  final List<int> values;
  final List<DateTime?> dates;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _RatingTrendPainter(
          values: values,
          dates: dates,
          color: color,
          labelColor: labelColor,
        ),
      ),
    );
  }
}

class _RatingTrendPainter extends CustomPainter {
  _RatingTrendPainter({
    required this.values,
    required this.dates,
    required this.color,
    required this.labelColor,
  });

  final List<int> values;
  final List<DateTime?> dates;
  final Color color;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Leave headroom top/bottom for the endpoint value labels.
    const padX = 12.0;
    const padTop = 20.0;
    const padBottom = 20.0;
    final plotW = size.width - padX * 2;
    final plotH = size.height - padTop - padBottom;

    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (minV == maxV) {
      // Flat series — pad so the line sits mid-plot instead of dividing by 0.
      minV -= 1;
      maxV += 1;
    }

    Offset pointAt(int i) {
      final x = padX + (values.length == 1 ? 0 : i / (values.length - 1)) * plotW;
      final y = padTop + (1 - (values[i] - minV) / (maxV - minV)) * plotH;
      return Offset(x, y);
    }

    final points = [for (var i = 0; i < values.length; i++) pointAt(i)];

    // Area fill under the line — a soft vertical fade, gapped from the line
    // by drawing the stroke on top afterwards.
    final areaPath = Path()..moveTo(points.first.dx, size.height - padBottom);
    for (final p in points) {
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(points.last.dx, size.height - padBottom);
    areaPath.close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, padTop),
          Offset(0, size.height - padBottom),
          [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
        ),
    );

    // The line itself.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Endpoint dots.
    final dotPaint = Paint()..color = color;
    canvas.drawCircle(points.first, 3, dotPaint);
    canvas.drawCircle(points.last, 4, dotPaint);

    // Direct labels: first value above its dot, last value above its dot.
    _drawLabel(canvas, '${values.first}', points.first, size, alignEnd: false);
    _drawLabel(canvas, '${values.last}', points.last, size, alignEnd: true);

    // X-axis dates: earliest race date bottom-left, latest bottom-right (the
    // baseline point carries no date). One race → just the single date.
    final firstDate = dates.firstWhere((d) => d != null, orElse: () => null);
    final lastDate = dates.lastWhere((d) => d != null, orElse: () => null);
    if (firstDate != null) {
      _drawBottomLabel(canvas, _formatDate(firstDate), size, alignEnd: false);
    }
    if (lastDate != null && lastDate != firstDate) {
      _drawBottomLabel(canvas, _formatDate(lastDate), size, alignEnd: true);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}.${local.day}';
  }

  void _drawLabel(Canvas canvas, String text, Offset at, Size size,
      {required bool alignEnd}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelColor,
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx - tp.width / 2;
    dx = dx.clamp(0.0, size.width - tp.width);
    // Place the label above the dot, or below if the dot hugs the top edge.
    final aboveY = at.dy - tp.height - 6;
    final dy = aboveY < 0 ? at.dy + 6 : aboveY;
    tp.paint(canvas, Offset(dx, dy));
  }

  void _drawBottomLabel(Canvas canvas, String text, Size size,
      {required bool alignEnd}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignEnd ? size.width - tp.width : 0.0;
    tp.paint(canvas, Offset(dx, size.height - tp.height));
  }

  @override
  bool shouldRepaint(_RatingTrendPainter old) =>
      old.values != values ||
      old.dates != dates ||
      old.color != color ||
      old.labelColor != labelColor;
}
