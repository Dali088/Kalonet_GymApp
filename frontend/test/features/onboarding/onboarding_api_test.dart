import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';
import 'package:kalonet_frontend/features/onboarding/onboarding_api.dart';
import 'package:kalonet_frontend/features/onboarding/onboarding_models.dart';

void main() {
  test('saves an onboarding section using the approved JSON shape', () async {
    final adapter = _Adapter(_stateJson);
    final api = OnboardingApi(client: _client(adapter));

    await api.saveDraft(
      const OnboardingDraftPatch(
        goal: 'weight_loss',
        activityLevel: 'moderately_active',
      ),
    );

    expect(adapter.uri?.path, '/api/v1/users/me/onboarding');
    expect(adapter.method, 'PATCH');
    expect(adapter.data, {
      'goal': 'weight_loss',
      'activity_level': 'moderately_active',
    });
  });

  test('parses a resumable state and nutrition preview', () {
    final state = OnboardingState.fromJson(_stateJson);
    final preview = NutritionPreview.fromJson(_previewJson);

    expect(state.status, 'in_progress');
    expect(state.measurements?.heightCm, 180);
    expect(state.mealSchedule.single.preferredTime, '08:00');
    expect(preview.target.caloriesKcal, 2200);
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

final _stateJson = <String, dynamic>{
  'status': 'in_progress',
  'goal': 'weight_loss',
  'measurements': {
    'date_of_birth': '2000-01-01',
    'sex_for_formula': 'male',
    'height_cm': 180,
    'weight_kg': 80,
  },
  'activity_level': 'moderately_active',
  'dietary_preferences': ['halal'],
  'meal_schedule': [
    {'preferred_time': '08:00', 'display_order': 1},
  ],
  'missing_fields': [],
  'nutrition_target_status': 'not_calculated',
  'updated_at': '2026-08-19T10:00:00Z',
};

final _previewJson = <String, dynamic>{
  'calculation_version': 'v1',
  'inputs': {
    'goal': 'weight_loss',
    'age_years': 26,
    'sex_for_formula': 'male',
    'height_cm': 180,
    'weight_kg': 80,
    'activity_level': 'moderately_active',
  },
  'calculation': {
    'bmr_kcal': 1800,
    'tdee_kcal': 2600,
    'goal_adjustment_kcal': -400,
  },
  'target': {
    'id': 'preview',
    'calculation_version': 'v1',
    'calories_kcal': 2200,
    'protein_g': 160,
    'carbohydrate_g': 240,
    'fat_g': 70,
    'effective_from': '2026-08-19',
    'is_active': false,
  },
  'warnings': [],
  'calculated_at': '2026-08-19T10:00:00Z',
};

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
