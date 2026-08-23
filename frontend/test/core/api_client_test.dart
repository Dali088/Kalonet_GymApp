import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';

void main() {
  test('builds a shared Dio client with Kalonet defaults', () {
    final client = ApiClient(
      config: const AppConfig(apiBaseUrl: 'http://localhost:8000/api/v1'),
    );

    expect(client.options.baseUrl, 'http://localhost:8000/api/v1/');
    expect(client.options.connectTimeout, const Duration(seconds: 5));
    expect(client.options.receiveTimeout, const Duration(seconds: 10));
    expect(client.options.headers['Accept'], 'application/json');
    expect(client.options.responseType, ResponseType.json);
  });

  test('retries one protected request after an access-token refresh', () async {
    var requests = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
      ..httpClientAdapter = _UnauthorizedThenSuccessAdapter(
        onRequest: () => requests += 1,
      );
    final client = ApiClient(
      config: const AppConfig(apiBaseUrl: 'http://test/api/v1'),
      dio: dio,
      refreshAccessToken: () async => 'access-new',
    );

    final response = await client.get<Object?>(
      'users/me/profile',
      retryOnUnauthorized: true,
    );

    expect(response.statusCode, 200);
    expect(requests, 2);
  });
}

final class _UnauthorizedThenSuccessAdapter implements HttpClientAdapter {
  _UnauthorizedThenSuccessAdapter({required this.onRequest});

  final void Function() onRequest;
  var _requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest();
    _requestCount += 1;
    if (_requestCount == 1) {
      return ResponseBody.fromString(
        '{"error":{"code":"invalid_access_token","message":"expired"}}',
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
