import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/board_colors.dart';
import 'pixel_icon.dart';

class GameControlsRow extends StatelessWidget {
  const GameControlsRow({
    super.key,
    required this.canUndo,
    required this.onUndo,
    required this.canErase,
    required this.onErase,
    required this.isNoteMode,
    required this.onToggleNoteMode,
    this.onHint,
    this.canAutoFillNotes = false,
    this.onAutoFillNotes,
    this.showAssists = true,
    this.noteButtonKey,
    this.hintButtonKey,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final bool canErase;
  final VoidCallback onErase;
  final bool isNoteMode;
  final VoidCallback onToggleNoteMode;
  final VoidCallback? onHint;
  final bool canAutoFillNotes;
  final VoidCallback? onAutoFillNotes;

  /// Tutorial coach-mark anchors for the note-mode toggle and hint button.
  final Key? noteButtonKey;
  final Key? hintButtonKey;

  /// The rewarded-ad assist actions (auto-fill notes + hint). Hidden in
  /// races, which offer neither — leaving them visible showed a dead hint
  /// button and a misleading "plays an ad" badge.
  final bool showAssists;

  @override
  Widget build(BuildContext context) {
    final noteColor = isNoteMode ? Theme.of(context).colorScheme.primary : null;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: PixelIcons.undo,
          label: l10n.undoLabel,
          onPressed: canUndo ? onUndo : null,
        ),
        _ControlButton(
          icon: PixelIcons.backspace,
          label: l10n.eraseLabel,
          onPressed: canErase ? onErase : null,
        ),
        _ControlButton(
          key: noteButtonKey,
          icon: PixelIcons.editNote,
          label: l10n.noteLabel,
          onPressed: onToggleNoteMode,
          color: noteColor,
          bold: isNoteMode,
          noteModeBadge: isNoteMode,
        ),
        if (showAssists) ...[
          _ControlButton(
            icon: PixelIcons.magicWand,
            label: l10n.autoFillLabel,
            onPressed: canAutoFillNotes ? onAutoFillNotes : null,
            showAdBadge: true,
          ),
          _ControlButton(
            key: hintButtonKey,
            icon: PixelIcons.lightbulb,
            label: l10n.hintLabel,
            onPressed: onHint,
            showAdBadge: true,
          ),
        ],
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.bold = false,
    this.showAdBadge = false,
    this.noteModeBadge,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool bold;
  final bool showAdBadge;

  /// Null hides the badge entirely (every button except 메모). True/false
  /// shows an "ON"/"OFF" badge reflecting whether note mode is active.
  final bool? noteModeBadge;

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    final enabled = onPressed != null;
    final iconColor = !enabled
        ? BoardColors.controlIconDisabled(isDark)
        : (color ?? BoardColors.controlIconDefault(isDark));
    final backgroundColor = !enabled
        ? BoardColors.controlCircleBgDisabled(isDark)
        : (color ?? BoardColors.controlCircleBaseColor(isDark))
            .withValues(alpha: BoardColors.controlCircleBgAlpha(isDark));

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: Colors.transparent,
      ).copyWith(splashFactory: NoSplash.splashFactory),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: backgroundColor,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: iconColor.withValues(alpha: enabled ? 0.35 : 0.12),
                    ),
                  ),
                  child: Center(child: Icon(icon, color: iconColor, size: 20)),
                ),
              ),
              // Marks that this action plays a rewarded ad before running.
              if (showAdBadge)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.shade600,
                      border: Border.all(
                          color: BoardColors.adBadgeBorder(isDark), width: 1.5),
                    ),
                    child: const Icon(
                      PixelIcons.ad,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (noteModeBadge != null)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: noteModeBadge!
                          ? _darken(Theme.of(context).colorScheme.primary)
                          : Colors.grey.shade500,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: BoardColors.adBadgeBorder(isDark), width: 1),
                    ),
                    child: Text(
                      noteModeBadge! ? 'ON' : 'OFF',
                      style: const TextStyle(
                        fontSize: 8,
                        height: 1,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: bold ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  static Color _darken(Color color, [double amount = 0.2]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
