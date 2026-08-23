import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/errors/api_error.dart';
import '../../auth/authentication_providers.dart';
import '../../profile/profile_models.dart';
import '../../profile/profile_providers.dart';
import '../../onboarding/onboarding_models.dart';
import '../../tracking/tracking_models.dart';
import '../../tracking/tracking_providers.dart';

final class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

final class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _tab = 0;
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await ref.read(sessionServiceProvider).logout();
      if (mounted) context.go('/');
    } on ApiError catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickDate() async {
    final selected = ref.read(selectedDateProvider);
    final startDate = ref
        .read(profileProvider)
        .maybeWhen(
          data: (profile) => _dateOnly(profile.onboardingCompletedAt),
          orElse: () => _dateOnly(DateTime.now()),
        );
    final picked = await showDatePicker(
      context: context,
      initialDate: selected.isBefore(startDate) ? startDate : selected,
      firstDate: startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) ref.read(selectedDateProvider.notifier).set(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final profileState = ref.watch(profileProvider);
    final startDate = profileState.maybeWhen(
      data: (profile) => _dateOnly(profile.onboardingCompletedAt),
      orElse: () => null,
    );
    if (startDate != null && selectedDate.isBefore(startDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedDateProvider.notifier).set(startDate);
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tab == 0
              ? 'Today'
              : _tab == 1
              ? 'Meals'
              : _tab == 2
              ? 'Tracking'
              : 'Profile',
        ),
        actions: [
          IconButton(
            tooltip: 'Previous day',
            onPressed: startDate != null && selectedDate.isAfter(startDate)
                ? () => ref.read(selectedDateProvider.notifier).previous()
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton(
            onPressed: _pickDate,
            child: Text(_dateLabel(selectedDate)),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed: selectedDate.isBefore(_dateOnly(DateTime.now()))
                ? () => ref.read(selectedDateProvider.notifier).next()
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _isLoggingOut ? null : _logout,
            icon: _isLoggingOut
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _OverviewTab(),
          _MealsTab(),
          _TrackingTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Meals'),
          NavigationDestination(
            icon: Icon(Icons.water_drop),
            label: 'Tracking',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

final class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final result = ref.watch(dashboardProvider(date));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: _friendlyError(error),
        onRetry: () => ref.invalidate(dashboardProvider(date)),
      ),
      data: (dashboard) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider(date)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Your daily snapshot',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _NutritionCard(dashboard: dashboard),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.restaurant,
                    label: 'Meals',
                    value: '${dashboard.mealCount}',
                    detail: '${dashboard.itemCount} items',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.water_drop,
                    label: 'Water',
                    value: '${dashboard.waterConsumedMl} ml',
                    detail: dashboard.waterTargetMl == null
                        ? 'Target not set'
                        : 'of ${dashboard.waterTargetMl} ml',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.directions_walk,
                    label: 'Steps',
                    value: '${dashboard.stepCount}',
                    detail: dashboard.stepTarget == null
                        ? 'Target not set'
                        : 'of ${dashboard.stepTarget}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.fitness_center,
                    label: 'Activity',
                    value: '${dashboard.activityDurationMinutes} min',
                    detail: '${dashboard.activityCount} sessions',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Activity calories are shown separately and do not increase your food allowance.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

final class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.dashboard});

  final DailyDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final target = dashboard.target;
    final consumed = dashboard.consumed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nutrition', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              '${consumed.caloriesKcal} / ${target.caloriesKcal} kcal',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: target.caloriesKcal == 0
                  ? 0
                  : (consumed.caloriesKcal / target.caloriesKcal).clamp(0, 1),
              minHeight: 10,
            ),
            const SizedBox(height: 12),
            Text(
              'Remaining ${dashboard.remaining.caloriesKcal} kcal  •  '
              'Protein ${consumed.proteinG}/${target.proteinG} g  •  '
              'Carbs ${consumed.carbohydrateG}/${target.carbohydrateG} g  •  '
              'Fat ${consumed.fatG}/${target.fatG} g',
            ),
          ],
        ),
      ),
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

final class _MealsTab extends ConsumerWidget {
  const _MealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final result = ref.watch(mealsProvider(date));
    return result.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: _friendlyError(error),
        onRetry: () => ref.invalidate(mealsProvider(date)),
      ),
      data: (meals) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(mealsProvider(date)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Logged meals',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Add meal',
                  onPressed: () => _showMealComposer(context, ref, date),
                  icon: const Icon(Icons.add_circle),
                ),
              ],
            ),
            if (meals.items.isEmpty)
              const _EmptyState(
                icon: Icons.restaurant,
                message: 'No meals logged for this date yet.',
              ),
            ...meals.items.map((meal) => _MealCard(meal: meal, date: date)),
            const SizedBox(height: 12),
            _DailyTotalsCard(totals: meals.dailyTotals),
          ],
        ),
      ),
    );
  }

  Future<void> _showMealComposer(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _MealComposerDialog(date: date),
    );
    if (created == true) {
      ref.invalidate(mealsProvider(date));
      ref.invalidate(dashboardProvider(date));
    }
  }
}

final class _MealCard extends ConsumerWidget {
  const _MealCard({required this.meal, required this.date});

  final MealModel meal;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        title: Text(meal.name),
        subtitle: Text('${_label(meal.mealType)} • ${meal.items.length} items'),
        trailing: Text('${meal.totals.caloriesKcal.toStringAsFixed(0)} kcal'),
        children: [
          ...meal.items.map(
            (item) => ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.quantity} × ${item.servingDescription} • '
                '${item.nutrition.caloriesKcal.toStringAsFixed(0)} kcal',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _editItem(context, ref, item);
                  } else {
                    await _deleteItem(context, ref, item);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Correct item')),
                  PopupMenuItem(value: 'delete', child: Text('Delete item')),
                ],
              ),
            ),
          ),
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: () => _deleteMeal(context, ref),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete meal'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    MealItemModel item,
  ) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ItemEditDialog(item: item),
    );
    if (values == null) return;
    try {
      await ref
          .read(trackingApiProvider)
          .updateMealItem(meal.id, item.id, values);
      ref.invalidate(mealsProvider(date));
      ref.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    MealItemModel item,
  ) async {
    final confirmed = await _confirm(context, 'Delete ${item.name}?');
    if (!confirmed) return;
    try {
      await ref.read(trackingApiProvider).deleteMealItem(meal.id, item.id);
      ref.invalidate(mealsProvider(date));
      ref.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _deleteMeal(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      'Delete the entire ${meal.name} meal?',
    );
    if (!confirmed) return;
    try {
      await ref.read(trackingApiProvider).deleteMeal(meal.id);
      ref.invalidate(mealsProvider(date));
      ref.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

final class _DailyTotalsCard extends StatelessWidget {
  const _DailyTotalsCard({required this.totals});

  final NutritionValuesModel totals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.summarize),
        title: const Text('Daily meal totals'),
        subtitle: Text(
          '${totals.caloriesKcal.toStringAsFixed(0)} kcal • '
          '${totals.proteinG.toStringAsFixed(0)} g protein • '
          '${totals.carbohydrateG.toStringAsFixed(0)} g carbs • '
          '${totals.fatG.toStringAsFixed(0)} g fat',
        ),
      ),
    );
  }
}

final class _MealComposerDialog extends ConsumerStatefulWidget {
  const _MealComposerDialog({required this.date});

  final DateTime date;

  @override
  ConsumerState<_MealComposerDialog> createState() =>
      _MealComposerDialogState();
}

final class _MealComposerDialogState
    extends ConsumerState<_MealComposerDialog> {
  final _name = TextEditingController(text: 'Meal');
  final _itemName = TextEditingController();
  final _serving = TextEditingController(text: '1 serving');
  final _quantity = TextEditingController(text: '1');
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _barcode = TextEditingController();
  String _mealType = 'breakfast';
  final String _recordedTime = '12:00';
  String _source = 'manual';
  String? _provider;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _itemName,
      _serving,
      _quantity,
      _calories,
      _protein,
      _carbs,
      _fat,
      _barcode,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _lookup() async {
    final barcode = _barcode.text.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(barcode)) {
      setState(() => _error = 'Enter an 8–14 digit barcode.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final product = await ref
          .read(trackingApiProvider)
          .lookupBarcode(barcode);
      _itemName.text = product.brand == null || product.brand!.isEmpty
          ? product.name
          : '${product.brand} ${product.name}';
      _serving.text = product.servingDescription;
      _calories.text = product.nutrition.caloriesKcal.toString();
      _protein.text = product.nutrition.proteinG.toString();
      _carbs.text = product.nutrition.carbohydrateG.toString();
      _fat.text = product.nutrition.fatG.toString();
      setState(() {
        _source = 'barcode';
        _provider = product.provider;
      });
    } on ApiError catch (error) {
      setState(
        () => _error = '${error.message} You can enter the food manually.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final values = [
      _quantity.text,
      _calories.text,
      _protein.text,
      _carbs.text,
      _fat.text,
    ].map((value) => double.tryParse(value.trim())).toList();
    if (_itemName.text.trim().isEmpty || values.any((value) => value == null)) {
      setState(
        () => _error = 'Enter the food name and valid nutrition values.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(trackingApiProvider)
          .createMeal(
            MealCreateInput(
              recordDate: widget.date,
              mealType: _mealType,
              name: _name.text.trim(),
              recordedTime: _recordedTime,
              items: [
                MealItemCreateInput(
                  name: _itemName.text.trim(),
                  quantity: values[0]!,
                  servingDescription: _serving.text.trim(),
                  source: _source,
                  provider: _provider,
                  barcode: _source == 'barcode' ? _barcode.text.trim() : null,
                  nutrition: NutritionValuesModel(
                    caloriesKcal: values[1]!,
                    proteinG: values[2]!,
                    carbohydrateG: values[3]!,
                    fatG: values[4]!,
                  ),
                ),
              ],
            ),
            idempotencyKey: 'meal-${DateTime.now().microsecondsSinceEpoch}',
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (error) {
      setState(() => _error = error.message);
    } on FormatException {
      setState(
        () => _error =
            'The server returned an unexpected meal response. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log a meal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _mealType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Meal type'),
              items:
                  const [
                        'breakfast',
                        'morning_snack',
                        'lunch',
                        'afternoon_snack',
                        'dinner',
                        'evening_snack',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) =>
                  setState(() => _mealType = value ?? _mealType),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Meal name'),
            ),
            TextField(
              controller: _itemName,
              decoration: const InputDecoration(labelText: 'Food name'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Barcode (optional)',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _lookup,
                  icon: const Icon(Icons.search),
                  tooltip: 'Look up barcode',
                ),
              ],
            ),
            TextField(
              controller: _serving,
              decoration: const InputDecoration(
                labelText: 'Serving description',
              ),
            ),
            TextField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _calories,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Calories'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _protein,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Protein (g)'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _carbs,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Carbs (g)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fat (g)'),
                  ),
                ),
              ],
            ),
            if (_source == 'barcode')
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Source: ${_provider ?? 'food provider'} • Values are editable before saving.',
                ),
              ),
            if (_error != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const CircularProgressIndicator()
              : const Text('Save meal'),
        ),
      ],
    );
  }
}

final class _ItemEditDialog extends StatefulWidget {
  const _ItemEditDialog({required this.item});

  final MealItemModel item;

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

final class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item.name,
  );
  late final TextEditingController _quantity = TextEditingController(
    text: '${widget.item.quantity}',
  );
  late final TextEditingController _serving = TextEditingController(
    text: widget.item.servingDescription,
  );
  late final TextEditingController _calories = TextEditingController(
    text: '${widget.item.nutrition.caloriesKcal}',
  );
  late final TextEditingController _protein = TextEditingController(
    text: '${widget.item.nutrition.proteinG}',
  );
  late final TextEditingController _carbs = TextEditingController(
    text: '${widget.item.nutrition.carbohydrateG}',
  );
  late final TextEditingController _fat = TextEditingController(
    text: '${widget.item.nutrition.fatG}',
  );

  @override
  void dispose() {
    for (final c in [
      _name,
      _quantity,
      _serving,
      _calories,
      _protein,
      _carbs,
      _fat,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Correct food item'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _quantity,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              controller: _serving,
              decoration: const InputDecoration(labelText: 'Serving'),
            ),
            TextField(
              controller: _calories,
              decoration: const InputDecoration(labelText: 'Calories'),
            ),
            TextField(
              controller: _protein,
              decoration: const InputDecoration(labelText: 'Protein (g)'),
            ),
            TextField(
              controller: _carbs,
              decoration: const InputDecoration(labelText: 'Carbs (g)'),
            ),
            TextField(
              controller: _fat,
              decoration: const InputDecoration(labelText: 'Fat (g)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final values = [_quantity, _calories, _protein, _carbs, _fat]
                .map((controller) => double.tryParse(controller.text.trim()))
                .toList();
            if (_name.text.trim().isEmpty ||
                values.any((value) => value == null)) {
              return;
            }
            Navigator.of(context).pop(<String, dynamic>{
              'name': _name.text.trim(),
              'quantity': values[0],
              'serving_description': _serving.text.trim(),
              'nutrition': <String, dynamic>{
                'calories_kcal': values[1],
                'protein_g': values[2],
                'carbohydrate_g': values[3],
                'fat_g': values[4],
              },
            });
          },
          child: const Text('Save correction'),
        ),
      ],
    );
  }
}

final class _TrackingTab extends ConsumerWidget {
  const _TrackingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final water = ref.watch(waterProvider(date));
    final steps = ref.watch(stepsProvider(date));
    final activities = ref.watch(activitiesProvider(date));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Daily tracking',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _WaterSection(result: water, date: date),
        const SizedBox(height: 12),
        _StepsSection(result: steps, date: date),
        const SizedBox(height: 12),
        _ActivitySection(result: activities, date: date),
      ],
    );
  }
}

final class _WaterSection extends StatelessWidget {
  const _WaterSection({required this.result, required this.date});

  final AsyncValue<WaterListModel> result;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: result.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(_friendlyError(error)),
          data: (water) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Water: ${water.totalMl} ml',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [250, 500, 750]
                    .map(
                      (amount) => ActionChip(
                        label: Text('+$amount ml'),
                        onPressed: () => _quickAdd(context, amount),
                      ),
                    )
                    .toList(),
              ),
              if (water.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('No water entries yet.'),
                ),
              ...water.items.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${entry.amountMl} ml'),
                  subtitle: Text(_timeLabel(entry.recordedAt)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => value == 'edit'
                        ? _edit(context, entry)
                        : _delete(context, entry),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Correct amount'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete entry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context, int amount) async {
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container
          .read(trackingApiProvider)
          .createWater(
            amount,
            DateTime.now(),
            idempotencyKey: 'water-${DateTime.now().microsecondsSinceEpoch}',
          );
      container.invalidate(waterProvider(date));
      container.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _add(BuildContext context) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (_) =>
          const _WaterEditDialog(title: 'Add water', initialAmount: 500),
    );
    if (amount != null && context.mounted) {
      await _quickAdd(context, amount);
    }
  }

  Future<void> _edit(BuildContext context, WaterEntryModel entry) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _WaterEditDialog(initialAmount: entry.amountMl),
    );
    if (amount == null) return;
    try {
      await container.read(trackingApiProvider).updateWater(
        entry.id,
        <String, dynamic>{'amount_ml': amount},
      );
      container.invalidate(waterProvider(date));
      container.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _delete(BuildContext context, WaterEntryModel entry) async {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!await _confirm(context, 'Delete this ${entry.amountMl} ml entry?')) {
      return;
    }
    try {
      await container.read(trackingApiProvider).deleteWater(entry.id);
      container.invalidate(waterProvider(date));
      container.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

final class _StepsSection extends StatefulWidget {
  const _StepsSection({required this.result, required this.date});

  final AsyncValue<DailyStepsModel> result;
  final DateTime date;

  @override
  State<_StepsSection> createState() => _StepsSectionState();
}

final class _WaterEditDialog extends StatefulWidget {
  const _WaterEditDialog({
    required this.initialAmount,
    this.title = 'Correct water amount',
  });

  final int initialAmount;
  final String title;

  @override
  State<_WaterEditDialog> createState() => _WaterEditDialogState();
}

final class _WaterEditDialogState extends State<_WaterEditDialog> {
  late final _controller = TextEditingController(
    text: '${widget.initialAmount}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Amount (ml)'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          final amount = int.tryParse(_controller.text.trim());
          if (amount == null || amount < 1 || amount > 10000) return;
          Navigator.of(context).pop(amount);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

final class _StepsSectionState extends State<_StepsSection> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: widget.result.when(
          loading: () => _buildForm(context, loading: true),
          error: (error, _) => _buildForm(context, error: error),
          data: (steps) => _buildForm(context, initialCount: steps.stepCount),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context, {
    int initialCount = 0,
    Object? error,
    bool loading = false,
  }) {
    if (_controller.text.isEmpty) {
      _controller.text = '$initialCount';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(_friendlyError(error)),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            const Icon(Icons.directions_walk),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Steps'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 88,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _save(context),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final count = int.tryParse(_controller.text.trim());
    if (count == null || count < 0) return;
    setState(() => _saving = true);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final saved = await container
          .read(trackingApiProvider)
          .setSteps(widget.date, count);
      if (context.mounted) {
        _controller.value = TextEditingValue(
          text: '${saved.stepCount}',
          selection: TextSelection.collapsed(
            offset: '${saved.stepCount}'.length,
          ),
        );
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Steps saved.')));
      }
      container.invalidate(stepsProvider(widget.date));
      container.invalidate(dashboardProvider(widget.date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    } on FormatException {
      if (context.mounted) {
        _showError(context, 'Kalonet returned an invalid steps response.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

final class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.result, required this.date});

  final AsyncValue<ActivityListModel> result;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: result.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(_friendlyError(error)),
          data: (activities) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Activities: ${activities.totalDurationMinutes} min',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showActivityDialog(context),
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),
              if (activities.items.isEmpty)
                const Text('No activities logged yet.'),
              ...activities.items.map(
                (activity) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(activity.name),
                  subtitle: Text(
                    '${_label(activity.activityType)} • ${activity.durationMinutes} min',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => value == 'delete'
                        ? _delete(context, activity)
                        : _edit(context, activity),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActivityDialog(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ActivityDialog(),
    );
    if (payload == null) return;
    try {
      await container.read(trackingApiProvider).createActivity({
        ...payload,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      }, idempotencyKey: 'activity-${DateTime.now().microsecondsSinceEpoch}');
      container.invalidate(activitiesProvider(date));
      container.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _edit(BuildContext context, ActivityModel activity) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ActivityDialog(activity: activity),
    );
    if (payload == null) return;
    try {
      await container
          .read(trackingApiProvider)
          .updateActivity(activity.id, payload);
      container.invalidate(activitiesProvider(date));
      container.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _delete(BuildContext context, ActivityModel activity) async {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!await _confirm(context, 'Delete ${activity.name}?')) {
      return;
    }
    try {
      await container.read(trackingApiProvider).deleteActivity(activity.id);
      container.invalidate(activitiesProvider(date));
      container.invalidate(dashboardProvider(date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

final class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({this.activity});

  final ActivityModel? activity;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

final class _ActivityDialogState extends State<_ActivityDialog> {
  late final _name = TextEditingController(
    text: widget.activity?.name ?? 'Workout',
  );
  late final _duration = TextEditingController(
    text: '${widget.activity?.durationMinutes ?? 30}',
  );
  late final _calories = TextEditingController(
    text: '${widget.activity?.estimatedCaloriesKcal ?? ''}',
  );
  String _type = 'strength_training';

  @override
  void initState() {
    super.initState();
    _type = widget.activity?.activityType ?? _type;
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _calories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.activity == null ? 'Add activity' : 'Edit activity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            items:
                const [
                      'walking',
                      'running',
                      'cycling',
                      'strength_training',
                      'swimming',
                      'other',
                    ]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
            decoration: const InputDecoration(labelText: 'Type'),
          ),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration (minutes)'),
          ),
          TextField(
            controller: _calories,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Estimated calories (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final duration = int.tryParse(_duration.text.trim());
            final calories = double.tryParse(_calories.text.trim());
            if (_name.text.trim().isEmpty || duration == null) return;
            Navigator.of(context).pop(<String, dynamic>{
              'activity_type': _type,
              'name': _name.text.trim(),
              'duration_minutes': duration,
              ...?(calories == null
                  ? null
                  : <String, dynamic>{'estimated_calories_kcal': calories}),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

final class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final settings = ref.watch(settingsProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Profile & settings',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        profile.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (value) => _ProfileCard(profile: value),
        ),
        const SizedBox(height: 12),
        settings.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => ref.invalidate(settingsProvider),
          ),
          data: (value) => _SettingsCard(settings: value),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _changePassword(context, ref),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Change password'),
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _PasswordChangeDialog(),
    );
    if (values == null) return;
    try {
      await ref.read(profileApiProvider).changePassword(values[0], values[1]);
      // Password change revokes every server session, so only clear local
      // credentials here; a second logout request would correctly receive 401.
      await ref.read(sessionControllerProvider.notifier).clear();
      if (context.mounted) context.go('/');
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

final class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputs = profile.inputs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(profile.email, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${_label(inputs.goal)} • ${inputs.weightKg} kg • ${inputs.heightCm} cm',
            ),
            Text(
              'Target: ${profile.target.dailyCalories} kcal • ${profile.target.proteinG} g protein',
            ),
            Text(
              'Preferences: ${profile.preferences.isEmpty ? 'None' : profile.preferences.join(', ')}',
            ),
            Text(
              'Meals: ${profile.schedule.map((item) => '${_label(item.mealType)} ${item.preferredTime}').join(', ')}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _editPreferences(context, ref),
                  child: const Text('Preferences'),
                ),
                OutlinedButton(
                  onPressed: () => _editSchedule(context, ref),
                  child: const Text('Meal schedule'),
                ),
                OutlinedButton(
                  onPressed: () => _recalculate(context, ref),
                  child: const Text('Recalculate target'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPreferences(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Dietary preferences',
        initial: profile.preferences.join(', '),
        hint: 'halal, lactose_free',
      ),
    );
    if (value == null) return;
    try {
      await ref
          .read(profileApiProvider)
          .replacePreferences(
            value
                .split(',')
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(),
          );
      ref.invalidate(profileProvider);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _editSchedule(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Meal schedule',
        initial: profile.schedule
            .map((item) => '${item.mealType}=${item.preferredTime}')
            .join(', '),
        hint: 'breakfast=08:00, lunch=13:00',
      ),
    );
    if (value == null) return;
    final schedule = <MealScheduleInput>[];
    for (final part in value.split(',')) {
      final pieces = part.trim().split('=');
      if (pieces.length == 2) {
        schedule.add(
          MealScheduleInput(
            mealType: pieces[0].trim(),
            preferredTime: pieces[1].trim(),
            displayOrder: schedule.length + 1,
          ),
        );
      }
    }
    try {
      await ref.read(profileApiProvider).replaceSchedule(schedule);
      ref.invalidate(profileProvider);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _recalculate(BuildContext context, WidgetRef ref) async {
    final inputs = await showDialog<ProfileCalculationInputsModel>(
      context: context,
      builder: (_) => _RecalculateDialog(inputs: profile.inputs),
    );
    if (inputs == null) return;
    try {
      await ref.read(profileApiProvider).recalculate(inputs);
      ref.invalidate(profileProvider);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

final class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.settings});

  final SettingsModel settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: const Text('Application settings'),
        subtitle: Text(
          '${settings.measurementSystem} • ${settings.timeZone} • ${settings.themePreference}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _edit(context, ref),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Theme preference',
        initial: settings.themePreference,
        hint: 'system, light, or dark',
      ),
    );
    if (value == null || !['system', 'light', 'dark'].contains(value.trim())) {
      return;
    }
    try {
      await ref.read(profileApiProvider).updateSettings(<String, dynamic>{
        'theme_preference': value.trim(),
      });
      ref.invalidate(settingsProvider);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

final class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

final class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        TextField(
          controller: _next,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop([_current.text, _next.text]),
        child: const Text('Change'),
      ),
    ],
  );
}

final class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
  });

  final String title;
  final String initial;
  final String hint;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

final class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Save'),
      ),
    ],
  );
}

final class _RecalculateDialog extends StatefulWidget {
  const _RecalculateDialog({required this.inputs});

  final ProfileCalculationInputsModel inputs;

  @override
  State<_RecalculateDialog> createState() => _RecalculateDialogState();
}

final class _RecalculateDialogState extends State<_RecalculateDialog> {
  late String _goal = widget.inputs.goal;
  late String _activity = widget.inputs.activityLevel;
  late final _height = TextEditingController(text: '${widget.inputs.heightCm}');
  late final _weight = TextEditingController(text: '${widget.inputs.weightKg}');

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Recalculate target'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _goal,
          items: const ['weight_loss', 'maintain_weight', 'weight_gain']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => _goal = value ?? _goal),
          decoration: const InputDecoration(labelText: 'Goal'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _activity,
          items:
              const [
                    'sedentary',
                    'lightly_active',
                    'moderately_active',
                    'very_active',
                  ]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _activity = value ?? _activity),
          decoration: const InputDecoration(labelText: 'Activity level'),
        ),
        TextField(
          controller: _height,
          decoration: const InputDecoration(labelText: 'Height (cm)'),
        ),
        TextField(
          controller: _weight,
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          final height = double.tryParse(_height.text.trim());
          final weight = double.tryParse(_weight.text.trim());
          if (height == null || weight == null) return;
          Navigator.of(context).pop(
            ProfileCalculationInputsModel(
              goal: _goal,
              dateOfBirth: widget.inputs.dateOfBirth,
              formulaSex: widget.inputs.formulaSex,
              heightCm: height,
              weightKg: weight,
              activityLevel: _activity,
            ),
          );
        },
        child: const Text('Recalculate'),
      ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        Icon(icon, size: 48),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

String _friendlyError(Object error) => error is ApiError
    ? error.message
    : 'Kalonet could not load this information.';

String _label(String value) => value
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

String _dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Future<bool> _confirm(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result == true;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
