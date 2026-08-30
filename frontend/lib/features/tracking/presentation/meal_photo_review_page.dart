import 'package:flutter/material.dart';

import '../../../core/theme/kalonet_colors.dart';
import '../../../core/theme/kalonet_tokens.dart';
import '../../../core/widgets/kalonet_brand_mark.dart';
import '../../../core/widgets/kalonet_surface.dart';
import '../meal_photo.dart';
import '../tracking_models.dart';

/// Lets the learner correct every AI estimate before it can reach meal storage.
final class MealPhotoReviewPage extends StatefulWidget {
  const MealPhotoReviewPage({required this.analysis, super.key});

  final MealPhotoAnalysisModel analysis;

  @override
  State<MealPhotoReviewPage> createState() => _MealPhotoReviewPageState();
}

final class _MealPhotoReviewPageState extends State<MealPhotoReviewPage> {
  late final List<_PhotoItemDraft> _drafts = widget.analysis.items
      .map(_PhotoItemDraft.new)
      .toList();
  String? _error;

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _useReviewedItems() {
    final items = <MealItemCreateInput>[];
    for (final draft in _drafts) {
      final grams = double.tryParse(draft.grams.text.trim());
      final values = [
        grams,
        double.tryParse(draft.calories.text.trim()),
        double.tryParse(draft.protein.text.trim()),
        double.tryParse(draft.carbs.text.trim()),
        double.tryParse(draft.fat.text.trim()),
      ];
      if (draft.name.text.trim().isEmpty ||
          grams == null ||
          grams <= 0 ||
          values.skip(1).any((value) => value == null || value < 0)) {
        setState(() => _error = 'Enter valid values for every food item.');
        return;
      }
      items.add(
        MealItemCreateInput(
          name: draft.name.text.trim(),
          quantity: 1,
          servingDescription: '${grams.toStringAsFixed(0)} g estimated portion',
          nutrition: NutritionValuesModel(
            caloriesKcal: values[1]!,
            proteinG: values[2]!,
            carbohydrateG: values[3]!,
            fatG: values[4]!,
          ),
        ),
      );
    }
    Navigator.of(context).pop(items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review AI meal estimate')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: KalonetGradients.page),
        child: ListView(
          padding: const EdgeInsets.all(KalonetSpacing.md),
          children: [
            const Center(child: KalonetBrandMark(size: 68)),
            const SizedBox(height: KalonetSpacing.sm),
            KalonetSurface(
              accent: KalonetColors.primary.withValues(alpha: 0.65),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI proposal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: KalonetSpacing.xs),
                  Text(widget.analysis.disclaimer),
                  const SizedBox(height: KalonetSpacing.sm),
                  Text(
                    'Overall confidence: ${(widget.analysis.overallConfidence * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: KalonetSpacing.sm),
            for (var index = 0; index < _drafts.length; index++)
              _PhotoItemEditor(index: index, draft: _drafts[index]),
            AnimatedSwitcher(
              duration: KalonetMotion.resolve(context, KalonetMotion.quick),
              child: _error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: KalonetSpacing.xs),
                      child: Text(
                        _error!,
                        key: ValueKey(_error),
                        style: const TextStyle(color: KalonetColors.errorText),
                      ),
                    ),
            ),
            const SizedBox(height: KalonetSpacing.md),
            FilledButton(
              onPressed: _useReviewedItems,
              child: const Text('Use reviewed foods'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PhotoItemEditor extends StatelessWidget {
  const _PhotoItemEditor({required this.index, required this.draft});

  final int index;
  final _PhotoItemDraft draft;

  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      margin: const EdgeInsets.only(bottom: KalonetSpacing.sm),
      accent: KalonetColors.border,
      padding: const EdgeInsets.all(KalonetSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Food ${index + 1}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextField(
            controller: draft.name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: draft.grams,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Estimated portion (g)',
            ),
          ),
          _NumberRow(
            first: draft.calories,
            firstLabel: 'Calories (kcal)',
            second: draft.protein,
            secondLabel: 'Protein (g)',
          ),
          _NumberRow(
            first: draft.carbs,
            firstLabel: 'Carbs (g)',
            second: draft.fat,
            secondLabel: 'Fat (g)',
          ),
        ],
      ),
    );
  }
}

final class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.first,
    required this.firstLabel,
    required this.second,
    required this.secondLabel,
  });

  final TextEditingController first;
  final String firstLabel;
  final TextEditingController second;
  final String secondLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: first,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: firstLabel),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: second,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: secondLabel),
          ),
        ),
      ],
    );
  }
}

final class _PhotoItemDraft {
  _PhotoItemDraft(MealPhotoItemModel item)
    : name = TextEditingController(text: item.name),
      grams = TextEditingController(text: item.estimatedGrams.toString()),
      calories = TextEditingController(
        text: item.nutrition.caloriesKcal.toString(),
      ),
      protein = TextEditingController(text: item.nutrition.proteinG.toString()),
      carbs = TextEditingController(
        text: item.nutrition.carbohydrateG.toString(),
      ),
      fat = TextEditingController(text: item.nutrition.fatG.toString());

  final TextEditingController name;
  final TextEditingController grams;
  final TextEditingController calories;
  final TextEditingController protein;
  final TextEditingController carbs;
  final TextEditingController fat;

  void dispose() {
    name.dispose();
    grams.dispose();
    calories.dispose();
    protein.dispose();
    carbs.dispose();
    fat.dispose();
  }
}
