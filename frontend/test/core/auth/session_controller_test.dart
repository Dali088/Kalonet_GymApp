import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/auth/refresh_token_store.dart';
import 'package:kalonet_frontend/core/auth/session_providers.dart';
import 'package:kalonet_frontend/core/auth/session_tokens.dart';

void main() {
  test(
    'publishes access state while persisting only the refresh token',
    () async {
      final store = FakeRefreshTokenStore();
      final container = ProviderContainer(
        overrides: [refreshTokenStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final controller = container.read(sessionControllerProvider.notifier);
      await controller.establish(_tokens);

      final state = container.read(sessionControllerProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.accessToken, 'access-123');
      expect(state.user?.email, 'karim@example.com');
      expect(store.value, 'refresh-456');

      await controller.clear();
      expect(
        container.read(sessionControllerProvider).isAuthenticated,
        isFalse,
      );
      expect(store.value, isNull);
    },
  );
}

final _tokens = SessionTokens(
  accessToken: 'access-123',
  refreshToken: 'refresh-456',
  accessTokenExpiresInSeconds: 900,
  refreshTokenExpiresAt: DateTime.utc(2026, 9, 1, 12),
  user: SessionUser(
    id: 'user-1',
    email: 'karim@example.com',
    onboardingCompleted: false,
  ),
);

final class FakeRefreshTokenStore implements RefreshTokenStore {
  String? value;

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String refreshToken) async {
    value = refreshToken;
  }
}
