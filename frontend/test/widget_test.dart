import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalonet_frontend/app/app.dart';

void main() {
  testWidgets('Kalonet app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(child: KalonetApp(restoreSession: () async => false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kalonet'), findsOneWidget);
  });
}
