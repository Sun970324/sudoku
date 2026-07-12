import 'package:flutter/material.dart';

import '../theme/board_colors.dart';

class SudokuCellWidget extends StatelessWidget {
  const SudokuCellWidget({
    super.key,
    required this.value,
    required this.isFixed,
    required this.isSelected,
    required this.isWrong,
    required this.isPeerHighlighted,
    required this.isSameValueHighlighted,
    required this.isHintFillTarget,
    required this.isHintReasonCell,
    required this.isConflictFlash,
    required this.notes,
    required this.highlightedNotes,
    required this.hintRedNotes,
    required this.hintGreenNotes,
    required this.hintColorANotes,
    required this.hintColorBNotes,
    required this.onTap,
  });

  final int value;
  final bool isFixed;
  final bool isSelected;
  final bool isWrong;
  final bool isPeerHighlighted;
  final bool isSameValueHighlighted;
  final bool isHintFillTarget;
  final bool isHintReasonCell;
  final bool isConflictFlash;
  final Set<int> notes;
  final Set<int> highlightedNotes;
  final Set<int> hintRedNotes;
  final Set<int> hintGreenNotes;
  final Set<int> hintColorANotes;
  final Set<int> hintColorBNotes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    final Color background;
    if (isHintFillTarget) {
      background = BoardColors.cellHintFill(isDark);
    } else if (isHintReasonCell) {
      background = BoardColors.cellHintReason(isDark);
    } else if (isSelected || isSameValueHighlighted) {
      background = BoardColors.cellSelected(isDark);
    } else if (isPeerHighlighted) {
      background = BoardColors.cellPeer(isDark);
    } else {
      background = BoardColors.cellDefault(isDark);
    }

    final isHighlightedSelection = isSelected || isSameValueHighlighted;
    final Color textColor;
    if (isConflictFlash || isWrong) {
      textColor = BoardColors.textWrong(isDark);
    } else if (isFixed) {
      textColor = BoardColors.textFixed(isDark);
    } else if (isHighlightedSelection) {
      textColor = BoardColors.textEnteredHighlighted;
    } else {
      textColor = BoardColors.textEntered(isDark);
    }

    Widget content;
    if (value != 0) {
      content = Text(
        '$value',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      );
    } else if (notes.isNotEmpty) {
      content = _NotesGrid(
        notes: notes,
        highlightedNotes: highlightedNotes,
        hintRedNotes: hintRedNotes,
        hintGreenNotes: hintGreenNotes,
        hintColorANotes: hintColorANotes,
        hintColorBNotes: hintColorBNotes,
      );
    } else {
      content = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: background,
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.notes,
    required this.highlightedNotes,
    required this.hintRedNotes,
    required this.hintGreenNotes,
    required this.hintColorANotes,
    required this.hintColorBNotes,
  });

  final Set<int> notes;
  final Set<int> highlightedNotes;
  final Set<int> hintRedNotes;
  final Set<int> hintGreenNotes;
  final Set<int> hintColorANotes;
  final Set<int> hintColorBNotes;

  @override
  Widget build(BuildContext context) {
    final isDark = BoardColors.isDark(context);
    return GridView.count(
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: List.generate(9, (i) {
        final digit = i + 1;
        final hasNote = notes.contains(digit);
        final Color? background;
        if (hasNote && hintRedNotes.contains(digit)) {
          background = BoardColors.noteHintRemove(isDark);
        } else if (hasNote && hintColorANotes.contains(digit)) {
          background = BoardColors.noteHintColorA(isDark);
        } else if (hasNote && hintColorBNotes.contains(digit)) {
          background = BoardColors.noteHintColorB(isDark);
        } else if (hasNote && hintGreenNotes.contains(digit)) {
          background = BoardColors.noteHintReason(isDark);
        } else if (hasNote && highlightedNotes.contains(digit)) {
          background = BoardColors.noteHighlight(isDark);
        } else {
          background = null;
        }
        return Container(
          color: background,
          alignment: Alignment.center,
          child: Text(
            hasNote ? '$digit' : '',
            style: TextStyle(
              fontSize: 10,
              color: BoardColors.noteText(isDark),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }),
    );
  }
}
