import 'tracking_models.dart';

/// One editable item proposed by the AI provider.
final class MealPhotoItemModel {
  const MealPhotoItemModel({
    required this.name,
    required this.estimatedGrams,
    required this.confidence,
    required this.nutrition,
  });

  final String name;
  final double estimatedGrams;
  final double confidence;
  final NutritionValuesModel nutrition;

  factory MealPhotoItemModel.fromJson(Map<String, dynamic> json) {
    final nutrition = json['nutrition'];
    if (nutrition is! Map) {
      throw const FormatException('AI item did not include nutrition.');
    }
    return MealPhotoItemModel(
      name: _string(json, 'name'),
      estimatedGrams: _number(json, 'estimated_grams'),
      confidence: _number(json, 'confidence'),
      nutrition: NutritionValuesModel.fromJson(
        Map<String, dynamic>.from(nutrition),
      ),
    );
  }
}

/// The server deliberately returns a proposal, not a saved meal.
final class MealPhotoAnalysisModel {
  const MealPhotoAnalysisModel({
    required this.items,
    required this.overallConfidence,
    required this.disclaimer,
  });

  final List<MealPhotoItemModel> items;
  final double overallConfidence;
  final String disclaimer;

  factory MealPhotoAnalysisModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw const FormatException('AI response did not include food items.');
    }
    return MealPhotoAnalysisModel(
      items: rawItems
          .whereType<Map>()
          .map(
            (item) =>
                MealPhotoItemModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      overallConfidence: _number(json, 'overall_confidence'),
      disclaimer: _string(json, 'disclaimer'),
    );
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Invalid $key.');
}
