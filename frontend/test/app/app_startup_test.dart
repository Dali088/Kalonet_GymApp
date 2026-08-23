import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/app/app.dart';

void main() {
  testWidgets('holds the app behind restoration while startup is pending', (
    WidgetTester tester,
  ) async {
    final restoration = Completer<bool>();

    await tester.pumpWidget(
      ProviderScope(
        child: KalonetApp(restoreSession: () => restoration.future),
      ),
    );

    expect(find.text('Restoring your session...'), findsOneWidget);
    expect(find.text('Kalonet'), findsNothing);

    restoration.complete(false);
    await tester.pumpAndSettle();

    expect(find.text('Kalonet'), findsOneWidget);
  });

  testWidgets('shows a retryable error when restoration fails', (
    WidgetTester tester,
  ) async {
    var attempts = 0;

    Future<bool> restore() async {
      attempts += 1;
      if (attempts == 1) {
        throw StateError('temporary failure');
      }
      return false;
    }

    await tester.pumpWidget(
      ProviderScope(child: KalonetApp(restoreSession: restore)),
    );
    await tester.pumpAndSettle();

    expect(find.text('We could not restore your session.'), findsOneWidget);
    expect(find.text('temporary failure'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Kalonet'), findsOneWidget);
  });
}
