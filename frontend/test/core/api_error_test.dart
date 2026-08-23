import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/errors/api_error.dart';

void main() {
  test('parses the standard Kalonet error envelope', () {
    final error = ApiError.fromResponse(
      statusCode: 422,
      data: {
        'error': {
          'code': 'validation_error',
          'message': 'Request validation failed.',
          'details': [
            {'field': 'password', 'message': 'Password is too short.'},
          ],
          'request_id': 'req_123',
        },
      },
    );

    expect(error.code, 'validation_error');
    expect(error.message, 'Request validation failed.');
    expect(error.statusCode, 422);
    expect(error.requestId, 'req_123');
    expect(error.details.single.field, 'password');
  });

  test('uses a safe fallback for an unexpected response shape', () {
    final error = ApiError.fromResponse(
      statusCode: 502,
      data: {'detail': 'provider internals should not leak'},
      fallbackRequestId: 'req_456',
    );

    expect(error.code, 'api_request_failed');
    expect(error.message, 'Kalonet could not complete the request.');
    expect(error.requestId, 'req_456');
  });
}
