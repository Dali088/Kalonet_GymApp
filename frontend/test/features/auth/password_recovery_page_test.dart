import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/features/auth/presentation/forgot_password_page.dart';
import 'package:kalonet_frontend/features/auth/presentation/reset_password_page.dart';

void main() {
  testWidgets('forgot-password validates the email before networking', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ForgotPasswordPage())),
    );
    await tester.tap(find.text('Send instructions'));
    await tester.pump();

    expect(find.text('Enter a valid email.'), findsOneWidget);
  });

  testWidgets('reset-password validates confirmation and token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ResetPasswordPage(resetToken: null)),
      ),
    );
    await tester.tap(find.text('Change password'));
    await tester.pump();

    expect(
      find.text('This password-reset link is missing its token.'),
      findsOneWidget,
    );
  });
}
