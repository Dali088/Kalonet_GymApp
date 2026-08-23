import 'package:dio/dio.dart';

import '../../core/auth/session_tokens.dart';
import '../../core/network/api_client.dart';
import 'authentication_models.dart';

/// Endpoint adapter for the authentication contract.
abstract interface class AuthenticationGateway {
  Future<SessionTokens> refresh(RefreshTokenRequest request);
}

abstract interface class AuthenticationActions {
  Future<void> logout(LogoutRequest request);

  Future<String> requestPasswordReset(PasswordResetRequest request);

  Future<void> completePasswordReset(PasswordResetCompletionRequest request);
}

final class AuthenticationApi
    implements AuthenticationGateway, AuthenticationActions {
  AuthenticationApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  Future<SessionTokens> register(RegistrationRequest request) async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/auth/registrations.
    final response = await _client.post<Object?>(
      'auth/registrations',
      data: request.toJson(),
      options: _skipAuthRefresh,
    );

    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid registration response.');
    }

    return SessionTokens.fromJson(Map<String, dynamic>.from(body));
  }

  Future<SessionTokens> login(LoginRequest request) async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/auth/sessions.
    final response = await _client.post<Object?>(
      'auth/sessions',
      data: request.toJson(),
      options: _skipAuthRefresh,
    );

    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid login response.');
    }

    return SessionTokens.fromJson(Map<String, dynamic>.from(body));
  }

  @override
  Future<SessionTokens> refresh(RefreshTokenRequest request) async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/auth/token-refreshes.
    final response = await _client.post<Object?>(
      'auth/token-refreshes',
      data: request.toJson(),
      options: _skipAuthRefresh,
    );

    final body = response.data;
    if (body is! Map) {
      throw const FormatException('Invalid refresh response.');
    }

    return SessionTokens.fromJson(Map<String, dynamic>.from(body));
  }

  @override
  Future<void> logout(LogoutRequest request) async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/auth/logout.
    await _client.post<Object?>(
      'auth/logout',
      data: request.toJson(),
      retryOnUnauthorized: true,
    );
  }

  @override
  Future<String> requestPasswordReset(PasswordResetRequest request) async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/auth/password-reset-requests.
    final response = await _client.post<Object?>(
      'auth/password-reset-requests',
      data: request.toJson(),
      options: _skipAuthRefresh,
    );
    final body = response.data;
    if (body is! Map || body['message'] is! String) {
      throw const FormatException('Invalid password-reset response.');
    }
    return body['message'] as String;
  }

  @override
  Future<void> completePasswordReset(
    PasswordResetCompletionRequest request,
  ) async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/auth/password-resets.
    await _client.post<Object?>(
      'auth/password-resets',
      data: request.toJson(),
      options: _skipAuthRefresh,
    );
  }

  static final _skipAuthRefresh = Options(
    extra: <String, Object>{'skip_auth_refresh': true},
  );
}
