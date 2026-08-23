import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'tracking_models.dart';

abstract interface class TrackingGateway {
  Future<DailyDashboardModel> dashboard(DateTime date);
  Future<MealsResponseModel> meals(DateTime date);
  Future<MealModel> createMeal(MealCreateInput input, {String? idempotencyKey});
  Future<MealModel> updateMeal(String mealId, Map<String, dynamic> patch);
  Future<MealModel> addMealItem(
    String mealId,
    MealItemCreateInput input, {
    String? idempotencyKey,
  });
  Future<MealModel> updateMealItem(
    String mealId,
    String itemId,
    Map<String, dynamic> patch,
  );
  Future<void> deleteMeal(String mealId);
  Future<void> deleteMealItem(String mealId, String itemId);

  Future<WaterListModel> water(DateTime date);
  Future<WaterEntryModel> createWater(
    int amountMl,
    DateTime recordedAt, {
    String? idempotencyKey,
  });
  Future<WaterEntryModel> updateWater(
    String entryId,
    Map<String, dynamic> patch,
  );
  Future<void> deleteWater(String entryId);

  Future<DailyStepsModel> steps(DateTime date);
  Future<DailyStepsModel> setSteps(DateTime date, int stepCount);

  Future<ActivityListModel> activities(DateTime date);
  Future<ActivityModel> createActivity(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  });
  Future<ActivityModel> updateActivity(
    String activityId,
    Map<String, dynamic> patch,
  );
  Future<void> deleteActivity(String activityId);

  Future<FoodProductModel> lookupBarcode(String barcode);
}

final class TrackingApi implements TrackingGateway {
  TrackingApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<DailyDashboardModel> dashboard(DateTime date) async {
    final response = await _client.get<Object?>(
      'users/me/daily-dashboard',
      queryParameters: <String, dynamic>{'date': _dateOnly(date)},
      retryOnUnauthorized: true,
    );
    return DailyDashboardModel.fromJson(_body(response.data));
  }

  @override
  Future<MealsResponseModel> meals(DateTime date) async {
    final response = await _client.get<Object?>(
      'users/me/meals',
      queryParameters: <String, dynamic>{'date': _dateOnly(date)},
      retryOnUnauthorized: true,
    );
    return MealsResponseModel.fromJson(_body(response.data));
  }

  @override
  Future<MealModel> createMeal(
    MealCreateInput input, {
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Object?>(
      'users/me/meals',
      data: input.toJson(),
      options: _idempotencyOptions(idempotencyKey),
      retryOnUnauthorized: true,
    );
    return MealModel.fromJson(_body(response.data));
  }

  @override
  Future<MealModel> updateMeal(
    String mealId,
    Map<String, dynamic> patch,
  ) async {
    final response = await _client.patch<Object?>(
      'users/me/meals/$mealId',
      data: patch,
      retryOnUnauthorized: true,
    );
    return MealModel.fromJson(_body(response.data));
  }

  @override
  Future<MealModel> addMealItem(
    String mealId,
    MealItemCreateInput input, {
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Object?>(
      'users/me/meals/$mealId/items',
      data: input.toJson(),
      options: _idempotencyOptions(idempotencyKey),
      retryOnUnauthorized: true,
    );
    final body = _body(response.data);
    final meal = body['meal'];
    if (meal is! Map) {
      throw const FormatException('Invalid meal-item response.');
    }
    return MealModel.fromJson(Map<String, dynamic>.from(meal));
  }

  @override
  Future<MealModel> updateMealItem(
    String mealId,
    String itemId,
    Map<String, dynamic> patch,
  ) async {
    final response = await _client.patch<Object?>(
      'users/me/meals/$mealId/items/$itemId',
      data: patch,
      retryOnUnauthorized: true,
    );
    final body = _body(response.data);
    final meal = body['meal'];
    if (meal is! Map) {
      throw const FormatException('Invalid meal-item response.');
    }
    return MealModel.fromJson(Map<String, dynamic>.from(meal));
  }

  @override
  Future<void> deleteMeal(String mealId) async {
    await _client.delete<Object?>(
      'users/me/meals/$mealId',
      retryOnUnauthorized: true,
    );
  }

  @override
  Future<void> deleteMealItem(String mealId, String itemId) async {
    await _client.delete<Object?>(
      'users/me/meals/$mealId/items/$itemId',
      retryOnUnauthorized: true,
    );
  }

  @override
  Future<WaterListModel> water(DateTime date) async {
    final response = await _client.get<Object?>(
      'users/me/water-entries',
      queryParameters: <String, dynamic>{'date': _dateOnly(date)},
      retryOnUnauthorized: true,
    );
    return WaterListModel.fromJson(_body(response.data));
  }

  @override
  Future<WaterEntryModel> createWater(
    int amountMl,
    DateTime recordedAt, {
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Object?>(
      'users/me/water-entries',
      data: <String, dynamic>{
        'amount_ml': amountMl,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      },
      options: _idempotencyOptions(idempotencyKey),
      retryOnUnauthorized: true,
    );
    return WaterEntryModel.fromJson(_body(response.data));
  }

  @override
  Future<WaterEntryModel> updateWater(
    String entryId,
    Map<String, dynamic> patch,
  ) async {
    final response = await _client.patch<Object?>(
      'users/me/water-entries/$entryId',
      data: patch,
      retryOnUnauthorized: true,
    );
    return WaterEntryModel.fromJson(_body(response.data));
  }

  @override
  Future<void> deleteWater(String entryId) async {
    await _client.delete<Object?>(
      'users/me/water-entries/$entryId',
      retryOnUnauthorized: true,
    );
  }

  @override
  Future<DailyStepsModel> steps(DateTime date) async {
    final response = await _client.get<Object?>(
      'users/me/daily-steps/${_dateOnly(date)}',
      retryOnUnauthorized: true,
    );
    return DailyStepsModel.fromJson(_body(response.data));
  }

  @override
  Future<DailyStepsModel> setSteps(DateTime date, int stepCount) async {
    final response = await _client.put<Object?>(
      'users/me/daily-steps/${_dateOnly(date)}',
      data: <String, dynamic>{'step_count': stepCount, 'source': 'manual'},
      retryOnUnauthorized: true,
    );
    return DailyStepsModel.fromJson(_body(response.data));
  }

  @override
  Future<ActivityListModel> activities(DateTime date) async {
    final response = await _client.get<Object?>(
      'users/me/activities',
      queryParameters: <String, dynamic>{'date': _dateOnly(date)},
      retryOnUnauthorized: true,
    );
    return ActivityListModel.fromJson(_body(response.data));
  }

  @override
  Future<ActivityModel> createActivity(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final response = await _client.post<Object?>(
      'users/me/activities',
      data: payload,
      options: _idempotencyOptions(idempotencyKey),
      retryOnUnauthorized: true,
    );
    return ActivityModel.fromJson(_body(response.data));
  }

  @override
  Future<ActivityModel> updateActivity(
    String activityId,
    Map<String, dynamic> patch,
  ) async {
    final response = await _client.patch<Object?>(
      'users/me/activities/$activityId',
      data: patch,
      retryOnUnauthorized: true,
    );
    return ActivityModel.fromJson(_body(response.data));
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    await _client.delete<Object?>(
      'users/me/activities/$activityId',
      retryOnUnauthorized: true,
    );
  }

  @override
  Future<FoodProductModel> lookupBarcode(String barcode) async {
    final response = await _client.get<Object?>(
      'food-products/barcodes/$barcode',
      retryOnUnauthorized: true,
    );
    return FoodProductModel.fromJson(_body(response.data));
  }

  static Options? _idempotencyOptions(String? key) {
    return key == null
        ? null
        : Options(headers: <String, dynamic>{'Idempotency-Key': key});
  }
}

Map<String, dynamic> _body(Object? body) {
  if (body is! Map) throw const FormatException('Invalid tracking response.');
  return Map<String, dynamic>.from(body);
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
