import 'package:flutter/material.dart';

import 'theme_pack.dart';

/// Light/dark color pairs for the Sudoku board widgets (cells, grid lines,
/// number pad, control buttons) — these are hardcoded outside of [Theme]
/// (unlike AppBar/dialogs/bottom sheets, which follow it automatically), so
/// this is the one place that maps every board color decision to a dark
/// counterpart. Each pair inverts lightness while keeping the same hue and
/// the same relative-contrast relationships (e.g. selected still reads
/// stronger than peer-highlighted in both themes).
///
/// Structural colors (cells, borders, digits, pads) delegate to the active
/// [ThemePack]; colors that carry gameplay meaning (hints, wrong-digit red,
/// neutral greys) stay fixed here so no skin can change what they mean.
class BoardColors {
  BoardColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static ThemePackColors _pack(bool d) => ThemePack.active.of(d);

  /// A muted "wash" for dark-mode cell highlights: blends [accent] at low
  /// opacity over the dark cell background instead of using a saturated
  /// shade directly, so highlights stay legible without being harsh.
  static Color _tintOnDark(Color accent, double opacity) =>
      Color.alphaBlend(accent.withValues(alpha: opacity), Colors.grey.shade900);

  // sudoku_cell_widget.dart
  static Color cellDefault(bool d) => _pack(d).cellDefault;

  /// Reveal-type hint (Full House / Naked Single / Hidden Single): the
  /// whole cell that needs to be filled.
  static Color cellHintFill(bool d) =>
      d ? _tintOnDark(const Color(0xFF00D9FF), 0.58) : const Color(0xFF8DEBFF);

  /// Reveal-type hint: the whole cell(s) that justify the fill.
  static Color cellHintReason(bool d) =>
      d ? _tintOnDark(const Color(0xFF64F5B6), 0.30) : const Color(0xFFD5FFED);
  static Color cellSelected(bool d) => _pack(d).cellSelected;
  static Color cellPeer(bool d) => _pack(d).cellPeer;
  static Color textWrong(bool d) => d ? Colors.red.shade300 : Colors.red;
  static Color textFixed(bool d) => _pack(d).textFixed;
  static Color textEntered(bool d) => _pack(d).textEntered;

  /// User-entered digit text when its cell is selected or same-value
  /// highlighted — white in both themes so it pops against the (now
  /// colored/tinted) highlight background instead of blending in as blue.
  static const Color textEnteredHighlighted = Colors.white;
  static Color noteHighlight(bool d) =>
      d ? _tintOnDark(Colors.blue, 0.7) : Colors.blue.shade200;

  /// Eliminate-type hint (Intersection / X-Wing): the specific candidate
  /// digit's note background that must be removed.
  static Color noteHintRemove(bool d) =>
      d ? _tintOnDark(Colors.red, 0.7) : Colors.red.shade200;

  /// Eliminate-type hint: the specific candidate digit's note background
  /// that justifies the removal.
  static Color noteHintReason(bool d) =>
      d ? _tintOnDark(Colors.green, 0.7) : Colors.green.shade200;
  static Color noteText(bool d) =>
      d ? Colors.grey.shade300 : Colors.grey.shade700;

  /// Eliminate-type hint (Simple Coloring / XY-Chain only): one of the two
  /// "opposite state" groups of the coloring/chain pattern — replaces the
  /// generic [noteHintReason] green for just these two techniques so both
  /// sides of the pattern read as distinct groups. See [noteHintColorB].
  static Color noteHintColorA(bool d) =>
      d ? _tintOnDark(Colors.purple, 0.7) : Colors.purple.shade200;

  /// The other of the two opposite-state groups; see [noteHintColorA].
  static Color noteHintColorB(bool d) =>
      d ? _tintOnDark(Colors.orange, 0.7) : Colors.orange.shade200;

  // sudoku_grid_widget.dart
  static Color outerBorder(bool d) => _pack(d).outerBorder;
  static Color innerBorder(bool d) => _pack(d).innerBorder;

  /// The emphasized border drawn around the row(s)/column(s)/box(es) a
  /// unit-confined hint is scoped to (Full House, Hidden Single, Naked/
  /// Hidden Pair/Triple/Quad, Intersection, X-Wing/Swordfish/Jellyfish,
  /// Finned/Sashimi X-Wing, Unique Rectangle). Teal — distinct from the
  /// blue/green/red/purple/orange already used for cell/note highlights.
  static Color unitHighlightBorder(bool d) =>
      d ? const Color(0xFF64F5B6) : const Color(0xFF007D62);

  /// The connective arrows an eliminate-type hint draws from its cause cells
  /// to the candidate(s) being removed. A bold amber directional line —
  /// distinct from the blue/green/red/purple/orange note fills and the teal
  /// unit border, and it reads as a line/arrow rather than a cell state.
  static Color hintArrow(bool d) =>
      d ? const Color(0xFFFFB74D) : const Color(0xFFB26A00);

  // number_pad_widget.dart
  static Color remainingCountText(bool d) => _pack(d).remainingCountText;
  static Color padTextDisabled(bool d) =>
      d ? Colors.grey.shade600 : Colors.grey.shade400;
  static Color padTextNote(bool d) =>
      d ? Colors.grey.shade300 : Colors.grey.shade600;
  static Color padTextValue(bool d) => _pack(d).textEntered;
  static Color padBgDisabled(bool d) => _pack(d).padBgDisabled;
  static Color padBgNote(bool d) => _pack(d).padBgNote;
  static Color padBgValue(bool d) => _pack(d).padBgValue;

  // game_controls_row.dart
  static Color controlIconDefault(bool d) => _pack(d).textEntered;
  static Color controlIconDisabled(bool d) =>
      d ? Colors.grey.shade600 : Colors.grey.shade400;
  static Color controlCircleBgDisabled(bool d) =>
      d ? Colors.grey.shade800 : Colors.grey.shade100;
  static Color controlCircleBaseColor(bool d) => _pack(d).accent;
  static double controlCircleBgAlpha(bool d) => d ? 0.20 : 0.12;
  static Color adBadgeBorder(bool d) => d ? Colors.grey.shade900 : Colors.white;
}
