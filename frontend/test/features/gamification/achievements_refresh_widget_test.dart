import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/features/dashboard/presentation/dashboard_page.dart';
import 'package:kalonet_frontend/features/gamification/gamification_models.dart';
import 'package:kalonet_frontend/features/gamification/gamification_providers.dart';
import 'package:kalonet_frontend/features/onboarding/onboarding_models.dart';
import 'package:kalonet_frontend/features/profile/profile_models.dart';
import 'package:kalonet_frontend/features/profile/profile_providers.dart';
import 'package:kalonet_frontend/features/tracking/tracking_models.dart';
import 'package:kalonet_frontend/features/tracking/tracking_providers.dart';

void main() {
  testWidgets('Overview exposes and executes the shared achievements refresh', (
    WidgetTester tester,
  ) async {
    final date = _today();
    var summaryCalls = 0;
    var leaderboardCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamificationProvider.overrideWith((ref, date) async {
            summaryCalls++;
            return _summary(summaryCalls == 1 ? 10 : 25);
          }),
          leaderboardProvider.overrideWith((ref) async {
            leaderboardCalls++;
            return _leaderboard(totalXp: summaryCalls == 1 ? 10 : 25);
          }),
          dashboardProvider.overrideWith((ref, date) async => _dashboard(date)),
          mealsProvider.overrideWith((ref, date) async => _meals(date)),
          waterProvider.overrideWith((ref, date) async => _water(date)),
          stepsProvider.overrideWith((ref, date) async => _steps(date)),
          activitiesProvider.overrideWith(
            (ref, date) async => _activities(date),
          ),
          currentProfileProvider.overrideWith(
            (ref) => AsyncData<ProfileModel>(_profile(date)),
          ),
          currentProfileAvatarProvider.overrideWith(
            (ref) => const AsyncData<Uint8List?>(null),
          ),
          currentSettingsProvider.overrideWith(
            (ref) => const AsyncData<SettingsModel>(
              SettingsModel(
                measurementSystem: 'metric',
                timeZone: 'UTC',
                themePreference: 'system',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
    final currentDate = container.read(selectedDateProvider);
    expect(
      container.read(gamificationProvider(currentDate)).value?.totalXp,
      10,
    );

    final overviewList = find.byType(ListView).first;
    for (
      var attempt = 0;
      attempt < 4 && find.byTooltip('Refresh achievements').evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(overviewList, const Offset(0, -400));
      await tester.pumpAndSettle();
    }

    expect(find.byTooltip('Refresh achievements'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh achievements'));
    await tester.pumpAndSettle();

    expect(summaryCalls, greaterThan(1));
    expect(leaderboardCalls, 1);
    expect(
      container.read(gamificationProvider(currentDate)).value?.totalXp,
      25,
    );
    expect(tester.takeException(), isNull);
  });
}

GamificationSummaryModel _summary(int totalXp) {
  return GamificationSummaryModel(
    totalXp: totalXp,
    rank: 'E',
    nextRank: 'D',
    xpToNextRank: 490,
    dailyQuests: const [],
    weeklyQuests: const [],
    badges: const [
      BadgeProgressModel(
        code: 'FIRST_MEAL',
        title: 'First meal',
        description: 'Log your first meal',
        category: 'starter',
        unlocked: true,
        unlockedAt: null,
      ),
    ],
    unlockedBadgeCount: 1,
    totalBadgeCount: 13,
    leaderboardPosition: 1,
    leaderboardSize: 1,
  );
}

LeaderboardModel _leaderboard({required int totalXp}) {
  return LeaderboardModel(
    items: [
      LeaderboardEntryModel(
        position: 1,
        displayName: 'Ayo',
        totalXp: totalXp,
        rank: 'E',
        isCurrentUser: true,
      ),
    ],
    limit: 50,
    offset: 0,
    returned: 1,
    total: 1,
  );
}

ProfileModel _profile(DateTime date) {
  return ProfileModel(
    email: 'overview@example.com',
    nickname: 'Ayo',
    avatarPresent: false,
    onboardingCompletedAt: date,
    inputs: ProfileCalculationInputsModel(
      goal: 'maintain_weight',
      dateOfBirth: DateTime(1995, 1, 1),
      formulaSex: 'female',
      heightCm: 170,
      weightKg: 70,
      activityLevel: 'moderately_active',
    ),
    target: ProfileTargetModel(
      id: 'target',
      dailyCalories: 2000,
      proteinG: 140,
      carbohydrateG: 220,
      fatG: 65,
      effectiveFrom: date,
      ruleVersion: 'v1',
      isActive: true,
    ),
    preferences: const [],
    schedule: const [
      MealScheduleInput(preferredTime: '08:00', displayOrder: 1),
    ],
  );
}

DailyDashboardModel _dashboard(DateTime date) {
  const target = DashboardTargetModel(
    caloriesKcal: 2000,
    proteinG: 140,
    carbohydrateG: 220,
    fatG: 65,
  );
  return DailyDashboardModel(
    recordDate: date,
    timeZone: 'UTC',
    target: target,
    consumed: DashboardTargetModel(
      caloriesKcal: 500,
      proteinG: 35,
      carbohydrateG: 50,
      fatG: 15,
    ),
    remaining: DashboardTargetModel(
      caloriesKcal: 1500,
      proteinG: 105,
      carbohydrateG: 170,
      fatG: 50,
    ),
    mealCount: 1,
    itemCount: 1,
    waterConsumedMl: 500,
    waterTargetMl: 2500,
    stepCount: 1000,
    stepTarget: 10000,
    activityCount: 0,
    activityDurationMinutes: 0,
    activityCaloriesKcal: 0,
    generatedAt: date,
  );
}

MealsResponseModel _meals(DateTime date) {
  return MealsResponseModel(
    recordDate: date,
    items: const [],
    dailyTotals: const NutritionValuesModel(
      caloriesKcal: 0,
      proteinG: 0,
      carbohydrateG: 0,
      fatG: 0,
    ),
  );
}

WaterListModel _water(DateTime date) {
  return WaterListModel(
    recordDate: date,
    items: const [],
    totalMl: 0,
    targetMl: 2500,
  );
}

DailyStepsModel _steps(DateTime date) {
  return DailyStepsModel(recordDate: date, stepCount: 0, target: 10000);
}

ActivityListModel _activities(DateTime date) {
  return ActivityListModel(
    recordDate: date,
    items: const [],
    totalDurationMinutes: 0,
    totalCaloriesKcal: 0,
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
