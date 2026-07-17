import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/widgets/sudoku_grid_widget.dart';

/// A 9x9 grid of 40px cells — the same shape the painter sees.
const _cellW = 40.0;
const _grid = Size(_cellW * 9, _cellW * 9);

Offset _cp(Offset from, Offset to) =>
    curveControlPoint(from, to, _cellW, _grid);

void main() {
  group('curveControlPoint', () {
    test('bows perpendicular to the link, off its midpoint', () {
      // A horizontal link across the middle of the grid.
      const from = Offset(100, 180);
      const to = Offset(260, 180);

      final cp = _cp(from, to);

      // Perpendicular to a horizontal link means the bow is purely vertical,
      // and centered on the link.
      expect(cp.dx, closeTo(180, 0.001));
      expect(cp.dy, isNot(closeTo(180, 0.001)));
    });

    test('offset is 12% of a short link, capped at half a cell for long ones',
        () {
      const from = Offset(100, 180);
      final shortCp = _cp(from, const Offset(200, 180));
      // 100px link -> 12% = 12px, under the 20px cap.
      expect((shortCp.dy - 180).abs(), closeTo(12, 0.001));

      final longCp = _cp(const Offset(20, 180), const Offset(340, 180));
      // 320px link -> 12% = 38.4px, so the half-cell cap (20px) applies.
      expect((longCp.dy - 180).abs(), closeTo(_cellW * 0.5, 0.001));
    });

    test('a link and its reverse bow the same way, so they never cross', () {
      const a = Offset(100, 180);
      const b = Offset(260, 220);

      expect(_cp(a, b), _cp(b, a));
    });

    test('bows inward when the outward control point would leave the grid',
        () {
      // A link hugging the top edge: the canonical (downward) normal already
      // points inward here, so force the opposite case with a link along the
      // bottom edge instead.
      const from = Offset(100, 354);
      const to = Offset(260, 354);

      final cp = _cp(from, to);

      // A 160px link bows 19.2px. Outward (downward) would land at 373.2,
      // past the 354 bound of a 360px grid less its 6px margin, so it flips
      // upward instead.
      expect(cp.dy, lessThan(354));
      expect(cp.dy, closeTo(354 - 19.2, 0.001));
    });

    test('a zero-length link has no direction to bow along, so it stays put',
        () {
      const p = Offset(100, 100);

      expect(_cp(p, p), p);
    });

    test('the bow direction is canonical, not per-link: a vertical link bows '
        'right', () {
      // The normal is canonicalised to point down, or right when it is
      // horizontal — which is the case for a vertical link.
      final cp = _cp(const Offset(180, 100), const Offset(180, 260));

      expect(cp.dy, closeTo(180, 0.001));
      expect(cp.dx, closeTo(180 + 19.2, 0.001));
    });
  });
}
