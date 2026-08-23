class NutritionValuesModel {
  const NutritionValuesModel({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
  });

  final double caloriesKcal;
  final double proteinG;
  final double carbohydrateG;
  final double fatG;

  factory NutritionValuesModel.fromJson(Map<String, dynamic> json) {
    return NutritionValuesModel(
      caloriesKcal: _number(json, 'calories_kcal'),
      proteinG: _number(json, 'protein_g'),
      carbohydrateG: _number(json, 'carbohydrate_g'),
      fatG: _number(json, 'fat_g'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'calories_kcal': caloriesKcal,
    'protein_g': proteinG,
    'carbohydrate_g': carbohydrateG,
    'fat_g': fatG,
  };
}

class MealItemCreateInput {
  const MealItemCreateInput({
    required this.name,
    required this.quantity,
    required this.servingDescription,
    required this.nutrition,
    this.source = 'manual',
    this.provider,
    this.barcode,
  });

  final String name;
  final double quantity;
  final String servingDescription;
  final NutritionValuesModel nutrition;
  final String source;
  final String? provider;
  final String? barcode;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'source': source,
    if (provider != null && barcode != null)
      'source_reference': <String, dynamic>{
        'provider': provider,
        'barcode': barcode,
      },
    'quantity': quantity,
    'serving_description': servingDescription,
    'nutrition': nutrition.toJson(),
  };
}

class MealCreateInput {
  const MealCreateInput({
    required this.recordDate,
    required this.mealType,
    required this.name,
    required this.recordedTime,
    required this.items,
  });

  final DateTime recordDate;
  final String mealType;
  final String name;
  final String recordedTime;
  final List<MealItemCreateInput> items;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'record_date': _dateOnly(recordDate),
    'meal_type': mealType,
    'name': name,
    'recorded_time': recordedTime,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class MealItemModel {
  const MealItemModel({
    required this.id,
    required this.name,
    required this.source,
    required this.quantity,
    required this.servingDescription,
    required this.nutrition,
  });

  final String id;
  final String name;
  final String source;
  final double quantity;
  final String servingDescription;
  final NutritionValuesModel nutrition;

  factory MealItemModel.fromJson(Map<String, dynamic> json) {
    return MealItemModel(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      source: _string(json, 'source'),
      quantity: _number(json, 'quantity'),
      servingDescription: _string(json, 'serving_description'),
      nutrition: NutritionValuesModel.fromJson(_map(json, 'nutrition')),
    );
  }
}

class MealModel {
  const MealModel({
    required this.id,
    required this.mealType,
    required this.name,
    required this.recordedAt,
    required this.totals,
    required this.items,
  });

  final String id;
  final String mealType;
  final String name;
  final DateTime recordedAt;
  final NutritionValuesModel totals;
  final List<MealItemModel> items;

  factory MealModel.fromJson(Map<String, dynamic> json) {
    return MealModel(
      id: _string(json, 'id'),
      mealType: _string(json, 'meal_type'),
      name: _string(json, 'name'),
      recordedAt: _dateTime(json, 'recorded_at'),
      totals: NutritionValuesModel.fromJson(_map(json, 'totals')),
      items: _list(
        json,
        'items',
      ).map((item) => MealItemModel.fromJson(item)).toList(),
    );
  }
}

class MealsResponseModel {
  const MealsResponseModel({
    required this.recordDate,
    required this.items,
    required this.dailyTotals,
  });

  final DateTime recordDate;
  final List<MealModel> items;
  final NutritionValuesModel dailyTotals;

  factory MealsResponseModel.fromJson(Map<String, dynamic> json) {
    return MealsResponseModel(
      recordDate: _dateTime(json, 'record_date'),
      items: _list(
        json,
        'items',
      ).map((item) => MealModel.fromJson(item)).toList(),
      dailyTotals: NutritionValuesModel.fromJson(_map(json, 'daily_totals')),
    );
  }
}

class WaterEntryModel {
  const WaterEntryModel({
    required this.id,
    required this.amountMl,
    required this.recordedAt,
    required this.recordDate,
    this.createdAt,
  });

  final String id;
  final int amountMl;
  final DateTime recordedAt;
  final DateTime recordDate;
  final DateTime? createdAt;

  factory WaterEntryModel.fromJson(Map<String, dynamic> json) {
    return WaterEntryModel(
      id: _string(json, 'id'),
      amountMl: _integer(json, 'amount_ml'),
      recordedAt: _dateTime(json, 'recorded_at'),
      recordDate: _dateTime(json, 'record_date'),
      createdAt: _optionalDateTime(json['created_at']),
    );
  }
}

class WaterListModel {
  const WaterListModel({
    required this.recordDate,
    required this.items,
    required this.totalMl,
    this.targetMl,
  });

  final DateTime recordDate;
  final List<WaterEntryModel> items;
  final int totalMl;
  final int? targetMl;

  factory WaterListModel.fromJson(Map<String, dynamic> json) {
    return WaterListModel(
      recordDate: _dateTime(json, 'record_date'),
      items: _list(
        json,
        'items',
      ).map((item) => WaterEntryModel.fromJson(item)).toList(),
      totalMl: _integer(json, 'total_ml'),
      targetMl: _optionalInteger(json['target_ml']),
    );
  }
}

class DailyStepsModel {
  const DailyStepsModel({
    required this.recordDate,
    required this.stepCount,
    this.source,
    this.target,
    this.updatedAt,
  });

  final DateTime recordDate;
  final int stepCount;
  final String? source;
  final int? target;
  final DateTime? updatedAt;

  factory DailyStepsModel.fromJson(Map<String, dynamic> json) {
    return DailyStepsModel(
      recordDate: _dateTime(json, 'record_date'),
      stepCount: _integer(json, 'step_count'),
      source: json['source'] as String?,
      target: _optionalInteger(json['target']),
      updatedAt: _optionalDateTime(json['updated_at']),
    );
  }
}

class ActivityModel {
  const ActivityModel({
    required this.id,
    required this.activityType,
    required this.name,
    required this.durationMinutes,
    required this.recordedAt,
    this.estimatedCaloriesKcal,
  });

  final String id;
  final String activityType;
  final String name;
  final int durationMinutes;
  final double? estimatedCaloriesKcal;
  final DateTime recordedAt;

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: _string(json, 'id'),
      activityType: _string(json, 'activity_type'),
      name: _string(json, 'name'),
      durationMinutes: _integer(json, 'duration_minutes'),
      estimatedCaloriesKcal: _optionalNumber(json['estimated_calories_kcal']),
      recordedAt: _dateTime(json, 'recorded_at'),
    );
  }
}

class ActivityListModel {
  const ActivityListModel({
    required this.recordDate,
    required this.items,
    required this.totalDurationMinutes,
    required this.totalCaloriesKcal,
  });

  final DateTime recordDate;
  final List<ActivityModel> items;
  final int totalDurationMinutes;
  final double totalCaloriesKcal;

  factory ActivityListModel.fromJson(Map<String, dynamic> json) {
    final totals = _map(json, 'totals');
    return ActivityListModel(
      recordDate: _dateTime(json, 'record_date'),
      items: _list(
        json,
        'items',
      ).map((item) => ActivityModel.fromJson(item)).toList(),
      totalDurationMinutes: _integer(totals, 'duration_minutes'),
      totalCaloriesKcal: _number(totals, 'estimated_calories_kcal'),
    );
  }
}

class DashboardTargetModel {
  const DashboardTargetModel({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
  });

  final int caloriesKcal;
  final int proteinG;
  final int carbohydrateG;
  final int fatG;

  factory DashboardTargetModel.fromJson(Map<String, dynamic> json) {
    return DashboardTargetModel(
      caloriesKcal: _integer(json, 'calories_kcal'),
      proteinG: _integer(json, 'protein_g'),
      carbohydrateG: _integer(json, 'carbohydrate_g'),
      fatG: _integer(json, 'fat_g'),
    );
  }
}

class DailyDashboardModel {
  const DailyDashboardModel({
    required this.recordDate,
    required this.timeZone,
    required this.target,
    required this.consumed,
    required this.remaining,
    required this.mealCount,
    required this.itemCount,
    required this.waterConsumedMl,
    required this.waterTargetMl,
    required this.stepCount,
    required this.stepTarget,
    required this.activityCount,
    required this.activityDurationMinutes,
    required this.activityCaloriesKcal,
    required this.generatedAt,
  });

  final DateTime recordDate;
  final String timeZone;
  final DashboardTargetModel target;
  final DashboardTargetModel consumed;
  final DashboardTargetModel remaining;
  final int mealCount;
  final int itemCount;
  final int waterConsumedMl;
  final int? waterTargetMl;
  final int stepCount;
  final int? stepTarget;
  final int activityCount;
  final int activityDurationMinutes;
  final double activityCaloriesKcal;
  final DateTime generatedAt;

  factory DailyDashboardModel.fromJson(Map<String, dynamic> json) {
    final nutrition = _map(json, 'nutrition');
    final meals = _map(json, 'meals');
    final water = _map(json, 'water');
    final steps = _map(json, 'steps');
    final activity = _map(json, 'activity');
    return DailyDashboardModel(
      recordDate: _dateTime(json, 'record_date'),
      timeZone: _string(json, 'time_zone'),
      target: DashboardTargetModel.fromJson(_map(nutrition, 'target')),
      consumed: DashboardTargetModel.fromJson(_map(nutrition, 'consumed')),
      remaining: DashboardTargetModel.fromJson(_map(nutrition, 'remaining')),
      mealCount: _integer(meals, 'logged_meal_count'),
      itemCount: _integer(meals, 'logged_item_count'),
      waterConsumedMl: _integer(water, 'consumed_ml'),
      waterTargetMl: _optionalInteger(water['target_ml']),
      stepCount: _integer(steps, 'count'),
      stepTarget: _optionalInteger(steps['target']),
      activityCount: _integer(activity, 'activity_count'),
      activityDurationMinutes: _integer(activity, 'duration_minutes'),
      activityCaloriesKcal: _number(activity, 'estimated_calories_kcal'),
      generatedAt: _dateTime(json, 'generated_at'),
    );
  }
}

class FoodProductModel {
  const FoodProductModel({
    required this.barcode,
    required this.provider,
    required this.name,
    required this.servingDescription,
    required this.nutrition,
    this.brand,
  });

  final String barcode;
  final String provider;
  final String name;
  final String servingDescription;
  final NutritionValuesModel nutrition;
  final String? brand;

  factory FoodProductModel.fromJson(Map<String, dynamic> json) {
    final product = _map(json, 'product');
    final nutrition = product['nutrition'];
    if (nutrition is! Map) {
      throw const FormatException(
        'Barcode response did not include nutrition.',
      );
    }
    return FoodProductModel(
      barcode: _string(json, 'barcode'),
      provider: _string(json, 'provider'),
      name: _string(product, 'name'),
      servingDescription: _string(product, 'serving_description'),
      nutrition: NutritionValuesModel.fromJson(
        Map<String, dynamic>.from(nutrition),
      ),
      brand: product['brand'] as String?,
    );
  }
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('Invalid $key.');
  return value;
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Invalid $key.');
}

double? _optionalNumber(Object? value) =>
    value is num ? value.toDouble() : null;

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.toInt()) return value.toInt();
  throw FormatException('Invalid $key.');
}

int? _optionalInteger(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.toInt()) return value.toInt();
  return null;
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid $key.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $key.');
  return parsed.toLocal();
}

DateTime? _optionalDateTime(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  return parsed?.toLocal();
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Invalid $key.');
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Invalid $key.');
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
