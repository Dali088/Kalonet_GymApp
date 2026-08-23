import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/auth/refresh_token_store.dart';
import 'package:kalonet_frontend/core/auth/session_providers.dart';
import 'package:kalonet_frontend/core/errors/api_error.dart';
import 'package:kalonet_frontend/features/auth/authentication_api.dart';
import 'package:kalonet_frontend/features/auth/authentication_models.dart';
import 'package:kalonet_frontend/features/auth/session_service.dart';

void main() {
  test('clears local credentials even when server logout fails', () async {
    final store = _Store()..value = 'refresh-old';
    final container = ProviderContainer(
      overrides: [refreshTokenStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final service = SessionService(
      authentication: _Actions(),
      sessionController: container.read(sessionControllerProvider.notifier),
    );

    await expectLater(service.logout(), throwsA(isA<ApiError>()));
    expect(store.value, isNull);
    expect(container.read(sessionControllerProvider).isAuthenticated, isFalse);
  });
}

final class _Actions implements AuthenticationActions {
  @override
  Future<void> completePasswordReset(
    PasswordResetCompletionRequest request,
  ) async {}

  @override
  Future<void> logout(LogoutRequest request) {
    return Future.error(
      const ApiError(code: 'network_unavailable', message: 'offline'),
    );
  }

  @override
  Future<String> requestPasswordReset(PasswordResetRequest request) async => '';
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
