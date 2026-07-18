import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_palette.dart';

/// A tappable code display (room codes, puzzle share codes): monospace so
/// 0/O and 1/l can't be misread — deliberately NOT Jua — with tap-to-copy
/// and the shared "copied" snackbar.
class CopyableCodeBox extends StatelessWidget {
  const CopyableCodeBox({
    super.key,
    required this.code,
    this.fontSize = 28,
    this.letterSpacing = 8,
  });

  final String code;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = AppPalette.isDark(context);
    final accent = AppPalette.primaryGradient(isDark).last;
    return Material(
      color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(AppDims.fieldRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDims.fieldRadius),
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.copiedToClipboard)),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDims.fieldRadius),
            border: Border.all(color: accent.withValues(alpha: 0.45), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: letterSpacing,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy, size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
