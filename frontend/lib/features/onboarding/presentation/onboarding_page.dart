import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _breakfastController = TextEditingController(text: '08:00');
  final _lunchController = TextEditingController(text: '13:00');
  final _dinnerController = TextEditingController(text: '19:00');

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
    _breakfastController.dispose();
    _lunchController.dispose();
    _dinnerController.dispose();
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
    for (final item in state.mealSchedule) {
      switch (item.mealType) {
        case 'breakfast':
          _breakfastController.text = item.preferredTime;
          break;
        case 'lunch':
          _lunchController.text = item.preferredTime;
          break;
        case 'dinner':
          _dinnerController.text = item.preferredTime;
          break;
      }
    }
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
      MealScheduleInput(
        mealType: 'breakfast',
        preferredTime: _breakfastController.text.trim(),
        displayOrder: 1,
      ),
      MealScheduleInput(
        mealType: 'lunch',
        preferredTime: _lunchController.text.trim(),
        displayOrder: 2,
      ),
      MealScheduleInput(
        mealType: 'dinner',
        preferredTime: _dinnerController.text.trim(),
        displayOrder: 3,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errorMessage != null && _state == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadState,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your plan')),
      body: SafeArea(
        child: Stepper(
          currentStep: _currentStep,
          onStepTapped: (step) {
            if (step <= _currentStep) setState(() => _currentStep = step);
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
    return Column(
      children: [
        _timeField('Breakfast', _breakfastController),
        const SizedBox(height: 16),
        _timeField('Lunch', _lunchController),
        const SizedBox(height: 16),
        _timeField('Dinner', _dinnerController),
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

  Widget _timeField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(labelText: '$label time (HH:MM)'),
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
