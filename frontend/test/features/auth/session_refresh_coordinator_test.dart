import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/auth/refresh_token_store.dart';
import 'package:kalonet_frontend/core/auth/session_providers.dart';
import 'package:kalonet_frontend/core/auth/session_tokens.dart';
import 'package:kalonet_frontend/core/errors/api_error.dart';
import 'package:kalonet_frontend/features/auth/authentication_api.dart';
import 'package:kalonet_frontend/features/auth/authentication_models.dart';
import 'package:kalonet_frontend/features/auth/session_refresh_coordinator.dart';

void main() {
  test('coalesces concurrent refresh requests into one rotation', () async {
    final store = _Store()..value = 'refresh-old';
    final container = ProviderContainer(
      overrides: [refreshTokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final gateway = _Gateway();
    final coordinator = SessionRefreshCoordinator(
      authentication: gateway,
      sessionController: container.read(sessionControllerProvider.notifier),
    );

    final first = coordinator.refreshAccessToken();
    final second = coordinator.refreshAccessToken();
    gateway.completer.complete(_tokens);

    expect(await first, 'access-new');
    expect(await second, 'access-new');
    expect(gateway.calls, 1);
    expect(store.value, 'refresh-new');
  });

  test('clears the session after refresh replay is rejected', () async {
    final store = _Store()..value = 'refresh-old';
    final container = ProviderContainer(
      overrides: [refreshTokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final gateway = _Gateway()
      ..error = const ApiError(
        code: 'refresh_token_reuse_detected',
        message: 'The refresh token was already used.',
        statusCode: 401,
      );
    final coordinator = SessionRefreshCoordinator(
      authentication: gateway,
      sessionController: container.read(sessionControllerProvider.notifier),
    );

    expect(await coordinator.refreshAccessToken(), isNull);
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).isAuthenticated, isFalse);
  });
}

final _tokens = SessionTokens(
  accessToken: 'access-new',
  refreshToken: 'refresh-new',
  accessTokenExpiresInSeconds: 900,
  refreshTokenExpiresAt: DateTime.utc(2026, 9, 1, 12),
  user: const SessionUser(
    id: 'user-1',
    email: 'learner@example.com',
    onboardingCompleted: false,
  ),
);

final class _Gateway implements AuthenticationGateway {
  final completer = Completer<SessionTokens>();
  ApiError? error;
  var calls = 0;

  @override
  Future<SessionTokens> refresh(RefreshTokenRequest request) {
    calls += 1;
    if (error != null) return Future.error(error!);
    return completer.future;
  }
}

final class _Store implements RefreshTokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String refreshToken) async => value = refreshToken;
}
