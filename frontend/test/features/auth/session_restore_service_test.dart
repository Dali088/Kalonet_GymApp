import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/auth/refresh_token_store.dart';
import 'package:kalonet_frontend/core/auth/session_providers.dart';
import 'package:kalonet_frontend/core/auth/session_tokens.dart';
import 'package:kalonet_frontend/core/errors/api_error.dart';
import 'package:kalonet_frontend/features/auth/authentication_api.dart';
import 'package:kalonet_frontend/features/auth/authentication_models.dart';
import 'package:kalonet_frontend/features/auth/session_restore_service.dart';

void main() {
  test('returns false without refreshing when no token is stored', () async {
    final store = FakeRefreshTokenStore();
    final container = _container(store);
    addTearDown(container.dispose);
    final gateway = FakeAuthenticationGateway();
    final service = _service(container, gateway);

    expect(await service.restore(), isFalse);
    expect(gateway.request, isNull);
  });

  test('rotates the stored token and publishes authenticated state', () async {
    final store = FakeRefreshTokenStore()..value = 'refresh-old';
    final container = _container(store);
    addTearDown(container.dispose);
    final gateway = FakeAuthenticationGateway()..response = _tokens;
    final service = _service(container, gateway);

    expect(await service.restore(), isTrue);
    expect(gateway.request?.refreshToken, 'refresh-old');
    expect(store.value, 'refresh-new');
    expect(container.read(sessionControllerProvider).accessToken, 'access-new');
  });

  test('clears local state when the refresh token is invalid', () async {
    final store = FakeRefreshTokenStore()..value = 'refresh-old';
    final container = _container(store);
    addTearDown(container.dispose);
    final gateway = FakeAuthenticationGateway()
      ..error = const ApiError(
        code: 'invalid_refresh_token',
        message: 'Refresh token is invalid.',
        statusCode: 401,
      );
    final service = _service(container, gateway);

    expect(await service.restore(), isFalse);
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).isAuthenticated, isFalse);
  });
}

ProviderContainer _container(FakeRefreshTokenStore store) {
  return ProviderContainer(
    overrides: [refreshTokenStoreProvider.overrideWithValue(store)],
  );
}

SessionRestoreService _service(
  ProviderContainer container,
  FakeAuthenticationGateway gateway,
) {
  return SessionRestoreService(
    authentication: gateway,
    sessionController: container.read(sessionControllerProvider.notifier),
  );
}

final _tokens = SessionTokens(
  accessToken: 'access-new',
  refreshToken: 'refresh-new',
  accessTokenExpiresInSeconds: 900,
  refreshTokenExpiresAt: DateTime.utc(2026, 9, 1, 12),
  user: const SessionUser(
    id: 'user-1',
    email: 'karim@example.com',
    onboardingCompleted: true,
  ),
);

final class FakeAuthenticationGateway implements AuthenticationGateway {
  RefreshTokenRequest? request;
  SessionTokens? response;
  ApiError? error;

  @override
  Future<SessionTokens> refresh(RefreshTokenRequest refreshRequest) async {
    request = refreshRequest;
    if (error != null) {
      throw error!;
    }
    return response!;
  }
}

final class FakeRefreshTokenStore implements RefreshTokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String refreshToken) async => value = refreshToken;
}
