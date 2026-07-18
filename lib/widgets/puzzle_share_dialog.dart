import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/sudoku_puzzle.dart';
import '../services/puzzle_share_service.dart';
import 'copyable_code_box.dart';

void showPuzzleShareDialog(BuildContext context, {required SudokuPuzzle puzzle}) {
  final l10n = AppLocalizations.of(context)!;
  final textCode = PuzzleShareService().encodeText(puzzle);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(l10n.shareCodeTitle,
          style: const TextStyle(fontFamily: 'Jua')),
      content: CopyableCodeBox(code: textCode, fontSize: 14, letterSpacing: 1),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.closeAction),
        ),
      ],
    ),
  );
}
