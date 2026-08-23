import 'package:dio/dio.dart';

/// Adds the current in-memory access token to outgoing API requests.
final class AccessTokenInterceptor extends Interceptor {
  AccessTokenInterceptor({required this.readAccessToken});

  final String? Function() readAccessToken;

  void apply(RequestOptions options) {
    final accessToken = readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      options.headers.remove('Authorization');
      return;
    }

    // FRONTEND-BACKEND: Protected Kalonet routes require Bearer access tokens.
    options.headers['Authorization'] = 'Bearer $accessToken';
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    apply(options);
    handler.next(options);
  }
}
