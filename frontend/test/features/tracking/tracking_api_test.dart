import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';
import 'package:kalonet_frontend/features/tracking/tracking_api.dart';
import 'package:kalonet_frontend/features/tracking/tracking_models.dart';

void main() {
  test('dashboard request sends the selected local date', () async {
    final adapter = _Adapter(_dashboardJson);
    final api = TrackingApi(client: _client(adapter));

    final dashboard = await api.dashboard(DateTime(2026, 8, 19));

    expect(adapter.uri?.path, '/api/v1/users/me/daily-dashboard');
    expect(adapter.uri?.queryParameters['date'], '2026-08-19');
    expect(dashboard.target.caloriesKcal, 2400);
    expect(dashboard.remaining.caloriesKcal, 1800);
  });

  test('meal create uses the contract shape and idempotency header', () async {
    final adapter = _Adapter(_mealJson);
    final api = TrackingApi(client: _client(adapter));

    await api.createMeal(
      MealCreateInput(
        recordDate: DateTime(2026, 8, 19),
        mealType: 'lunch',
        name: 'Lunch',
        recordedTime: '13:00',
        items: [
          MealItemCreateInput(
            name: 'Rice',
            quantity: 1,
            servingDescription: '1 bowl',
            nutrition: const NutritionValuesModel(
              caloriesKcal: 500,
              proteinG: 20,
              carbohydrateG: 80,
              fatG: 10,
            ),
          ),
        ],
      ),
      idempotencyKey: 'meal-test-key',
    );

    expect(adapter.method, 'POST');
    expect(adapter.uri?.path, '/api/v1/users/me/meals');
    expect(adapter.headers?['idempotency-key'], 'meal-test-key');
    expect((adapter.data as Map)['record_date'], '2026-08-19');
  });

  test('barcode product is a proposal with editable nutrition', () {
    final product = FoodProductModel.fromJson(_foodJson);

    expect(product.name, 'Greek yogurt');
    expect(product.provider, 'open_food_facts');
    expect(product.nutrition.proteinG, 17);
  });

  test('steps update uses the approved route and payload', () async {
    final adapter = _Adapter(_stepsJson);
    final api = TrackingApi(client: _client(adapter));

    final steps = await api.setSteps(DateTime(2026, 8, 19), 110);

    expect(adapter.method, 'PUT');
    expect(adapter.uri?.path, '/api/v1/users/me/daily-steps/2026-08-19');
    expect(adapter.data, {'step_count': 110, 'source': 'manual'});
    expect(steps.stepCount, 110);
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
  Map<String, dynamic>? headers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    uri = options.uri;
    data = options.data;
    headers = options.headers.map(
      (key, value) => MapEntry(key.toLowerCase(), '$value'),
    );
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

final _dashboardJson = <String, dynamic>{
  'record_date': '2026-08-19',
  'time_zone': 'Africa/Tunis',
  'nutrition': {
    'target': {
      'calories_kcal': 2400,
      'protein_g': 160,
      'carbohydrate_g': 280,
      'fat_g': 80,
    },
    'consumed': {
      'calories_kcal': 600,
      'protein_g': 40,
      'carbohydrate_g': 60,
      'fat_g': 20,
    },
    'remaining': {
      'calories_kcal': 1800,
      'protein_g': 120,
      'carbohydrate_g': 220,
      'fat_g': 60,
    },
  },
  'meals': {'logged_meal_count': 1, 'logged_item_count': 1},
  'water': {'consumed_ml': 500, 'target_ml': null},
  'steps': {'count': 2000, 'target': null},
  'activity': {
    'activity_count': 0,
    'duration_minutes': 0,
    'estimated_calories_kcal': 0,
  },
  'generated_at': '2026-08-19T10:00:00Z',
};

final _mealJson = <String, dynamic>{
  'id': 'meal-1',
  'meal_type': 'lunch',
  'name': 'Lunch',
  'recorded_at': '2026-08-19T13:00:00Z',
  'totals': {
    'calories_kcal': 500,
    'protein_g': 20,
    'carbohydrate_g': 80,
    'fat_g': 10,
  },
  'items': [
    {
      'id': 'item-1',
      'name': 'Rice',
      'source': 'manual',
      'quantity': 1,
      'serving_description': '1 bowl',
      'nutrition': {
        'calories_kcal': 500,
        'protein_g': 20,
        'carbohydrate_g': 80,
        'fat_g': 10,
      },
    },
  ],
};

final _foodJson = <String, dynamic>{
  'barcode': '1234567890123',
  'provider': 'open_food_facts',
  'product': {
    'name': 'Greek yogurt',
    'brand': 'Example',
    'serving_description': '170 g cup',
    'nutrition': {
      'calories_kcal': 130,
      'protein_g': 17,
      'carbohydrate_g': 9,
      'fat_g': 2,
    },
  },
  'retrieved_at': '2026-08-19T10:00:00Z',
};

final _stepsJson = <String, dynamic>{
  'record_date': '2026-08-19',
  'step_count': 110,
  'source': 'manual',
  'target': null,
  'updated_at': '2026-08-19T10:00:00Z',
};
