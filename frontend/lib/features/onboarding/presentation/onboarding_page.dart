import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/kalonet_colors.dart';
import '../../../core/theme/kalonet_tokens.dart';
import '../../../core/widgets/kalonet_brand_mark.dart';
import '../../../core/widgets/kalonet_surface.dart';
import '../../../core/auth/session_providers.dart';
import '../../../core/errors/api_error.dart';
import '../onboarding_models.dart';
import '../onboarding_providers.dart';

final class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

final class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _basicsFormKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _preferencesController = TextEditingController();
  final List<TextEditingController> _mealTimeControllers = [
    TextEditingController(text: '08:00'),
    TextEditingController(text: '13:00'),
    TextEditingController(text: '19:00'),
  ];

  static const _goals = <String>[
    'weight_loss',
    'maintain_weight',
    'weight_gain',
  ];
  static const _sexes = <String>['male', 'female'];
  static const _activityLevels = <String>[
    'sedentary',
    'lightly_active',
    'moderately_active',
    'very_active',
  ];

  String _goal = 'maintain_weight';
  String _sexForFormula = 'male';
  String _activityLevel = 'moderately_active';
  DateTime? _dateOfBirth;
  OnboardingState? _state;
  NutritionPreview? _preview;
  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _acceptedTarget = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _preferencesController.dispose();
    for (final controller in _mealTimeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final state = await ref.read(onboardingApiProvider).getState();
      if (!mounted) return;
      _hydrate(state);
      setState(() => _isLoading = false);
    } on ApiError catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message;
        });
      }
    } on FormatException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'The server returned an unexpected onboarding response.';
        });
      }
    }
  }

  void _hydrate(OnboardingState state) {
    _state = state;
    if (state.goal != null && _goals.contains(state.goal)) _goal = state.goal!;
    if (state.activityLevel != null &&
        _activityLevels.contains(state.activityLevel)) {
      _activityLevel = state.activityLevel!;
    }
    final measurements = state.measurements;
    if (measurements != null) {
      _dateOfBirth = measurements.dateOfBirth;
      if (_sexes.contains(measurements.sexForFormula)) {
        _sexForFormula = measurements.sexForFormula;
      }
      _heightController.text = _formatNumber(measurements.heightCm);
      _weightController.text = _formatNumber(measurements.weightKg);
    }
    _preferencesController.text = state.dietaryPreferences.join(', ');
    if (state.mealSchedule.isNotEmpty) {
      final schedule = [...state.mealSchedule]
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      _setMealTimes(schedule.map((item) => item.preferredTime).toList());
    }
  }

  void _setMealTimes(List<String> values) {
    for (final controller in _mealTimeControllers) {
      controller.dispose();
    }
    _mealTimeControllers
      ..clear()
      ..addAll(values.map((value) => TextEditingController(text: value)));
  }

  Future<bool> _saveBasics() async {
    if (!(_basicsFormKey.currentState?.validate() ?? false)) return false;
    if (_dateOfBirth == null) {
      setState(() => _errorMessage = 'Date of birth is required.');
      return false;
    }

    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (height == null || weight == null) {
      setState(
        () => _errorMessage = 'Height and weight must be valid numbers.',
      );
      return false;
    }

    return _runSave(() async {
      _state = await ref
          .read(onboardingApiProvider)
          .saveDraft(
            OnboardingDraftPatch(
              goal: _goal,
              activityLevel: _activityLevel,
              measurements: Measurements(
                dateOfBirth: _dateOfBirth!,
                sexForFormula: _sexForFormula,
                heightCm: height,
                weightKg: weight,
              ),
            ),
          );
    });
  }

  Future<bool> _savePreferences() async {
    final preferences = _preferencesController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return _runSave(() async {
      _state = await ref
          .read(onboardingApiProvider)
          .saveDraft(OnboardingDraftPatch(dietaryPreferences: preferences));
    });
  }

  Future<bool> _saveSchedule() async {
    final schedule = [
      for (var index = 0; index < _mealTimeControllers.length; index++)
        MealScheduleInput(
          preferredTime: _mealTimeControllers[index].text.trim(),
          displayOrder: index + 1,
        ),
    ];
    if (schedule.any((item) => !_isValidTime(item.preferredTime))) {
      setState(() => _errorMessage = 'Meal times must use HH:MM format.');
      return false;
    }
    return _runSave(() async {
      _state = await ref
          .read(onboardingApiProvider)
          .saveDraft(OnboardingDraftPatch(mealSchedule: schedule));
    });
  }

  Future<bool> _runSave(Future<void> Function() save) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await save();
      _preview = null;
      _acceptedTarget = false;
      return true;
    } on ApiError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
      return false;
    } on FormatException {
      if (mounted) {
        setState(
          () => _errorMessage = 'The server returned an unexpected response.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _continue() async {
    final saved = switch (_currentStep) {
      0 => await _saveBasics(),
      1 => await _savePreferences(),
      2 => await _saveSchedule(),
      _ => true,
    };
    if (!saved || !mounted) return;
    setState(() {
      _errorMessage = null;
      _currentStep = _currentStep < 3 ? _currentStep + 1 : 3;
    });
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final preview = await ref.read(onboardingApiProvider).preview();
      if (mounted) setState(() => _preview = preview);
    } on ApiError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _errorMessage = 'The server returned an unexpected response.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _complete() async {
    if (!_acceptedTarget) {
      setState(
        () => _errorMessage = 'Accept the proposed target before continuing.',
      );
      return;
    }
    if (_preview == null) await _loadPreview();
    if (_preview == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(onboardingApiProvider)
          .complete(const OnboardingCompletionRequest(acceptedTarget: true));
      ref.read(sessionControllerProvider.notifier).markOnboardingCompleted();
      if (mounted) context.go('/dashboard');
    } on ApiError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _errorMessage = 'The server returned an unexpected response.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickMealTime(int index) async {
    final parts = _mealTimeControllers[index].text.split(':');
    final parsedHour = int.tryParse(parts.first) ?? 12;
    final parsedMinute = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;
    final initialTime = parts.length == 2
        ? TimeOfDay(
            hour: parsedHour < 0
                ? 0
                : parsedHour > 23
                ? 23
                : parsedHour,
            minute: parsedMinute < 0
                ? 0
                : parsedMinute > 59
                ? 59
                : parsedMinute,
          )
        : const TimeOfDay(hour: 12, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Choose meal time',
    );
    if (picked != null && mounted) {
      _mealTimeControllers[index].text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  void _addMeal() {
    if (_mealTimeControllers.length >= 15) return;
    setState(() {
      _mealTimeControllers.add(TextEditingController(text: '12:00'));
    });
  }

  void _removeMeal(int index) {
    if (_mealTimeControllers.length <= 1) return;
    final controller = _mealTimeControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: KalonetGradients.page),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KalonetBrandMark(size: 72),
                SizedBox(height: KalonetSpacing.md),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }
    if (_errorMessage != null && _state == null) {
      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: KalonetGradients.page),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KalonetBrandMark(size: 72),
                const SizedBox(height: KalonetSpacing.md),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: KalonetSpacing.md),
                ElevatedButton(
                  onPressed: _loadState,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your plan')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: KalonetGradients.page),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (_, _) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Stepper(
                  currentStep: _currentStep,
                  onStepTapped: (step) {
                    if (step <= _currentStep) {
                      setState(() => _currentStep = step);
                    }
                  },
                  controlsBuilder: (_, _) => _buildControls(),
                  steps: [
                    Step(
                      title: const Text('Your basics'),
                      isActive: _currentStep >= 0,
                      content: _buildBasics(),
                    ),
                    Step(
                      title: const Text('Preferences'),
                      isActive: _currentStep >= 1,
                      content: _buildPreferences(),
                    ),
                    Step(
                      title: const Text('Meal schedule'),
                      isActive: _currentStep >= 2,
                      content: _buildSchedule(),
                    ),
                    Step(
                      title: const Text('Review your target'),
                      isActive: _currentStep >= 3,
                      content: _buildReview(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (_currentStep == 3) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton(
              onPressed: _isSaving ? null : _loadPreview,
              child: const Text('Refresh preview'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _acceptedTarget,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _acceptedTarget = value ?? false),
              title: const Text('I accept this nutrition target.'),
            ),
            ElevatedButton(
              onPressed: _isSaving ? null : _complete,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Complete onboarding'),
            ),
            if (_errorMessage != null) _errorText(),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() => _currentStep -= 1),
              child: const Text('Back'),
            ),
          ElevatedButton(
            onPressed: _isSaving ? null : _continue,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save and continue'),
          ),
          if (_errorMessage != null) _errorText(),
        ],
      ),
    );
  }

  Widget _buildBasics() {
    return Form(
      key: _basicsFormKey,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _goal,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Goal'),
            items: _goals
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_label(value), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _goal = value ?? _goal),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _dateOfBirth == null
                  ? 'Date of birth'
                  : 'Date of birth: ${_dateOnly(_dateOfBirth!)}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          DropdownButtonFormField<String>(
            initialValue: _sexForFormula,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sex used for calculation',
            ),
            items: _sexes
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_label(value), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _sexForFormula = value ?? _sexForFormula),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Height (cm)'),
            validator: _numberValidator,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
            validator: _numberValidator,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _activityLevel,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Activity level'),
            items: _activityLevels
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_label(value), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _activityLevel = value ?? _activityLevel),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Optional: separate dietary preferences with commas.'),
        const SizedBox(height: 16),
        TextField(
          controller: _preferencesController,
          decoration: const InputDecoration(
            labelText: 'Dietary preferences',
            hintText: 'vegetarian, halal',
          ),
        ),
      ],
    );
  }

  Widget _buildSchedule() {
    final atMaximum = _mealTimeControllers.length == 15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Set the times that fit your routine. You can configure 1 to 15 meals.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: KalonetSpacing.md),
        AnimatedSize(
          duration: KalonetMotion.resolve(context, KalonetMotion.standard),
          curve: KalonetMotion.curve,
          child: Column(
            children: [
              for (var index = 0; index < _mealTimeControllers.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: KalonetSpacing.sm),
                  child: _MealScheduleRow(
                    key: ValueKey(_mealTimeControllers[index]),
                    index: index,
                    controller: _mealTimeControllers[index],
                    canRemove: _mealTimeControllers.length > 1,
                    onPickTime: () => _pickMealTime(index),
                    onRemove: () => _removeMeal(index),
                  ),
                ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: atMaximum ? null : _addMeal,
          icon: const Icon(Icons.add),
          label: Text(atMaximum ? '15 meals configured' : 'Add meal'),
        ),
      ],
    );
  }

  Widget _buildReview() {
    final preview = _preview;
    if (preview == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your saved inputs are ready for a server-authoritative preview.',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _loadPreview,
            child: const Text('Calculate my target'),
          ),
          if (_errorMessage != null) _errorText(),
        ],
      );
    }
    final target = preview.target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${target.caloriesKcal} kcal per day',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          'Protein ${target.proteinG} g • Carbs ${target.carbohydrateG} g • Fat ${target.fatG} g',
        ),
        if (preview.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...preview.warnings.map((warning) => Text('• $warning')),
        ],
        const SizedBox(height: 12),
        const Text('You can go back and correct any input before accepting.'),
      ],
    );
  }

  Widget _errorText() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  String? _numberValidator(String? value) {
    if (value == null || double.tryParse(value.trim()) == null) {
      return 'Enter a valid number.';
    }
    return null;
  }
}

final class _MealScheduleRow extends StatelessWidget {
  const _MealScheduleRow({
    required this.index,
    required this.controller,
    required this.canRemove,
    required this.onPickTime,
    required this.onRemove,
    super.key,
  });

  final int index;
  final TextEditingController controller;
  final bool canRemove;
  final VoidCallback onPickTime;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      padding: const EdgeInsets.all(KalonetSpacing.sm),
      accent: KalonetColors.borderPale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KalonetColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KalonetRadii.sm),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: KalonetColors.primaryBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: KalonetSpacing.sm),
              Expanded(
                child: Text(
                  'Meal ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: canRemove
                    ? 'Remove meal ${index + 1}'
                    : 'One meal required',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: KalonetSpacing.xs),
          TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: 'Time (HH:MM)',
              suffixIcon: IconButton(
                tooltip: 'Choose time',
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _label(String value) {
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

bool _isValidTime(String value) {
  return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
