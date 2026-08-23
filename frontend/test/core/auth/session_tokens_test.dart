import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/auth/session_tokens.dart';

void main() {
  test('parses the shared authentication representation', () {
    final tokens = SessionTokens.fromJson({
      'access_token': 'access-123',
      'refresh_token': 'refresh-456',
      'token_type': 'bearer',
      'access_token_expires_in_seconds': 900,
      'refresh_token_expires_at': '2026-09-01T12:00:00Z',
      'user': {
        'id': 'user-1',
        'email': 'karim@example.com',
        'onboarding_completed': false,
      },
    });

    expect(tokens.accessToken, 'access-123');
    expect(tokens.refreshToken, 'refresh-456');
    expect(tokens.accessTokenExpiresInSeconds, 900);
    expect(tokens.refreshTokenExpiresAt.isUtc, isTrue);
    expect(tokens.user.email, 'karim@example.com');
  });

  test('rejects a malformed authentication representation', () {
    expect(
      () => SessionTokens.fromJson({'token_type': 'basic'}),
      throwsA(isA<FormatException>()),
    );
  });
}
