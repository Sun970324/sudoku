import 'package:flutter/material.dart';

import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../theme/board_colors.dart';

class NumberPadWidget extends StatelessWidget {
  const NumberPadWidget({
    super.key,
    required this.controller,
    required this.isNotePad,
    required this.onNumberSelected,
    this.selectedNumber,
  });

  final GameController controller;
  final bool isNotePad;
  final ValueChanged<int> onNumberSelected;

  /// The digit rendered as active — quick input mode's pad-picked digit.
  /// Null (always, in cell-first mode) renders no button as active.
  final int? selectedNumber;

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    return Row(
      children: List.generate(9, (i) {
        final number = i + 1;
        final remaining = controller.remainingCount(number);
        final isComplete = remaining <= 0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isNotePad) ...[
                  Text(
                    '$remaining',
                    style: TextStyle(
                        fontFamily: AppTheme.systemFontFamily,
                        fontSize: 11,
                        // fontWeight: FontWeight.w600,
                        color: BoardColors.remainingCountText(isDark)),
                  ),
                  const SizedBox(height: 4),
                ],
                _NumberPadButton(
                  number: number,
                  enabled: !isComplete,
                  isNotePad: isNotePad,
                  isActive: number == selectedNumber,
                  onTap: () => onNumberSelected(number),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _NumberPadButton extends StatefulWidget {
  const _NumberPadButton({
    required this.number,
    required this.enabled,
    required this.isNotePad,
    required this.isActive,
    required this.onTap,
  });

  final int number;
  final bool enabled;
  final bool isNotePad;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_NumberPadButton> createState() => _NumberPadButtonState();
}

class _NumberPadButtonState extends State<_NumberPadButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    final primary = Theme.of(context).colorScheme.primary;
    final Color textColor;
    if (!widget.enabled) {
      textColor = BoardColors.padTextDisabled(isDark);
    } else if (widget.isActive) {
      // onPrimary, not hardcoded white: the active chip's background is
      // colorScheme.primary, and only its scheme-paired "on" color is
      // guaranteed readable on it in every theme pack (monochrome dark's
      // primary is near-white, where white text disappears).
      textColor = Theme.of(context).colorScheme.onPrimary;
    } else if (widget.isNotePad) {
      textColor = BoardColors.padTextNote(isDark);
    } else {
      textColor = BoardColors.padTextValue(isDark);
    }
    final Color backgroundColor;
    if (!widget.enabled) {
      backgroundColor = BoardColors.padBgDisabled(isDark);
    } else if (widget.isActive) {
      backgroundColor = primary;
    } else if (widget.isNotePad) {
      backgroundColor = BoardColors.padBgNote(isDark);
    } else {
      backgroundColor = BoardColors.padBgValue(isDark);
    }

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.enabled
                  ? (widget.isActive
                      ? Colors.white.withValues(alpha: 0.45)
                      : widget.isNotePad
                          ? Colors.white.withValues(alpha: 0.10)
                          : BoardColors.padTextValue(isDark)
                              .withValues(alpha: 0.35))
                  : Colors.transparent,
            ),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.26 : 0.12),
                      offset: const Offset(0, 3),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          height: 56,
          alignment: Alignment.center,
          child: Text(
            '${widget.number}',
            style: TextStyle(
              fontFamily: AppTheme.systemFontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
