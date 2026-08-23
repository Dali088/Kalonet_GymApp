import 'package:dio/dio.dart';

final class ApiErrorDetail {
  const ApiErrorDetail({required this.message, this.field});

  final String? field;
  final String message;
}

/// Stable client-side representation of a failed Kalonet request.
final class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.details = const [],
  });

  factory ApiError.fromDioException(DioException exception) {
    final response = exception.response;
    if (response != null) {
      final responseRequestId = response.headers.value('x-request-id');
      return ApiError.fromResponse(
        statusCode: response.statusCode,
        data: response.data,
        fallbackRequestId: responseRequestId,
      );
    }

    final isCancelled = exception.type == DioExceptionType.cancel;
    return ApiError(
      code: isCancelled ? 'request_cancelled' : 'network_unavailable',
      message: isCancelled
          ? 'The request was cancelled.'
          : 'Unable to reach Kalonet. Check your connection and try again.',
    );
  }

  factory ApiError.fromResponse({
    required int? statusCode,
    required Object? data,
    String? fallbackRequestId,
  }) {
    if (data is Map) {
      final rawError = data['error'];
      if (rawError is Map) {
        final code = rawError['code'];
        final message = rawError['message'];
        if (code is String &&
            code.isNotEmpty &&
            message is String &&
            message.isNotEmpty) {
          return ApiError(
            code: code,
            message: message,
            statusCode: statusCode,
            requestId: rawError['request_id'] is String
                ? rawError['request_id'] as String
                : fallbackRequestId,
            details: _parseDetails(rawError['details']),
          );
        }
      }
    }

    return ApiError(
      code: 'api_request_failed',
      message: 'Kalonet could not complete the request.',
      statusCode: statusCode,
      requestId: fallbackRequestId,
    );
  }

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final List<ApiErrorDetail> details;

  static List<ApiErrorDetail> _parseDetails(Object? rawDetails) {
    if (rawDetails is! List) {
      return const [];
    }

    final details = <ApiErrorDetail>[];
    for (final rawDetail in rawDetails) {
      if (rawDetail is! Map) {
        continue;
      }

      final message = rawDetail['message'];
      if (message is! String || message.isEmpty) {
        continue;
      }

      final field = rawDetail['field'];
      details.add(
        ApiErrorDetail(field: field is String ? field : null, message: message),
      );
    }
    return details;
  }

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiError$status [$code]: $message';
  }
}
