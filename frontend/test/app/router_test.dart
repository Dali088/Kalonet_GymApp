import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/app/router.dart';
import 'package:kalonet_frontend/core/auth/session_controller.dart';
import 'package:kalonet_frontend/core/auth/session_tokens.dart';

void main() {
  final user = SessionUser(
    id: 'user-1',
    email: 'learner@example.com',
    onboardingCompleted: false,
  );

  test('normalizes the Android password-reset deep link', () {
    expect(
      normalizeKalonetDeepLink(
        Uri.parse('kalonet://password-reset?token=one-time-token'),
      ),
      '/reset-password?token=one-time-token',
    );
  });

  test('normalizes a password-reset link without a token', () {
    expect(
      normalizeKalonetDeepLink(Uri.parse('kalonet://password-reset')),
      '/reset-password',
    );
  });

  test('does not rewrite ordinary application routes', () {
    expect(normalizeKalonetDeepLink(Uri.parse('/login')), isNull);
  });

  test('sends unauthenticated users away from protected routes', () {
    const session = SessionState.unauthenticated();

    expect(authRedirect(session: session, location: '/dashboard'), '/');
    expect(authRedirect(session: session, location: '/onboarding'), '/');
    expect(authRedirect(session: session, location: '/login'), isNull);
  });

  test('sends authenticated users to onboarding until it is complete', () {
    final session = SessionState.authenticated(
      accessToken: 'access-token',
      user: user,
    );

    expect(authRedirect(session: session, location: '/'), '/onboarding');
    expect(authRedirect(session: session, location: '/login'), '/onboarding');
  });

  test('allows authenticated users to open password reset links', () {
    final session = SessionState.authenticated(
      accessToken: 'access-token',
      user: user,
    );

    expect(authRedirect(session: session, location: '/reset-password'), isNull);
  });

  test('sends onboarded users to the dashboard', () {
    final session = SessionState.authenticated(
      accessToken: 'access-token',
      user: SessionUser(
        id: user.id,
        email: user.email,
        onboardingCompleted: true,
      ),
    );

    expect(authRedirect(session: session, location: '/'), '/dashboard');
    expect(authRedirect(session: session, location: '/register'), '/dashboard');
    expect(authRedirect(session: session, location: '/dashboard'), isNull);
  });
}
