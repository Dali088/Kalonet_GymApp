import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';
import 'package:kalonet_frontend/features/profile/profile_api.dart';

void main() {
  test('profile response preserves target inputs and schedule', () async {
    final api = ProfileApi(client: _client(_Adapter(_profileJson)));

    final profile = await api.profile();

    expect(profile.email, 'athlete@example.com');
    expect(
      profile.onboardingCompletedAt,
      DateTime.parse('2026-08-19T08:00:00Z').toLocal(),
    );
    expect(profile.inputs.weightKg, 80);
    expect(profile.target.dailyCalories, 2400);
    expect(profile.schedule.single.preferredTime, '08:00');
  });

  test('settings update maps to the settings endpoint', () async {
    final adapter = _Adapter(_settingsJson);
    final api = ProfileApi(client: _client(adapter));

    await api.updateSettings({'theme_preference': 'dark'});

    expect(adapter.method, 'PATCH');
    expect(adapter.uri?.path, '/api/v1/users/me/settings');
    expect(adapter.data, {'theme_preference': 'dark'});
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
  _Adapter(this.response);

  final Map<String, dynamic> response;
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
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _profileJson = <String, dynamic>{
  'user': {
    'id': 'user-1',
    'email': 'athlete@example.com',
    'onboarding_completed': true,
    'onboarding_completed_at': '2026-08-19T08:00:00Z',
  },
  'calculation_inputs': {
    'goal': 'weight_loss',
    'date_of_birth': '2000-01-01',
    'formula_sex': 'male',
    'height_cm': 180,
    'weight_kg': 80,
    'activity_level': 'moderately_active',
  },
  'current_nutrition_target': {
    'id': 'target-1',
    'daily_calories': 2400,
    'protein_g': 160,
    'carbohydrate_g': 280,
    'fat_g': 80,
    'effective_from': '2026-08-19',
    'rule_version': '1.0',
    'is_active': true,
  },
  'dietary_preferences': ['halal'],
  'meal_schedule': [
    {'meal_type': 'breakfast', 'preferred_time': '08:00', 'display_order': 1},
  ],
};

final _settingsJson = <String, dynamic>{
  'measurement_system': 'metric',
  'time_zone': 'Africa/Tunis',
  'theme_preference': 'dark',
};
