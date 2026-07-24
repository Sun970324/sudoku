import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/board_colors.dart';
import 'pixel_icon.dart';

/// The bolt toggle that switches a board between cell-first and digit-first
/// (quick) input. Shared by the solo game and race screens. Background and
/// border stay constant across states; only the bolt's colour signals on/off
/// — grey when off, the control-icon colour (with a matching tint) when on.
class QuickInputToggle extends StatelessWidget {
  const QuickInputToggle({
    super.key,
    required this.active,
    required this.onToggle,
  });

  final bool active;

  /// Called with the requested new state when tapped.
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = BoardColors.isDark(context);
    return Tooltip(
      message: l10n.inputModeQuick,
      child: GestureDetector(
        onTap: () => onToggle(!active),
        child: Container(
          width: 25,
          height: 25,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? BoardColors.controlCircleBaseColor(isDark)
                    .withValues(alpha: BoardColors.controlCircleBgAlpha(isDark))
                : (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            PixelIcons.bolt,
            size: 15,
            color: active
                ? BoardColors.controlIconDefault(isDark)
                : BoardColors.controlIconDisabled(isDark),
          ),
        ),
      ),
    );
  }
}
