import 'package:flutter/services.dart';

/// Centralized haptic feedback so every interaction picks from the same
/// small, consistent vocabulary instead of calling HapticFeedback directly
/// (and inventing a different strength) at each call site.
class HapticService {
  HapticService._();

  /// Global on/off gate, driven by the user's haptics setting.
  static bool enabled = true;

  /// Selecting/toggling something — cell tap, note tap that succeeds.
  static void selection() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  /// A minor confirmed action — correct value entered, undo, erase.
  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  /// A more significant confirmed action — hint applied, auto-fill notes.
  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Rejection/failure — wrong value, blocked note (conflict flash), game over.
  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// A stronger, longer celebratory buzz — winning the puzzle. Flutter's
  /// HapticFeedback has no custom-duration API, so this fakes "longer" with
  /// a quick triple pulse instead of a single impact.
  static Future<void> celebrate() async {
    if (!enabled) return;
    for (var i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      if (i < 2) await Future.delayed(const Duration(milliseconds: 120));
    }
  }
}
