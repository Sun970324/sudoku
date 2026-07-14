import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/sudoku_puzzle.dart';
import '../services/puzzle_share_service.dart';

void showPuzzleShareDialog(BuildContext context, {required SudokuPuzzle puzzle}) {
  final l10n = AppLocalizations.of(context)!;
  final textCode = PuzzleShareService().encodeText(puzzle);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.shareCodeTitle),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: SelectableText(textCode,
                style: const TextStyle(fontFamily: 'monospace')),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: textCode));
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(l10n.copiedToClipboard)),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.closeAction),
        ),
      ],
    ),
  );
}
