import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/theme/kalonet_theme.dart';
import 'package:kalonet_frontend/core/widgets/kalonet_surface.dart';

void main() {
  Widget harness(Widget child) {
    return MaterialApp(
      theme: KalonetTheme.dark(),
      home: Scaffold(body: child),
    );
  }

  testWidgets('metric tile exposes the semantic metric content', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const KalonetMetricTile(
          icon: Icons.water_drop,
          label: 'Water',
          value: '1500 ml',
          detail: 'of 2000 ml',
        ),
      ),
    );

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('1500 ml'), findsOneWidget);
    expect(find.text('of 2000 ml'), findsOneWidget);
  });

  testWidgets('progress ring animates to a bounded value', (tester) async {
    await tester.pumpWidget(
      harness(const KalonetProgressRing(value: 1.4, label: '100%')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('error state exposes a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      harness(
        KalonetStatePanel.error(
          error: 'Unable to load progress.',
          onRetry: () => retried = true,
        ),
      ),
    );

    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
