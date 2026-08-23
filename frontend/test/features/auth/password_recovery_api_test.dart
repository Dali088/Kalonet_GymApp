import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';
import 'package:kalonet_frontend/features/auth/authentication_api.dart';
import 'package:kalonet_frontend/features/auth/authentication_models.dart';

void main() {
  test('sends the password-reset request contract', () async {
    final adapter = _Adapter({
      'message': 'If an account exists, check your email.',
    });
    final api = AuthenticationApi(client: _client(adapter));

    final message = await api.requestPasswordReset(
      const PasswordResetRequest(email: 'learner@example.com'),
    );

    expect(message, contains('If an account exists'));
    expect(adapter.uri?.path, '/api/v1/auth/password-reset-requests');
    expect(adapter.data, {'email': 'learner@example.com'});
  });

  test('sends the password-reset completion contract', () async {
    final adapter = _Adapter(const <String, dynamic>{}, statusCode: 204);
    final api = AuthenticationApi(client: _client(adapter));

    await api.completePasswordReset(
      const PasswordResetCompletionRequest(
        resetToken: 'one-time-token',
        newPassword: 'correct-horse-battery-staple',
      ),
    );

    expect(adapter.uri?.path, '/api/v1/auth/password-resets');
    expect(adapter.data, {
      'reset_token': 'one-time-token',
      'new_password': 'correct-horse-battery-staple',
    });
  });
}

ApiClient _client(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
    ..httpClientAdapter = adapter;
  return ApiClient(
    config: const AppConfig(apiBaseUrl: 'http://test/api/v1'),
    dio: dio,
  );
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.response, {this.statusCode = 202});

  final Map<String, dynamic> response;
  final int statusCode;
  Uri? uri;
  Object? data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
