import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/network/access_token_interceptor.dart';

void main() {
  test('adds the current access token as a Bearer header', () {
    final interceptor = AccessTokenInterceptor(
      readAccessToken: () => 'access-123',
    );
    final options = RequestOptions(path: 'users/me');

    interceptor.apply(options);

    expect(options.headers['Authorization'], 'Bearer access-123');
  });

  test('removes a stale header when no access token is available', () {
    final interceptor = AccessTokenInterceptor(readAccessToken: () => null);
    final options = RequestOptions(
      path: 'users/me',
      headers: {'Authorization': 'Bearer old-token'},
    );

    interceptor.apply(options);

    expect(options.headers.containsKey('Authorization'), isFalse);
  });
}
