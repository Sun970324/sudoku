import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

enum PopButtonVariant { primary, secondary, outline }

/// The app's game-style button: a filled rounded rect that bumps slightly
/// larger on press and eases back down on release — a short scale-only
/// pulse, no other property animates.
///
/// The label is always rendered as a plain [Text] — widget tests find
/// buttons by `find.text(...)`, so no RichText/painting tricks here.
class PopButton extends StatefulWidget {
  const PopButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.color,
    this.variant = PopButtonVariant.primary,
    this.expanded = false,
    this.fontSize = 18,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  /// Shows a small spinner in place of [icon] — e.g. while a puzzle queue
  /// tier is empty and being refilled in the background.
  final bool loading;

  /// Overrides the variant's fill (e.g. a difficulty/tier accent).
  /// Ignored by [PopButtonVariant.outline].
  final Color? color;
  final PopButtonVariant variant;

  /// Stretch to the available width (for stacked full-width actions).
  final bool expanded;
  final double fontSize;

  @override
  State<PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<PopButton> {
  static const _pressedScale = 1.06;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final isOutline = widget.variant == PopButtonVariant.outline;

    final Color face;
    final Gradient? gradient;
    final Color foreground;
    if (isOutline) {
      face = AppPalette.cardSurface(isDark);
      gradient = null;
      foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (widget.variant == PopButtonVariant.primary &&
        widget.color == null) {
      final colors = AppPalette.primaryGradient(isDark);
      face = colors.last;
      gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      );
      foreground = Colors.white;
    } else {
      face = widget.color ?? AppPalette.primaryGradient(isDark).last;
      gradient = null;
      foreground = Colors.white;
    }

    // FittedBox — not Flexible+ellipsis — absorbs a label too wide for the
    // button: it shrinks icon and text together until they fit, rather than
    // clipping the text. A short label (or any locale's translation of one)
    // renders at its natural fontSize, since scaleDown never enlarges.
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.loading) ...[
            SizedBox(
              width: widget.fontSize,
              height: widget.fontSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            ),
            const SizedBox(width: 8),
          ] else if (widget.icon != null) ...[
            Icon(widget.icon, color: foreground, size: widget.fontSize + 4),
            const SizedBox(width: 8),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'Jua',
              fontSize: widget.fontSize,
              color: foreground,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: _enabled ? 1 : 0.5,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? _pressedScale : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            width: widget.expanded ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: gradient == null ? face : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppDims.buttonRadius),
              border: isOutline
                  ? Border.all(
                      color: Theme.of(context).colorScheme.outline, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppPalette.cardShadow(isDark),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
