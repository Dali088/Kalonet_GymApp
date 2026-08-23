import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';

void main() {
  test('normalizes the API base URL for Dio path joining', () {
    const config = AppConfig(apiBaseUrl: 'http://localhost:8000/api/v1');

    expect(config.normalizedApiBaseUrl, 'http://localhost:8000/api/v1/');
  });

  test('rejects an empty API base URL', () {
    const config = AppConfig(apiBaseUrl: '  ');

    expect(() => config.normalizedApiBaseUrl, throwsA(isA<FormatException>()));
  });
}
