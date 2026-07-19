import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/widgets/rating_trend_chart.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<int> values) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: RatingTrendChart(values: values, color: const Color(0xFF2563EB)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('paints a multi-point series without error', (tester) async {
    await pump(tester, const [1200, 1216, 1231, 1223, 1248]);
    expect(find.byType(RatingTrendChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints a flat (all-equal) series without dividing by zero',
      (tester) async {
    await pump(tester, const [1200, 1200]);
    expect(tester.takeException(), isNull);
  });
}
