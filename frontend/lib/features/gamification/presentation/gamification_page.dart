import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/theme/kalonet_colors.dart';
import '../../../core/theme/kalonet_tokens.dart';
import '../../../core/widgets/kalonet_brand_mark.dart';
import '../../../core/widgets/kalonet_surface.dart';
import '../../tracking/tracking_providers.dart';
import '../gamification_models.dart';
import '../gamification_providers.dart';

final class GamificationPage extends ConsumerWidget {
  const GamificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final summary = ref.watch(gamificationProvider(date));
    final leaderboard = ref.watch(leaderboardProvider);
    final isRefreshing = summary.isRefreshing || leaderboard.isRefreshing;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            tooltip: isRefreshing
                ? 'Refreshing achievements'
                : 'Refresh achievements',
            onPressed: isRefreshing
                ? null
                : () => _refreshAchievements(context, ref, date),
            icon: AnimatedSwitcher(
              duration: KalonetMotion.resolve(context, KalonetMotion.quick),
              child: isRefreshing
                  ? const SizedBox(
                      key: ValueKey('achievements-refreshing'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh,
                      key: ValueKey('achievements-refresh'),
                    ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: KalonetGradients.page),
        child: summary.when(
          loading: () => const KalonetStatePanel.loading(
            message: 'Loading your progress...',
          ),
          error: (error, _) => KalonetStatePanel.error(
            error: _friendlyError(error),
            onRetry: () => _refreshAchievements(context, ref, date),
          ),
          data: (value) => RefreshIndicator(
            onRefresh: () => _refreshAchievements(context, ref, date),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: KalonetSpacing.page,
                vertical: KalonetSpacing.md,
              ),
              children: [
                _ProgressCard(summary: value),
                const SizedBox(height: KalonetSpacing.lg),
                _QuestSection(
                  title: 'Today\'s quests',
                  subtitle: 'Momentum is built from repeatable actions.',
                  quests: value.dailyQuests,
                ),
                const SizedBox(height: KalonetSpacing.lg),
                _QuestSection(
                  title: 'This week',
                  subtitle: 'Keep your streak moving forward.',
                  quests: value.weeklyQuests,
                ),
                const SizedBox(height: KalonetSpacing.lg),
                _BadgeSection(summary: value),
                const SizedBox(height: KalonetSpacing.lg),
                _LeaderboardSection(result: leaderboard, summary: value),
              ],
            ),
          ),
          skipError: true,
        ),
      ),
    );
  }
}

final class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});

  final GamificationSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final badgeProgress = summary.totalBadgeCount == 0
        ? 0.0
        : summary.unlockedBadgeCount / summary.totalBadgeCount;
    return KalonetSurface(
      gradient: KalonetGradients.surface,
      accent: KalonetColors.gamification.withValues(alpha: 0.7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rank ${summary.rank}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: KalonetSpacing.xxs),
              Text('${summary.totalXp} XP earned'),
              if (summary.nextRank != null)
                Text(
                  '${summary.xpToNextRank} XP to rank ${summary.nextRank}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: KalonetSpacing.sm),
              Text(
                '#${summary.leaderboardPosition} of ${summary.leaderboardSize} • '
                '${summary.unlockedBadgeCount}/${summary.totalBadgeCount} badges',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
          final ring = KalonetProgressRing(
            value: badgeProgress,
            label: '${(badgeProgress * 100).round()}%',
            color: KalonetColors.gamification,
            size: 72,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KalonetBrandMark(size: 64),
                    const SizedBox(width: KalonetSpacing.sm),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: KalonetSpacing.md),
                Align(alignment: Alignment.centerRight, child: ring),
              ],
            );
          }
          return Row(
            children: [
              const KalonetBrandMark(size: 72),
              const SizedBox(width: KalonetSpacing.md),
              Expanded(child: details),
              ring,
            ],
          );
        },
      ),
    );
  }
}

final class _QuestSection extends StatelessWidget {
  const _QuestSection({
    required this.title,
    required this.subtitle,
    required this.quests,
  });

  final String title;
  final String subtitle;
  final List<QuestProgressModel> quests;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KalonetSectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: KalonetSpacing.sm),
        ...quests.map((quest) => _QuestCard(quest: quest)),
      ],
    );
  }
}

final class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final QuestProgressModel quest;

  @override
  Widget build(BuildContext context) {
    final progress = quest.target == 0 ? 0.0 : quest.current / quest.target;
    return KalonetSurface(
      margin: const EdgeInsets.only(bottom: KalonetSpacing.xs),
      accent: quest.completed
          ? KalonetColors.success.withValues(alpha: 0.7)
          : KalonetColors.border,
      padding: const EdgeInsets.all(KalonetSpacing.sm),
      child: Row(
        children: [
          Icon(
            quest.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: quest.completed
                ? KalonetColors.success
                : KalonetColors.textSecondary,
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
                const SizedBox(height: KalonetSpacing.xxs),
                Text(
                  '${quest.current}/${quest.target}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: KalonetSpacing.sm),
          Text(
            '+${quest.rewardXp} XP',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

final class _BadgeSection extends StatelessWidget {
  const _BadgeSection({required this.summary});

  final GamificationSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final badgesByCategory = <String, List<BadgeProgressModel>>{};
    for (final badge in summary.badges) {
      badgesByCategory.putIfAbsent(badge.category, () => []).add(badge);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KalonetSectionHeader(
          title: 'Badge collection',
          subtitle:
              '${summary.unlockedBadgeCount} unlocked of ${summary.totalBadgeCount}',
        ),
        const SizedBox(height: KalonetSpacing.sm),
        if (summary.badges.isEmpty)
          const KalonetEmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Your collection starts here',
            message: 'Complete a quest to unlock your first badge.',
          ),
        if (badgesByCategory.isNotEmpty)
          ...badgesByCategory.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: KalonetSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: KalonetSpacing.xs),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entry.value.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: KalonetSpacing.sm,
                          mainAxisSpacing: KalonetSpacing.sm,
                          // Badge content has a fixed, shared vertical budget
                          // for the icon, status, title, and description.
                          mainAxisExtent: 168,
                        ),
                    itemBuilder: (context, index) =>
                        _BadgeCard(badge: entry.value[index]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

final class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final BadgeProgressModel badge;

  @override
  Widget build(BuildContext context) {
    final color = badge.unlocked
        ? KalonetColors.gamification
        : KalonetColors.textMuted;
    return KalonetSurface(
      semanticLabel:
          '${badge.title}. ${badge.unlocked ? 'Unlocked' : 'Locked'}. '
          '${badge.description}',
      padding: const EdgeInsets.all(KalonetSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              if (badge.unlocked)
                Flexible(
                  child: Text(
                    'UNLOCKED',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: KalonetColors.gamification,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            badge.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: KalonetSpacing.xxs),
          Text(
            badge.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

final class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.result, required this.summary});

  final AsyncValue<LeaderboardModel> result;
  final GamificationSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KalonetSectionHeader(
          title: 'All-time leaderboard',
          subtitle: 'Compete with your own consistency first.',
        ),
        const SizedBox(height: KalonetSpacing.sm),
        result.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) =>
              KalonetSurface(child: Text(_friendlyError(error))),
          data: (leaderboard) => leaderboard.items.isEmpty
              ? const KalonetEmptyState(
                  icon: Icons.leaderboard_outlined,
                  title: 'Leaderboard is warming up',
                  message:
                      'Keep showing up and your progress will appear here.',
                )
              : Column(
                  children: [
                    _LeaderboardHero(summary: summary),
                    const SizedBox(height: KalonetSpacing.sm),
                    ...leaderboard.items.map(_LeaderboardRow.new),
                  ],
                ),
          skipError: true,
        ),
      ],
    );
  }
}

final class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({required this.summary});

  final GamificationSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      gradient: KalonetGradients.surface,
      accent: KalonetColors.primary.withValues(alpha: 0.65),
      padding: const EdgeInsets.all(KalonetSpacing.md),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: KalonetColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(KalonetRadii.md),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KalonetSpacing.md,
                vertical: KalonetSpacing.sm,
              ),
              child: Text(
                '#${summary.leaderboardPosition}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: KalonetColors.primaryBright,
                ),
              ),
            ),
          ),
          const SizedBox(width: KalonetSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your position',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Rank ${summary.rank} • ${summary.totalXp} XP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            'of ${summary.leaderboardSize}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

final class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow(this.entry);

  final LeaderboardEntryModel entry;

  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      margin: const EdgeInsets.only(bottom: KalonetSpacing.xs),
      accent: entry.isCurrentUser
          ? KalonetColors.primary.withValues(alpha: 0.65)
          : KalonetColors.border,
      padding: const EdgeInsets.symmetric(
        horizontal: KalonetSpacing.sm,
        vertical: KalonetSpacing.xs,
      ),
      semanticLabel:
          '${entry.displayName}, position ${entry.position}, rank ${entry.rank}, '
          '${entry.totalXp} XP${entry.isCurrentUser ? ', you' : ''}',
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${entry.position}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isCurrentUser
                      ? '${entry.displayName} (you)'
                      : entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Rank ${entry.rank}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalXp} XP',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is ApiError) return error.message;
  if (error is FormatException) return 'Kalonet returned an invalid response.';
  return 'Kalonet could not load this information.';
}

Future<void> _refreshAchievements(
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
