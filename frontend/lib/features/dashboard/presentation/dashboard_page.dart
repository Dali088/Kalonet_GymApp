// The legacy private card declarations below remain temporarily for API-safe
// hot-reload compatibility while the active tab uses the Figma showcase cards.
// ignore_for_file: unused_element, unused_element_parameter

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/errors/api_error.dart';
import '../../../core/theme/kalonet_colors.dart';
import '../../../core/theme/kalonet_tokens.dart';
import '../../../core/widgets/kalonet_brand_mark.dart';
import '../../../core/widgets/kalonet_surface.dart';
import '../../auth/authentication_providers.dart';
import '../../gamification/gamification_models.dart';
import '../../gamification/gamification_providers.dart';
import '../../profile/profile_models.dart';
import '../../profile/profile_media.dart';
import '../../profile/profile_providers.dart';
import '../../onboarding/onboarding_models.dart';
import '../../tracking/tracking_models.dart';
import '../../tracking/tracking_providers.dart';
import '../../tracking/presentation/meal_photo_review_page.dart';

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
        .read(currentProfileProvider)
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
    final profileState = ref.watch(currentProfileProvider);
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
    final compactHeader = MediaQuery.sizeOf(context).width < 420;
    final dateAction = compactHeader
        ? IconButton(
            tooltip: 'Select date ${_dateLabel(selectedDate)}',
            onPressed: _pickDate,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48),
            icon: Text(
              _dateLabel(selectedDate),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: KalonetColors.primary),
            ),
          )
        : TextButton(
            onPressed: _pickDate,
            child: Text(_dateLabel(selectedDate)),
          );
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
          dateAction,
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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: KalonetGradients.page),
        child: IndexedStack(
          index: _tab,
          children: const [
            _OverviewTab(),
            _MealsTab(),
            _TrackingTab(),
            _ProfileTab(),
          ],
        ),
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
    final profile = ref
        .watch(currentProfileProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final gamificationState = ref.watch(gamificationProvider(date));
    final gamification = gamificationState.value;
    final meals = ref
        .watch(mealsProvider(date))
        .maybeWhen(data: (value) => value, orElse: () => null);
    return result.when(
      loading: () => const KalonetStatePanel.loading(
        message: 'Loading your daily snapshot...',
      ),
      error: (error, _) => _ErrorState(
        message: _friendlyError(error),
        onRetry: () => ref.invalidate(dashboardProvider(date)),
      ),
      data: (dashboard) => RefreshIndicator(
        onRefresh: () async {
          try {
            await Future.wait<Object?>([
              ref.refresh(dashboardProvider(date).future),
              ref.read(achievementsRefreshControllerProvider).refresh(date),
            ]);
          } on Object catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(KalonetSpacing.md),
          children: [
            _DashboardIdentityCard(
              profile: profile,
              gamification: gamification,
            ),
            const SizedBox(height: KalonetSpacing.sm),
            _DashboardMetricRow(dashboard: dashboard),
            const SizedBox(height: KalonetSpacing.md),
            _TodaySummaryCard(dashboard: dashboard),
            if (gamification != null) ...[
              const SizedBox(height: KalonetSpacing.lg),
              _DashboardCollectionPreview(summary: gamification),
              const SizedBox(height: KalonetSpacing.lg),
              _DashboardQuestPreview(summary: gamification),
            ],
            if (meals != null) ...[
              const SizedBox(height: KalonetSpacing.lg),
              _DashboardMealsPreview(meals: meals),
            ],
          ],
        ),
      ),
    );
  }
}

final class _DashboardMetricRow extends StatelessWidget {
  const _DashboardMetricRow({required this.dashboard});

  final DailyDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      KalonetMetricTile(
        icon: Icons.local_fire_department,
        label: 'Calories',
        value: _compactNumber(dashboard.consumed.caloriesKcal),
        detail: 'of ${dashboard.target.caloriesKcal} kcal',
        color: KalonetColors.nutrition,
      ),
      KalonetMetricTile(
        icon: Icons.water_drop,
        label: 'Water',
        value: '${dashboard.waterConsumedMl} ml',
        detail: dashboard.waterTargetMl == null
            ? 'No target'
            : 'of ${dashboard.waterTargetMl} ml',
        color: KalonetColors.hydration,
      ),
      KalonetMetricTile(
        icon: Icons.directions_walk,
        label: 'Steps',
        value: _compactNumber(dashboard.stepCount),
        detail: dashboard.stepTarget == null
            ? 'No target'
            : 'of ${dashboard.stepTarget}',
        color: KalonetColors.steps,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 360 ? 3 : 2;
        final gap = KalonetSpacing.sm;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final metric in metrics) SizedBox(width: width, child: metric),
          ],
        );
      },
    );
  }
}

final class _DashboardIdentityCard extends StatelessWidget {
  const _DashboardIdentityCard({this.profile, this.gamification});

  final ProfileModel? profile;
  final GamificationSummaryModel? gamification;

  @override
  Widget build(BuildContext context) {
    final name = profile?.nickname?.trim();
    final displayName = name == null || name.isEmpty ? 'Kalonet athlete' : name;
    return KalonetSurface(
      semanticLabel: 'Profile identity for $displayName',
      padding: const EdgeInsets.all(KalonetSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              const KalonetBrandMark(size: 56, showGlow: false),
              const SizedBox(width: KalonetSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (gamification != null)
                      Text(
                        'Rank ${gamification!.rank}  •  ${gamification!.totalXp} XP',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (gamification != null)
                _RankBadge(
                  rank: gamification!.rank,
                  position: gamification!.leaderboardPosition,
                  size: gamification!.leaderboardSize,
                ),
            ],
          ),
          if (gamification?.nextRank != null) ...[
            const SizedBox(height: KalonetSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: KalonetSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${gamification!.xpToNextRank} XP to rank ${gamification!.nextRank}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.position,
    required this.size,
  });

  final String rank;
  final int position;
  final int size;

  @override
  Widget build(BuildContext context) {
    final label = size > 0 ? '#$position / $size' : '#$position';
    return Semantics(
      label: 'Rank $rank, leaderboard position $label',
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KalonetColors.primary.withValues(alpha: 0.14),
              border: Border.all(color: KalonetColors.borderPale),
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Text(
                  rank,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: KalonetColors.primaryBright,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: KalonetSpacing.xxs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

final class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.dashboard});

  final DailyDashboardModel dashboard;

  @override
  Widget build(BuildContext context) {
    final nutritionRatio = dashboard.target.caloriesKcal == 0
        ? 0.0
        : dashboard.consumed.caloriesKcal / dashboard.target.caloriesKcal;
    return KalonetSurface(
      semanticLabel: 'Today summary',
      padding: const EdgeInsets.all(KalonetSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Today', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: KalonetSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.eco_outlined,
                  color: KalonetColors.primary,
                  value: '${dashboard.remaining.caloriesKcal}',
                  label: 'kcal remaining',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.favorite_outline,
                  color: KalonetColors.activity,
                  value: '${dashboard.activityDurationMinutes} min',
                  label: 'activity',
                ),
              ),
            ],
          ),
          const SizedBox(height: KalonetSpacing.md),
          KalonetProgressBar(
            value: nutritionRatio,
            color: KalonetColors.primary,
            height: 6,
            label: 'Calories consumed today',
          ),
          const SizedBox(height: KalonetSpacing.xs),
          Text(
            'Activity calories stay separate from your food allowance.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

final class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(KalonetRadii.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KalonetSpacing.xs),
            child: ExcludeSemantics(child: Icon(icon, color: color, size: 18)),
          ),
        ),
        const SizedBox(width: KalonetSpacing.xs),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

final class _DashboardCollectionPreview extends ConsumerWidget {
  const _DashboardCollectionPreview({required this.summary});

  final GamificationSummaryModel summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = summary.badges.take(3).toList();
    final date = ref.watch(selectedDateProvider);
    final refreshState = ref.watch(gamificationProvider(date));
    final isRefreshing = refreshState.isRefreshing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KalonetSectionHeader(
          title: 'Achievements',
          subtitle:
              '${summary.unlockedBadgeCount}/${summary.totalBadgeCount} unlocked',
          action: IconButton.filledTonal(
            tooltip: isRefreshing
                ? 'Refreshing achievements'
                : 'Refresh achievements',
            onPressed: isRefreshing
                ? null
                : () => _refreshAchievementsFromOverview(context, ref, date),
            icon: AnimatedSwitcher(
              duration: KalonetMotion.resolve(context, KalonetMotion.quick),
              child: isRefreshing
                  ? const SizedBox(
                      key: ValueKey('overview-achievements-refreshing'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh,
                      key: ValueKey('overview-achievements-refresh'),
                    ),
            ),
          ),
        ),
        const SizedBox(height: KalonetSpacing.sm),
        if (badges.isEmpty)
          const KalonetEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Your collection starts here',
            message: 'Complete a quest to unlock your first badge.',
          )
        else
          SizedBox(
            height: 134,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: badges.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: KalonetSpacing.sm),
              itemBuilder: (context, index) =>
                  _BadgePreview(badge: badges[index]),
            ),
          ),
      ],
    );
  }
}

Future<void> _refreshAchievementsFromOverview(
  BuildContext context,
  WidgetRef ref,
  DateTime date,
) async {
  try {
    await ref.read(achievementsRefreshControllerProvider).refresh(date);
  } on Object catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
  }
}

final class _BadgePreview extends StatelessWidget {
  const _BadgePreview({required this.badge});

  final BadgeProgressModel badge;

  @override
  Widget build(BuildContext context) {
    final color = badge.unlocked
        ? KalonetColors.gamification
        : KalonetColors.textMuted;
    return SizedBox(
      width: 142,
      child: KalonetSurface(
        padding: const EdgeInsets.all(KalonetSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(KalonetRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KalonetSpacing.xs),
                child: ExcludeSemantics(
                  child: Icon(
                    badge.unlocked
                        ? Icons.emoji_events_outlined
                        : Icons.lock_outline,
                    color: color,
                    size: 20,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              badge.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(badge.category, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

final class _DashboardQuestPreview extends StatelessWidget {
  const _DashboardQuestPreview({required this.summary});

  final GamificationSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final quests = [
      ...summary.dailyQuests,
      ...summary.weeklyQuests,
    ].take(2).toList();
    if (quests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KalonetSectionHeader(title: 'Active quests'),
        const SizedBox(height: KalonetSpacing.sm),
        ...quests.map((quest) => _DashboardQuestCard(quest: quest)),
      ],
    );
  }
}

final class _DashboardQuestCard extends StatelessWidget {
  const _DashboardQuestCard({required this.quest});

  final QuestProgressModel quest;

  @override
  Widget build(BuildContext context) {
    final progress = quest.target == 0 ? 0.0 : quest.current / quest.target;
    return KalonetSurface(
      margin: const EdgeInsets.only(bottom: KalonetSpacing.xs),
      padding: const EdgeInsets.all(KalonetSpacing.sm),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              quest.completed ? Icons.check_circle : Icons.bolt,
              color: quest.completed
                  ? KalonetColors.success
                  : KalonetColors.primary,
            ),
          ),
          const SizedBox(width: KalonetSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: KalonetSpacing.xxs),
                Text(
                  quest.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: KalonetSpacing.xs),
                KalonetProgressBar(
                  value: progress,
                  height: 5,
                  color: quest.completed
                      ? KalonetColors.success
                      : KalonetColors.primary,
                  label: 'Quest progress',
                ),
              ],
            ),
          ),
          const SizedBox(width: KalonetSpacing.sm),
          Text(
            '+${quest.rewardXp} XP',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

final class _DashboardMealsPreview extends StatelessWidget {
  const _DashboardMealsPreview({required this.meals});

  final MealsResponseModel meals;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KalonetSectionHeader(title: 'Today\'s meals'),
        const SizedBox(height: KalonetSpacing.sm),
        if (meals.items.isEmpty)
          const KalonetEmptyState(
            icon: Icons.restaurant_outlined,
            title: 'Nothing logged yet',
            message: 'Add your first meal from the Meals tab.',
          )
        else
          ...meals.items
              .take(3)
              .map(
                (meal) => KalonetSurface(
                  margin: const EdgeInsets.only(bottom: KalonetSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KalonetSpacing.sm,
                    vertical: KalonetSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.restaurant_outlined,
                          color: KalonetColors.primary,
                        ),
                      ),
                      const SizedBox(width: KalonetSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${_label(meal.mealType)}  •  ${meal.items.length} items',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${meal.totals.caloriesKcal.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

String _compactNumber(num value) {
  final raw = value.round().toString();
  final chunks = <String>[];
  for (var end = raw.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    chunks.insert(0, raw.substring(start, end));
  }
  return chunks.join(',');
}

final class _MealsTab extends ConsumerWidget {
  const _MealsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final result = ref.watch(mealsProvider(date));
    return result.when(
      loading: () =>
          const KalonetStatePanel.loading(message: 'Loading your meals...'),
      error: (error, _) => _ErrorState(
        message: _friendlyError(error),
        onRetry: () => ref.invalidate(mealsProvider(date)),
      ),
      data: (meals) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(mealsProvider(date)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            KalonetSpacing.md,
            KalonetSpacing.lg,
            KalonetSpacing.md,
            KalonetSpacing.xl,
          ),
          children: [
            KalonetSectionHeader(
              title: 'Meals',
              subtitle:
                  'Build today\'s record one intentional choice at a time.',
              action: IconButton.filled(
                tooltip: 'Add meal',
                onPressed: () => _showMealComposer(context, ref, date),
                icon: const Icon(Icons.add),
              ),
            ),
            const SizedBox(height: KalonetSpacing.md),
            _MealsDaySummary(meals: meals),
            const SizedBox(height: KalonetSpacing.lg),
            if (meals.items.isEmpty)
              KalonetEmptyState(
                icon: Icons.restaurant_outlined,
                title: 'A clean slate',
                message: 'No meals logged for this date yet.',
                action: FilledButton.icon(
                  onPressed: () => _showMealComposer(context, ref, date),
                  icon: const Icon(Icons.add),
                  label: const Text('Log your first meal'),
                ),
              ),
            ...meals.items.map((meal) => _MealCard(meal: meal, date: date)),
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

final class _MealsDaySummary extends StatelessWidget {
  const _MealsDaySummary({required this.meals});

  final MealsResponseModel meals;

  @override
  Widget build(BuildContext context) {
    final totals = meals.dailyTotals;
    return KalonetSurface(
      gradient: KalonetGradients.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _ProfileIconTile(
                icon: Icons.insights_outlined,
                color: KalonetColors.nutrition,
              ),
              const SizedBox(width: KalonetSpacing.sm),
              Expanded(
                child: Text(
                  'Today at a glance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${meals.items.length} ${meals.items.length == 1 ? 'meal' : 'meals'}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: KalonetSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MealSummaryStat(
                  label: 'Calories',
                  value: '${totals.caloriesKcal.toStringAsFixed(0)} kcal',
                  color: KalonetColors.nutrition,
                ),
              ),
              Expanded(
                child: _MealSummaryStat(
                  label: 'Protein',
                  value: '${totals.proteinG.toStringAsFixed(0)} g',
                  color: KalonetColors.primaryBright,
                ),
              ),
              Expanded(
                child: _MealSummaryStat(
                  label: 'Carbs',
                  value: '${totals.carbohydrateG.toStringAsFixed(0)} g',
                  color: KalonetColors.activity,
                ),
              ),
              Expanded(
                child: _MealSummaryStat(
                  label: 'Fat',
                  value: '${totals.fatG.toStringAsFixed(0)} g',
                  color: KalonetColors.steps,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _MealSummaryStat extends StatelessWidget {
  const _MealSummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: KalonetSpacing.xxs),
      Text(
        value,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    ],
  );
}

final class _MealCard extends ConsumerWidget {
  const _MealCard({required this.meal, required this.date});

  final MealModel meal;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KalonetSurface(
      margin: const EdgeInsets.only(bottom: KalonetSpacing.sm),
      padding: EdgeInsets.zero,
      accent: meal.items.isEmpty
          ? KalonetColors.borderPale
          : KalonetColors.primary.withValues(alpha: 0.45),
      semanticLabel:
          '${meal.name}, ${meal.items.length} items, ${meal.totals.caloriesKcal.toStringAsFixed(0)} calories',
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: KalonetSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          KalonetSpacing.md,
          0,
          KalonetSpacing.md,
          KalonetSpacing.xs,
        ),
        title: Row(
          children: [
            const _ProfileIconTile(
              icon: Icons.restaurant_outlined,
              color: KalonetColors.nutrition,
            ),
            const SizedBox(width: KalonetSpacing.sm),
            Expanded(child: Text(meal.name)),
          ],
        ),
        subtitle: Text('${_label(meal.mealType)} • ${meal.items.length} items'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${meal.totals.caloriesKcal.toStringAsFixed(0)} kcal',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
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
  String _mealType = 'breakfast';
  final String _recordedTime = '12:00';
  List<MealItemCreateInput>? _photoItems;
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
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _analyzeMealPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (!mounted || image == null) return;
      final mimeType = _mealPhotoMimeType(image.name);
      if (mimeType == null) {
        setState(() => _error = 'Choose a JPEG, PNG, or WebP image.');
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
      });
      final analysis = await ref
          .read(trackingApiProvider)
          .analyzeMealPhoto(
            bytes: await image.readAsBytes(),
            filename: image.name.isEmpty ? 'meal-photo.jpg' : image.name,
            mimeType: mimeType,
          );
      if (!mounted) return;
      final reviewed = await Navigator.of(context)
          .push<List<MealItemCreateInput>>(
            MaterialPageRoute(
              builder: (_) => MealPhotoReviewPage(analysis: analysis),
            ),
          );
      if (reviewed != null && mounted) {
        setState(() {
          _photoItems = reviewed;
          _error = null;
        });
      }
    } on ApiError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _error =
              'The server returned an unexpected AI response. Use manual entry instead.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The photo could not be selected or analyzed. Use manual entry instead.',
        );
      }
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
    if (_name.text.trim().isEmpty ||
        (_photoItems == null &&
            (_itemName.text.trim().isEmpty ||
                values.any((value) => value == null)))) {
      setState(
        () => _error = _photoItems == null
            ? 'Enter the food name and valid nutrition values.'
            : 'Enter a meal name.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // FRONTEND-BACKEND: Sends the reviewed proposal through the existing
      // meal endpoint, which stores its nutrition snapshot.
      final items =
          _photoItems ??
          [
            MealItemCreateInput(
              name: _itemName.text.trim(),
              quantity: values[0]!,
              servingDescription: _serving.text.trim(),
              nutrition: NutritionValuesModel(
                caloriesKcal: values[1]!,
                proteinG: values[2]!,
                carbohydrateG: values[3]!,
                fatG: values[4]!,
              ),
            ),
          ];
      await ref
          .read(trackingApiProvider)
          .createMeal(
            MealCreateInput(
              recordDate: widget.date,
              mealType: _mealType,
              name: _name.text.trim(),
              recordedTime: _recordedTime,
              items: items,
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
            if (_photoItems == null) ...[
              TextField(
                controller: _itemName,
                decoration: const InputDecoration(labelText: 'Food name'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _analyzeMealPhoto,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Analyze meal photo'),
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
                      decoration: const InputDecoration(
                        labelText: 'Protein (g)',
                      ),
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
            ] else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text('${_photoItems!.length} AI-reviewed food(s)'),
                  subtitle: const Text(
                    'Estimates will be saved as reviewed meal values.',
                  ),
                  trailing: IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _photoItems = null),
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear AI proposal',
                  ),
                ),
              ),
            ],
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

  String? _mealPhotoMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: $initialCount'),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Add steps'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 88,
              child: ElevatedButton(
                onPressed: _saving ? null : () => _add(context),
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Add'),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _saving ? null : () => _correct(context, initialCount),
          child: const Text('Correct total'),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final increment = int.tryParse(_controller.text.trim());
    if (increment == null || increment <= 0) return;
    setState(() => _saving = true);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final saved = await container
          .read(trackingApiProvider)
          .addSteps(widget.date, increment);
      if (context.mounted) {
        _controller.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Steps total: ${saved.stepCount}.')),
          );
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

  Future<void> _correct(BuildContext context, int currentCount) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Correct total steps',
        initial: '$currentCount',
        hint: '0 to 200000',
      ),
    );
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null || count < 0 || !context.mounted) return;
    setState(() => _saving = true);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(trackingApiProvider).setSteps(widget.date, count);
      container.invalidate(stepsProvider(widget.date));
      container.invalidate(dashboardProvider(widget.date));
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
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
      scrollable: true,
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
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          _label(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
    final profile = ref.watch(currentProfileProvider);
    final avatar = ref.watch(currentProfileAvatarProvider);
    final settings = ref.watch(currentSettingsProvider);
    final date = ref.watch(selectedDateProvider);
    final gamification = ref
        .watch(gamificationProvider(date))
        .maybeWhen(data: (value) => value, orElse: () => null);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KalonetSpacing.md,
        KalonetSpacing.lg,
        KalonetSpacing.md,
        KalonetSpacing.xl,
      ),
      children: [
        Center(
          child: ShaderMask(
            shaderCallback: (bounds) =>
                KalonetGradients.primary.createShader(bounds),
            child: Text(
              'My profile',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: KalonetSpacing.xs),
        Text(
          'Your plan, progress, and account details in one place.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: KalonetSpacing.lg),
        profile.when(
          loading: () => const KalonetStatePanel.loading(
            message: 'Loading your profile...',
          ),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => _invalidateCurrentProfile(ref),
          ),
          data: (value) => _ProfileShowcaseCard(
            profile: value,
            avatar: avatar,
            gamification: gamification,
          ),
        ),
        const SizedBox(height: KalonetSpacing.lg),
        const KalonetSectionHeader(title: 'Settings'),
        const SizedBox(height: KalonetSpacing.sm),
        settings.when(
          loading: () =>
              const KalonetStatePanel.loading(message: 'Loading settings...'),
          error: (error, _) => _ErrorState(
            message: _friendlyError(error),
            onRetry: () => _invalidateCurrentSettings(ref),
          ),
          data: (value) => _SettingsCard(settings: value),
        ),
        const SizedBox(height: KalonetSpacing.sm),
        KalonetSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileActionTile(
                icon: Icons.lock_outline,
                color: KalonetColors.activity,
                title: 'Change password',
                subtitle: 'Secure your account',
                onTap: () => _changePassword(context, ref),
              ),
              const Divider(height: 1),
              _ProfileActionTile(
                icon: Icons.emoji_events_outlined,
                color: KalonetColors.gamification,
                title: 'Achievements',
                subtitle: 'Quests, badges, and leaderboard',
                onTap: () => context.push('/gamification'),
              ),
            ],
          ),
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
  const _ProfileCard({
    required this.profile,
    required this.avatar,
    required this.gamification,
  });

  final ProfileModel profile;
  final AsyncValue<Uint8List?> avatar;
  final GamificationSummaryModel? gamification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputs = profile.inputs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              profile.nickname ?? profile.email,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (profile.nickname != null)
              Text(
                profile.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
              'Meals: ${profile.schedule.map((item) => 'Meal ${item.displayOrder} ${item.preferredTime}').join(', ')}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _editNickname(context, ref),
                  child: const Text('Nickname'),
                ),
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

  Future<void> _editNickname(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Profile nickname',
        initial: profile.nickname ?? '',
        hint: 'Optional, up to 32 characters',
      ),
    );
    if (value == null) return;
    final nickname = value.trim().isEmpty ? null : value.trim();
    try {
      await ref.read(profileApiProvider).updateNickname(nickname);
      _invalidateCurrentProfile(ref);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
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
      _invalidateCurrentProfile(ref);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _editSchedule(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Meal schedule',
        initial: profile.schedule.map((item) => item.preferredTime).join(', '),
        hint: '08:00, 13:00',
      ),
    );
    if (value == null) return;
    final schedule = <MealScheduleInput>[];
    for (final part in value.split(',')) {
      final time = part.trim();
      if (time.isNotEmpty) {
        schedule.add(
          MealScheduleInput(
            preferredTime: time,
            displayOrder: schedule.length + 1,
          ),
        );
      }
    }
    try {
      await ref.read(profileApiProvider).replaceSchedule(schedule);
      _invalidateCurrentProfile(ref);
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
      _invalidateCurrentProfile(ref);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

enum _AvatarChoice { camera, gallery, remove }

final class _ProfileShowcaseCard extends ConsumerWidget {
  const _ProfileShowcaseCard({
    required this.profile,
    required this.avatar,
    required this.gamification,
  });

  final ProfileModel profile;
  final AsyncValue<Uint8List?> avatar;
  final GamificationSummaryModel? gamification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = profile.nickname ?? _emailName(profile.email);
    final inputs = profile.inputs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KalonetSurface(
          gradient: KalonetGradients.surface,
          padding: const EdgeInsets.all(KalonetSpacing.md),
          child: Row(
            children: [
              _ProfileAvatar(
                avatar: avatar,
                fallback: _initials(displayName),
                onTap: () => _changeAvatar(context, ref),
              ),
              const SizedBox(width: KalonetSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      profile.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: KalonetSpacing.xs),
                    const _ProfileStatusChip(),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit nickname',
                onPressed: () => _editNickname(context, ref),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: KalonetSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - KalonetSpacing.sm) / 2;
            return Wrap(
              spacing: KalonetSpacing.sm,
              runSpacing: KalonetSpacing.sm,
              children: [
                SizedBox(
                  width: width,
                  child: _ProfileMetric(
                    icon: Icons.flag_outlined,
                    label: 'Goal',
                    value: _label(inputs.goal),
                    color: KalonetColors.activity,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ProfileMetric(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Daily target',
                    value: '${profile.target.dailyCalories} kcal',
                    color: KalonetColors.nutrition,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ProfileMetric(
                    icon: Icons.restaurant_outlined,
                    label: 'Scheduled meals',
                    value: '${profile.schedule.length} slots',
                    color: KalonetColors.primaryBright,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _ProfileMetric(
                    icon: Icons.monitor_weight_outlined,
                    label: 'Current weight',
                    value: '${_formatMetric(inputs.weightKg)} kg',
                    color: KalonetColors.steps,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: KalonetSpacing.md),
        KalonetSurface(
          child: Row(
            children: [
              const KalonetProgressRing(
                value: 1,
                label: 'READY',
                color: KalonetColors.primaryBright,
                size: 88,
              ),
              const SizedBox(width: KalonetSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your plan is active',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: KalonetSpacing.xxs),
                    Text(
                      '${_label(inputs.goal)} · ${_label(inputs.activityLevel)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: KalonetSpacing.sm),
                    Text(
                      '${profile.target.proteinG} g protein · ${profile.target.carbohydrateG} g carbs · ${profile.target.fatG} g fat',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (gamification != null) ...[
          const SizedBox(height: KalonetSpacing.md),
          KalonetSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _ProfileIconTile(
                      icon: Icons.auto_awesome,
                      color: KalonetColors.gamification,
                    ),
                    const SizedBox(width: KalonetSpacing.sm),
                    Expanded(
                      child: Text(
                        'Rewards collection',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${gamification!.unlockedBadgeCount}/${gamification!.totalBadgeCount}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: KalonetSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileRewardStat(
                        label: 'Rank',
                        value: gamification!.rank,
                      ),
                    ),
                    Expanded(
                      child: _ProfileRewardStat(
                        label: 'XP',
                        value: '${gamification!.totalXp}',
                      ),
                    ),
                    Expanded(
                      child: _ProfileRewardStat(
                        label: 'Board',
                        value: '#${gamification!.leaderboardPosition}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: KalonetSpacing.md),
        KalonetSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileActionTile(
                icon: Icons.badge_outlined,
                color: KalonetColors.gamification,
                title: 'Edit profile name',
                subtitle: 'Update your private display name',
                onTap: () => _editNickname(context, ref),
              ),
              const Divider(height: 1),
              _ProfileActionTile(
                icon: Icons.tune,
                color: KalonetColors.activity,
                title: 'Nutrition inputs',
                subtitle: 'Recalculate your target',
                onTap: () => _recalculate(context, ref),
              ),
              const Divider(height: 1),
              _ProfileActionTile(
                icon: Icons.restaurant_menu,
                color: KalonetColors.nutrition,
                title: 'Meal schedule',
                subtitle: '${profile.schedule.length} configured times',
                onTap: () => _editSchedule(context, ref),
              ),
              const Divider(height: 1),
              _ProfileActionTile(
                icon: Icons.dining_outlined,
                color: KalonetColors.primaryBright,
                title: 'Dietary preferences',
                subtitle: profile.preferences.isEmpty
                    ? 'None saved'
                    : profile.preferences.join(', '),
                onTap: () => _editPreferences(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<_AvatarChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(_AvatarChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(_AvatarChoice.gallery),
            ),
            if (profile.avatarPresent)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: KalonetColors.error,
                ),
                title: const Text('Remove photo'),
                onTap: () => Navigator.of(context).pop(_AvatarChoice.remove),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == _AvatarChoice.remove) {
      if (!await _confirm(context, 'Remove your profile photo?')) return;
      try {
        await ref.read(profileApiProvider).removeAvatar();
        _invalidateCurrentProfile(ref);
        final userId = ref.read(sessionUserIdProvider);
        if (userId != null) {
          await ref.read(profileProvider(userId).future);
        }
        _invalidateCurrentAvatar(ref);
      } on ApiError catch (error) {
        if (context.mounted) _showError(context, error.message);
      }
      return;
    }
    try {
      final source = choice == _AvatarChoice.camera
          ? ImageSource.camera
          : ImageSource.gallery;
      final image = await ref.read(profileImagePickerProvider).pick(source);
      if (image == null || !context.mounted) return;
      final contentType = _avatarMimeType(image.name);
      if (contentType == null) {
        _showError(context, 'Choose a JPEG, PNG, or WebP image.');
        return;
      }
      await ref
          .read(profileApiProvider)
          .uploadAvatar(
            bytes: await image.readAsBytes(),
            contentType: contentType,
          );
      _invalidateCurrentProfile(ref);
      final userId = ref.read(sessionUserIdProvider);
      if (userId != null) {
        await ref.read(profileProvider(userId).future);
      }
      _invalidateCurrentAvatar(ref);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'The profile photo could not be saved.');
      }
    }
  }

  Future<void> _editNickname(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: 'Profile nickname',
        initial: profile.nickname ?? '',
        hint: 'Optional, up to 32 characters',
      ),
    );
    if (value == null) return;
    try {
      await ref
          .read(profileApiProvider)
          .updateNickname(value.trim().isEmpty ? null : value.trim());
      _invalidateCurrentProfile(ref);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
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
      _invalidateCurrentProfile(ref);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }

  Future<void> _editSchedule(BuildContext context, WidgetRef ref) async {
    final value = await showDialog<List<String>>(
      context: context,
      builder: (_) => _ScheduleEditorDialog(
        initial: profile.schedule.map((item) => item.preferredTime).toList(),
      ),
    );
    if (value == null) return;
    try {
      await ref.read(profileApiProvider).replaceSchedule([
        for (var index = 0; index < value.length; index++)
          MealScheduleInput(
            preferredTime: value[index],
            displayOrder: index + 1,
          ),
      ]);
      _invalidateCurrentProfile(ref);
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
      _invalidateCurrentProfile(ref);
    } on ApiError catch (error) {
      if (context.mounted) _showError(context, error.message);
    }
  }
}

final class _ProfileAvatarLegacy extends StatelessWidget {
  const _ProfileAvatarLegacy({
    required this.avatar,
    required this.fallback,
    required this.onTap,
  });

  final AsyncValue<Uint8List?> avatar;
  final String fallback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = avatar.asData?.value;
    return Semantics(
      button: true,
      label: 'Profile photo. Edit photo',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(48),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: KalonetColors.primary.withValues(alpha: 0.18),
              backgroundImage: bytes == null ? null : MemoryImage(bytes),
              child: bytes == null
                  ? Text(
                      fallback,
                      style: const TextStyle(
                        color: KalonetColors.primaryBright,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KalonetColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: KalonetColors.surfaceElevated,
                    width: 3,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit,
                    size: 14,
                    color: KalonetColors.background,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProfileIconTileLegacy extends StatelessWidget {
  const _ProfileIconTileLegacy({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KalonetRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KalonetSpacing.xs),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

final class _ProfileStatusChipLegacy extends StatelessWidget {
  const _ProfileStatusChipLegacy();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KalonetColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KalonetRadii.pill),
        border: Border.all(color: KalonetColors.borderPale),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: KalonetSpacing.xs,
          vertical: 3,
        ),
        child: Text(
          'PLAN ACTIVE',
          style: TextStyle(
            color: KalonetColors.primaryBright,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

final class _ProfileMetricLegacy extends StatelessWidget {
  const _ProfileMetricLegacy({
    required this.icon,
    required this.label,
    required this.color,
    this.value,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      semanticLabel: '$label${value == null ? '' : ', $value'}',
      padding: const EdgeInsets.all(KalonetSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileIconTile(icon: icon, color: color),
          const SizedBox(height: KalonetSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: KalonetSpacing.xxs),
          Text(
            value ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

final class _ProfileRewardStatLegacy extends StatelessWidget {
  const _ProfileRewardStatLegacy({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: KalonetSpacing.xxs),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

final class _ProfileActionTileLegacy extends StatelessWidget {
  const _ProfileActionTileLegacy({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _ProfileIconTile(icon: icon, color: color),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
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
      _invalidateCurrentSettings(ref);
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
    scrollable: true,
    title: const Text('Recalculate target'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _goal,
          isExpanded: true,
          items: const ['weight_loss', 'maintain_weight', 'weight_gain']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    _label(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _goal = value ?? _goal),
          decoration: const InputDecoration(labelText: 'Goal'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _activity,
          isExpanded: true,
          items:
              const [
                    'sedentary',
                    'lightly_active',
                    'moderately_active',
                    'very_active',
                  ]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        _label(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

final class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatar,
    required this.fallback,
    required this.onTap,
  });

  final AsyncValue<Uint8List?> avatar;
  final String fallback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = avatar.asData?.value;
    return Semantics(
      button: true,
      label: 'Profile photo. Edit photo',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(48),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: KalonetColors.primary.withValues(alpha: 0.18),
              backgroundImage: bytes == null ? null : MemoryImage(bytes),
              child: bytes == null
                  ? Text(
                      fallback,
                      style: const TextStyle(
                        color: KalonetColors.primaryBright,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KalonetColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: KalonetColors.surfaceElevated,
                    width: 3,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit,
                    size: 14,
                    color: KalonetColors.background,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProfileIconTile extends StatelessWidget {
  const _ProfileIconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(KalonetRadii.sm),
    ),
    child: Padding(
      padding: const EdgeInsets.all(KalonetSpacing.xs),
      child: Icon(icon, color: color, size: 20),
    ),
  );
}

final class _ProfileStatusChip extends StatelessWidget {
  const _ProfileStatusChip();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: KalonetColors.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(KalonetRadii.pill),
      border: Border.all(color: KalonetColors.borderPale),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: KalonetSpacing.xs, vertical: 3),
      child: Text(
        'PLAN ACTIVE',
        style: TextStyle(
          color: KalonetColors.primaryBright,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}

final class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.icon,
    required this.label,
    required this.color,
    this.value,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? value;

  @override
  Widget build(BuildContext context) => KalonetSurface(
    semanticLabel: '$label${value == null ? '' : ', $value'}',
    padding: const EdgeInsets.all(KalonetSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfileIconTile(icon: icon, color: color),
        const SizedBox(height: KalonetSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: KalonetSpacing.xxs),
        Text(
          value ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

final class _ProfileRewardStat extends StatelessWidget {
  const _ProfileRewardStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: KalonetSpacing.xxs),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

final class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: _ProfileIconTile(icon: icon, color: color),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

final class _ScheduleEditorDialog extends StatefulWidget {
  const _ScheduleEditorDialog({required this.initial});

  final List<String> initial;

  @override
  State<_ScheduleEditorDialog> createState() => _ScheduleEditorDialogState();
}

final class _ScheduleEditorDialogState extends State<_ScheduleEditorDialog> {
  late final List<TextEditingController> _controllers = [
    for (final value in widget.initial.isEmpty ? ['12:00'] : widget.initial)
      TextEditingController(text: value),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Meal schedule'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (var index = 0; index < _controllers.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: KalonetSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers[index],
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          labelText: 'Meal ${index + 1} time',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _controllers.length > 1
                          ? 'Remove meal ${index + 1}'
                          : 'One meal required',
                      onPressed: _controllers.length > 1
                          ? () => setState(() {
                              _controllers.removeAt(index).dispose();
                            })
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: _controllers.length == 15
                  ? null
                  : () => setState(() {
                      _controllers.add(TextEditingController(text: '12:00'));
                    }),
              icon: const Icon(Icons.add),
              label: Text(
                _controllers.length == 15 ? '15 meals configured' : 'Add meal',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          final values = _controllers
              .map((controller) => controller.text.trim())
              .toList();
          if (values.any((value) => !_isValidTime(value))) return;
          Navigator.of(context).pop(values);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

String _emailName(String email) => email.split('@').first;

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'K';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _formatMetric(double value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

String? _avatarMimeType(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}

bool _isValidTime(String value) =>
    RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      KalonetStatePanel.error(error: message, onRetry: onRetry);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) =>
      KalonetEmptyState(icon: icon, title: 'A clean slate', message: message);
}

void _invalidateCurrentProfile(WidgetRef ref) {
  final userId = ref.read(sessionUserIdProvider);
  if (userId != null) ref.invalidate(profileProvider(userId));
}

void _invalidateCurrentAvatar(WidgetRef ref) {
  final userId = ref.read(sessionUserIdProvider);
  if (userId != null) ref.invalidate(profileAvatarProvider(userId));
}

void _invalidateCurrentSettings(WidgetRef ref) {
  final userId = ref.read(sessionUserIdProvider);
  if (userId != null) ref.invalidate(settingsProvider(userId));
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
