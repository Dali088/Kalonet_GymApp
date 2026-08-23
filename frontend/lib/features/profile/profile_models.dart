import '../onboarding/onboarding_models.dart';

class ProfileCalculationInputsModel {
  const ProfileCalculationInputsModel({
    required this.goal,
    required this.dateOfBirth,
    required this.formulaSex,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
  });

  final String goal;
  final DateTime dateOfBirth;
  final String formulaSex;
  final double heightCm;
  final double weightKg;
  final String activityLevel;

  factory ProfileCalculationInputsModel.fromJson(Map<String, dynamic> json) {
    return ProfileCalculationInputsModel(
      goal: _string(json, 'goal'),
      dateOfBirth: _date(json, 'date_of_birth'),
      formulaSex: _string(json, 'formula_sex'),
      heightCm: _number(json, 'height_cm'),
      weightKg: _number(json, 'weight_kg'),
      activityLevel: _string(json, 'activity_level'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'goal': goal,
    'date_of_birth': _dateOnly(dateOfBirth),
    'formula_sex': formulaSex,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'activity_level': activityLevel,
  };
}

class ProfileTargetModel {
  const ProfileTargetModel({
    required this.id,
    required this.dailyCalories,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
    required this.effectiveFrom,
    required this.ruleVersion,
    required this.isActive,
  });

  final String id;
  final int dailyCalories;
  final int proteinG;
  final int carbohydrateG;
  final int fatG;
  final DateTime effectiveFrom;
  final String ruleVersion;
  final bool isActive;

  factory ProfileTargetModel.fromJson(Map<String, dynamic> json) {
    return ProfileTargetModel(
      id: _string(json, 'id'),
      dailyCalories: _integer(json, 'daily_calories'),
      proteinG: _integer(json, 'protein_g'),
      carbohydrateG: _integer(json, 'carbohydrate_g'),
      fatG: _integer(json, 'fat_g'),
      effectiveFrom: _date(json, 'effective_from'),
      ruleVersion: _string(json, 'rule_version'),
      isActive: json['is_active'] == true,
    );
  }
}

class ProfileModel {
  const ProfileModel({
    required this.email,
    required this.onboardingCompletedAt,
    required this.inputs,
    required this.target,
    required this.preferences,
    required this.schedule,
  });

  final String email;
  final DateTime onboardingCompletedAt;
  final ProfileCalculationInputsModel inputs;
  final ProfileTargetModel target;
  final List<String> preferences;
  final List<MealScheduleInput> schedule;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final user = _map(json, 'user');
    final schedule = json['meal_schedule'];
    final preferences = json['dietary_preferences'];
    if (schedule is! List || preferences is! List) {
      throw const FormatException('Invalid profile collections.');
    }
    return ProfileModel(
      email: _string(user, 'email'),
      onboardingCompletedAt: _date(user, 'onboarding_completed_at'),
      inputs: ProfileCalculationInputsModel.fromJson(
        _map(json, 'calculation_inputs'),
      ),
      target: ProfileTargetModel.fromJson(
        _map(json, 'current_nutrition_target'),
      ),
      preferences: preferences.whereType<String>().toList(),
      schedule: schedule
          .whereType<Map>()
          .map(
            (item) =>
                MealScheduleInput.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class SettingsModel {
  const SettingsModel({
    required this.measurementSystem,
    required this.timeZone,
    required this.themePreference,
  });

  final String measurementSystem;
  final String timeZone;
  final String themePreference;

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      measurementSystem: _string(json, 'measurement_system'),
      timeZone: _string(json, 'time_zone'),
      themePreference: _string(json, 'theme_preference'),
    );
  }
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

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.toInt()) return value.toInt();
  throw FormatException('Invalid $key.');
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = _string(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $key.');
  return parsed.toLocal();
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Invalid $key.');
  return Map<String, dynamic>.from(value);
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
