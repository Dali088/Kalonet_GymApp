class Measurements {
  const Measurements({
    required this.dateOfBirth,
    required this.sexForFormula,
    required this.heightCm,
    required this.weightKg,
  });

  final DateTime dateOfBirth;
  final String sexForFormula;
  final double heightCm;
  final double weightKg;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date_of_birth': _dateOnly(dateOfBirth),
      'sex_for_formula': sexForFormula,
      'height_cm': heightCm,
      'weight_kg': weightKg,
    };
  }

  factory Measurements.fromJson(Map<String, dynamic> json) {
    return Measurements(
      dateOfBirth: _parseDate(json, 'date_of_birth'),
      sexForFormula: _requiredString(json, 'sex_for_formula'),
      heightCm: _requiredNumber(json, 'height_cm'),
      weightKg: _requiredNumber(json, 'weight_kg'),
    );
  }
}

class MealScheduleInput {
  const MealScheduleInput({
    required this.preferredTime,
    required this.displayOrder,
  });

  final String preferredTime;
  final int displayOrder;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'preferred_time': preferredTime,
      'display_order': displayOrder,
    };
  }

  factory MealScheduleInput.fromJson(Map<String, dynamic> json) {
    return MealScheduleInput(
      preferredTime: _requiredString(json, 'preferred_time'),
      displayOrder: _requiredInt(json, 'display_order'),
    );
  }
}

class OnboardingDraftPatch {
  const OnboardingDraftPatch({
    this.goal,
    this.measurements,
    this.activityLevel,
    this.dietaryPreferences,
    this.mealSchedule,
  });

  final String? goal;
  final Measurements? measurements;
  final String? activityLevel;
  final List<String>? dietaryPreferences;
  final List<MealScheduleInput>? mealSchedule;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (goal != null) json['goal'] = goal;
    if (measurements != null) json['measurements'] = measurements!.toJson();
    if (activityLevel != null) json['activity_level'] = activityLevel;
    if (dietaryPreferences != null) {
      json['dietary_preferences'] = dietaryPreferences;
    }
    if (mealSchedule != null) {
      json['meal_schedule'] = mealSchedule!
          .map((item) => item.toJson())
          .toList();
    }
    return json;
  }
}

class OnboardingCompletionRequest {
  const OnboardingCompletionRequest({required this.acceptedTarget});

  final bool acceptedTarget;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'accepted_target': acceptedTarget};
  }
}

class NutritionTarget {
  const NutritionTarget({
    required this.id,
    required this.calculationVersion,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
    required this.effectiveFrom,
    required this.isActive,
  });

  final String id;
  final String calculationVersion;
  final int caloriesKcal;
  final int proteinG;
  final int carbohydrateG;
  final int fatG;
  final DateTime effectiveFrom;
  final bool isActive;

  factory NutritionTarget.fromJson(Map<String, dynamic> json) {
    return NutritionTarget(
      id: _requiredString(json, 'id'),
      calculationVersion: _requiredString(json, 'calculation_version'),
      caloriesKcal: _requiredInt(json, 'calories_kcal'),
      proteinG: _requiredInt(json, 'protein_g'),
      carbohydrateG: _requiredInt(json, 'carbohydrate_g'),
      fatG: _requiredInt(json, 'fat_g'),
      effectiveFrom: _parseDate(json, 'effective_from'),
      isActive: _requiredBool(json, 'is_active'),
    );
  }
}

class OnboardingState {
  const OnboardingState({
    required this.status,
    required this.goal,
    required this.measurements,
    required this.activityLevel,
    required this.dietaryPreferences,
    required this.mealSchedule,
    required this.missingFields,
    required this.nutritionTargetStatus,
    required this.updatedAt,
  });

  final String status;
  final String? goal;
  final Measurements? measurements;
  final String? activityLevel;
  final List<String> dietaryPreferences;
  final List<MealScheduleInput> mealSchedule;
  final List<String> missingFields;
  final String nutritionTargetStatus;
  final DateTime updatedAt;

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final rawMeasurements = json['measurements'];
    final rawSchedule = json['meal_schedule'];
    final rawPreferences = json['dietary_preferences'];
    return OnboardingState(
      status: _requiredString(json, 'status'),
      goal: _optionalString(json, 'goal'),
      measurements: rawMeasurements is Map
          ? Measurements.fromJson(Map<String, dynamic>.from(rawMeasurements))
          : null,
      activityLevel: _optionalString(json, 'activity_level'),
      dietaryPreferences: rawPreferences is List
          ? rawPreferences.whereType<String>().toList()
          : const [],
      mealSchedule: rawSchedule is List
          ? rawSchedule
                .whereType<Map>()
                .map(
                  (item) => MealScheduleInput.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      missingFields:
          (json['missing_fields'] as List?)?.whereType<String>().toList() ??
          const [],
      nutritionTargetStatus: _requiredString(json, 'nutrition_target_status'),
      updatedAt: DateTime.parse(_requiredString(json, 'updated_at')).toLocal(),
    );
  }
}

class NutritionPreview {
  const NutritionPreview({
    required this.target,
    required this.warnings,
    required this.calculatedAt,
  });

  final NutritionTarget target;
  final List<String> warnings;
  final DateTime calculatedAt;

  factory NutritionPreview.fromJson(Map<String, dynamic> json) {
    final rawTarget = json['target'];
    if (rawTarget is! Map) {
      throw const FormatException('Invalid nutrition preview target.');
    }
    return NutritionPreview(
      target: NutritionTarget.fromJson(Map<String, dynamic>.from(rawTarget)),
      warnings:
          (json['warnings'] as List?)?.whereType<String>().toList() ?? const [],
      calculatedAt: DateTime.parse(
        _requiredString(json, 'calculated_at'),
      ).toLocal(),
    );
  }
}

class OnboardingCompletion {
  const OnboardingCompletion({required this.completedAt, required this.target});

  final DateTime completedAt;
  final NutritionTarget target;

  factory OnboardingCompletion.fromJson(Map<String, dynamic> json) {
    final rawTarget = json['nutrition_target'];
    if (rawTarget is! Map) {
      throw const FormatException('Invalid completed nutrition target.');
    }
    return OnboardingCompletion(
      completedAt: DateTime.parse(
        _requiredString(json, 'completed_at'),
      ).toLocal(),
      target: NutritionTarget.fromJson(Map<String, dynamic>.from(rawTarget)),
    );
  }
}

String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid $field.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value is String && value.isNotEmpty ? value : null;
}

double _requiredNumber(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is num) return value.toDouble();
  throw FormatException('Missing or invalid $field.');
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is num && value == value.toInt()) return value.toInt();
  throw FormatException('Missing or invalid $field.');
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is bool) return value;
  throw FormatException('Missing or invalid $field.');
}

DateTime _parseDate(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Missing or invalid $field.');
  return parsed.toLocal();
}
