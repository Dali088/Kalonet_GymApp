import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';
import 'package:kalonet_frontend/features/auth/authentication_api.dart';
import 'package:kalonet_frontend/features/auth/authentication_models.dart';

void main() {
  test(
    'register sends the contract request and parses session tokens',
    () async {
      final adapter = RecordingAdapter(
        response: {
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
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
        ..httpClientAdapter = adapter;
      final api = AuthenticationApi(
        client: ApiClient(
          config: const AppConfig(apiBaseUrl: 'http://test/api/v1'),
          dio: dio,
        ),
      );

      final tokens = await api.register(
        const RegistrationRequest(
          email: 'karim@example.com',
          password: 'correct-horse-battery-staple',
        ),
      );

      expect(adapter.method, 'POST');
      expect(adapter.uri?.path, '/api/v1/auth/registrations');
      expect(adapter.data, {
        'email': 'karim@example.com',
        'password': 'correct-horse-battery-staple',
      });
      expect(tokens.accessToken, 'access-123');
      expect(tokens.refreshToken, 'refresh-456');
    },
  );

  test('login sends the contract request and parses session tokens', () async {
    final adapter = RecordingAdapter(
      statusCode: 200,
      response: {
        'access_token': 'access-789',
        'refresh_token': 'refresh-012',
        'token_type': 'bearer',
        'access_token_expires_in_seconds': 900,
        'refresh_token_expires_at': '2026-09-01T12:00:00Z',
        'user': {
          'id': 'user-1',
          'email': 'karim@example.com',
          'onboarding_completed': true,
        },
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
      ..httpClientAdapter = adapter;
    final api = AuthenticationApi(
      client: ApiClient(
        config: const AppConfig(apiBaseUrl: 'http://test/api/v1'),
        dio: dio,
      ),
    );

    final tokens = await api.login(
      const LoginRequest(
        email: 'karim@example.com',
        password: 'correct-horse-battery-staple',
      ),
    );

    expect(adapter.method, 'POST');
    expect(adapter.uri?.path, '/api/v1/auth/sessions');
    expect(adapter.data, {
      'email': 'karim@example.com',
      'password': 'correct-horse-battery-staple',
    });
    expect(tokens.accessToken, 'access-789');
    expect(tokens.refreshToken, 'refresh-012');
    expect(tokens.user.onboardingCompleted, isTrue);
  });

  test(
    'refresh sends the contract request and parses rotated session tokens',
    () async {
      final adapter = RecordingAdapter(
        statusCode: 200,
        response: {
          'access_token': 'access-refresh',
          'refresh_token': 'refresh-rotated',
          'token_type': 'bearer',
          'access_token_expires_in_seconds': 900,
          'refresh_token_expires_at': '2026-09-01T12:00:00Z',
          'user': {
            'id': 'user-1',
            'email': 'karim@example.com',
            'onboarding_completed': true,
          },
        },
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
        ..httpClientAdapter = adapter;
      final api = AuthenticationApi(
        client: ApiClient(
          config: const AppConfig(apiBaseUrl: 'http://test/api/v1'),
          dio: dio,
        ),
      );

      final tokens = await api.refresh(
        const RefreshTokenRequest(refreshToken: 'refresh-old'),
      );

      expect(adapter.method, 'POST');
      expect(adapter.uri?.path, '/api/v1/auth/token-refreshes');
      expect(adapter.data, {'refresh_token': 'refresh-old'});
      expect(tokens.accessToken, 'access-refresh');
      expect(tokens.refreshToken, 'refresh-rotated');
    },
  );
}

final class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter({required this.response, this.statusCode = 201});

  final Map<String, dynamic> response;
  final int statusCode;
  String? method;
  Uri? uri;
  Object? data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    uri = options.uri;
    data = options.data;
    return ResponseBody.fromString(
      jsonEncode(response),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
