import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/features/gamification/gamification_api.dart';
import 'package:kalonet_frontend/features/gamification/gamification_models.dart';
import 'package:kalonet_frontend/features/gamification/gamification_providers.dart';
import 'package:kalonet_frontend/features/gamification/presentation/gamification_page.dart';

void main() {
  test('refresh reloads the shared achievements providers together', () async {
    final gateway = _Gateway();
    final container = ProviderContainer(
      overrides: [gamificationApiProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final date = DateTime(2026, 8, 29);

    await container.read(gamificationProvider(date).future);
    await container.read(leaderboardProvider.future);
    gateway.totalXp = 25;
    gateway.displayName = 'Updated name';

    await container.read(achievementsRefreshControllerProvider).refresh(date);

    expect(gateway.summaryCalls, 2);
    expect(gateway.leaderboardCalls, 2);
    expect(container.read(gamificationProvider(date)).value?.totalXp, 25);
    expect(
      container.read(leaderboardProvider).value?.items.single.displayName,
      'Updated name',
    );
  });

  test('concurrent refresh taps share one in-flight request', () async {
    final gateway = _Gateway()..pauseNextSummary = true;
    final container = ProviderContainer(
      overrides: [gamificationApiProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    final date = DateTime(2026, 8, 29);
    final controller = container.read(achievementsRefreshControllerProvider);

    final first = controller.refresh(date);
    final second = controller.refresh(date);

    expect(identical(first, second), isTrue);
    expect(gateway.summaryCalls, 1);
    expect(gateway.leaderboardCalls, 1);

    gateway.releaseSummary();
    await Future.wait([first, second]);
  });

  testWidgets('the dedicated page uses the Achievements product name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gamificationProvider.overrideWith(
            (ref, date) async => _summary(totalXp: 25),
          ),
          leaderboardProvider.overrideWith(
            (ref) async => _leaderboard(displayName: 'Ayo'),
          ),
        ],
        child: const MaterialApp(home: GamificationPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Gamification'), findsNothing);
    expect(find.byTooltip('Refresh achievements'), findsOneWidget);
  });
}

final class _Gateway implements GamificationGateway {
  int summaryCalls = 0;
  int leaderboardCalls = 0;
  int totalXp = 10;
  String displayName = 'Initial name';
  bool pauseNextSummary = false;
  final Completer<void> _summaryGate = Completer<void>();

  @override
  Future<GamificationSummaryModel> summary(DateTime date) async {
    summaryCalls++;
    if (pauseNextSummary) {
      pauseNextSummary = false;
      await _summaryGate.future;
    }
    return _summary(totalXp: totalXp);
  }

  @override
  Future<LeaderboardModel> leaderboard({int limit = 50, int offset = 0}) async {
    leaderboardCalls++;
    return _leaderboard(displayName: displayName);
  }

  void releaseSummary() => _summaryGate.complete();
}

GamificationSummaryModel _summary({required int totalXp}) {
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

LeaderboardModel _leaderboard({required String displayName}) {
  return LeaderboardModel(
    items: [
      LeaderboardEntryModel(
        position: 1,
        displayName: displayName,
        totalXp: 10,
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
