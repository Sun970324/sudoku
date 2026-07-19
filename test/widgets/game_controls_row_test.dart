import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/l10n/generated/app_localizations.dart';
import 'package:sudoku/widgets/game_controls_row.dart';

Future<void> _pump(WidgetTester tester, {required bool showAssists}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: GameControlsRow(
        canUndo: true,
        onUndo: () {},
        canErase: true,
        onErase: () {},
        isNoteMode: false,
        onToggleNoteMode: () {},
        onHint: () {},
        canAutoFillNotes: true,
        onAutoFillNotes: () {},
        showAssists: showAssists,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows hint and auto-fill when showAssists is true',
      (tester) async {
    await _pump(tester, showAssists: true);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Auto Notes'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('hides hint and auto-fill in races (showAssists false)',
      (tester) async {
    await _pump(tester, showAssists: false);
    expect(find.text('Hint'), findsNothing);
    expect(find.text('Auto Notes'), findsNothing);
    // The core controls remain.
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Erase'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });
}
