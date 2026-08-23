import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/features/onboarding/onboarding_api.dart';
import 'package:kalonet_frontend/features/onboarding/onboarding_models.dart';
import 'package:kalonet_frontend/features/onboarding/onboarding_providers.dart';
import 'package:kalonet_frontend/features/onboarding/presentation/onboarding_page.dart';

void main() {
  testWidgets('loads resumable onboarding state and validates the first step', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingApiProvider.overrideWithValue(_Gateway())],
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your plan'), findsOneWidget);
    await tester.tap(find.text('Save and continue'));
    await tester.pump();

    expect(find.text('Enter a valid number.'), findsNWidgets(2));
  });

  testWidgets('renders the onboarding controls on a narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [onboardingApiProvider.overrideWithValue(_Gateway())],
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save and continue'), findsAtLeastNWidgets(1));
  });
}

final class _Gateway implements OnboardingGateway {
  @override
  Future<OnboardingCompletion> complete(
    OnboardingCompletionRequest request,
  ) async {
    return OnboardingCompletion(
      completedAt: DateTime.utc(2026, 8, 19),
      target: _target,
    );
  }

  @override
  Future<OnboardingState> getState() async {
    return OnboardingState(
      status: 'not_started',
      goal: null,
      measurements: null,
      activityLevel: null,
      dietaryPreferences: const [],
      mealSchedule: const [],
      missingFields: const ['goal', 'height_cm'],
      nutritionTargetStatus: 'not_calculated',
      updatedAt: DateTime.utc(2026, 8, 19),
    );
  }

  @override
  Future<NutritionPreview> preview() async {
    return NutritionPreview(
      target: _target,
      warnings: const [],
      calculatedAt: DateTime.utc(2026, 8, 19),
    );
  }

  @override
  Future<OnboardingState> saveDraft(OnboardingDraftPatch patch) async {
    return getState();
  }
}

final _target = NutritionTarget(
  id: 'preview',
  calculationVersion: 'v1',
  caloriesKcal: 2200,
  proteinG: 160,
  carbohydrateG: 240,
  fatG: 70,
  effectiveFrom: DateTime.utc(2026, 8, 19),
  isActive: false,
);
