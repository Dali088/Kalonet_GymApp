/// Runtime configuration for the Flutter client.
final class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      // FRONTEND-BACKEND: The FastAPI client contract is rooted at /api/v1.
      apiBaseUrl: String.fromEnvironment(
        'KALONET_API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000/api/v1',
      ),
    );
  }

  final String apiBaseUrl;

  String get normalizedApiBaseUrl {
    final trimmed = apiBaseUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('KALONET_API_BASE_URL cannot be empty.');
    }

    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }
}
