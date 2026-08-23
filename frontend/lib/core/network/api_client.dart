import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/api_error.dart';
import 'access_token_interceptor.dart';

/// Shared HTTP boundary for requests to the Kalonet API.
final class ApiClient {
  ApiClient({
    required AppConfig config,
    Dio? dio,
    String? Function()? readAccessToken,
    Future<String?> Function()? refreshAccessToken,
  }) : _dio = dio ?? Dio(_optionsFor(config)) {
    _refreshAccessToken = refreshAccessToken;
    if (readAccessToken != null) {
      _dio.interceptors.add(
        AccessTokenInterceptor(readAccessToken: readAccessToken),
      );
    }
  }

  final Dio _dio;
  late final Future<String?> Function()? _refreshAccessToken;

  BaseOptions get options => _dio.options;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool retryOnUnauthorized = false,
  }) {
    // FRONTEND-BACKEND: `path` must be a route from kalonet-api-design.md.
    return _send(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool retryOnUnauthorized = false,
  }) {
    // FRONTEND-BACKEND: JSON request bodies and responses use the shared API client.
    return _send(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool retryOnUnauthorized = false,
  }) {
    return _send(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool retryOnUnauthorized = false,
  }) {
    return _send(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool retryOnUnauthorized = false,
  }) {
    return _send(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
      retryOnUnauthorized: retryOnUnauthorized,
    );
  }

  static BaseOptions _optionsFor(AppConfig config) {
    return BaseOptions(
      baseUrl: config.normalizedApiBaseUrl,
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const <String, dynamic>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.json,
    );
  }

  Future<Response<T>> _send<T>(
    Future<Response<T>> Function() request, {
    required bool retryOnUnauthorized,
  }) async {
    try {
      return await request();
    } on DioException catch (exception) {
      final apiError = ApiError.fromDioException(exception);
      final shouldRefresh =
          retryOnUnauthorized &&
          exception.response?.statusCode == 401 &&
          _refreshAccessToken != null &&
          exception.requestOptions.extra['skip_auth_refresh'] != true;

      if (!shouldRefresh) {
        throw apiError;
      }

      final refreshedAccessToken = await _refreshAccessToken();
      if (refreshedAccessToken == null || refreshedAccessToken.isEmpty) {
        throw apiError;
      }

      try {
        return await request();
      } on DioException catch (retryException) {
        throw ApiError.fromDioException(retryException);
      }
    }
  }
}
