import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/features/auth/authentication_models.dart';

void main() {
  test('serializes the registration contract fields', () {
    const request = RegistrationRequest(
      email: 'karim@example.com',
      password: 'correct-horse-battery-staple',
    );

    expect(request.toJson(), {
      'email': 'karim@example.com',
      'password': 'correct-horse-battery-staple',
    });
  });

  test('serializes the login contract fields', () {
    const request = LoginRequest(
      email: 'karim@example.com',
      password: 'correct-horse-battery-staple',
    );

    expect(request.toJson(), {
      'email': 'karim@example.com',
      'password': 'correct-horse-battery-staple',
    });
  });

  test('serializes the refresh-token contract field', () {
    const request = RefreshTokenRequest(refreshToken: 'refresh-456');

    expect(request.toJson(), {'refresh_token': 'refresh-456'});
  });
}
