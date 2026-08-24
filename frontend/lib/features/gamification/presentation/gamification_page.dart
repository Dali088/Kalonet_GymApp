import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_error.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Gamification')),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorCard(
          message: _friendlyError(error),
          onRetry: () => ref.invalidate(gamificationProvider(date)),
        ),
        data: (value) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(gamificationProvider(date));
            ref.invalidate(leaderboardProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProgressCard(summary: value),
              const SizedBox(height: 16),
              _QuestSection(
                title: 'Today\'s quests',
                quests: value.dailyQuests,
              ),
              const SizedBox(height: 16),
              _QuestSection(title: 'This week', quests: value.weeklyQuests),
              const SizedBox(height: 16),
              _BadgeSection(summary: value),
              const SizedBox(height: 16),
              _LeaderboardSection(result: leaderboard),
            ],
          ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rank ${summary.rank}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text('${summary.totalXp} XP'),
            if (summary.nextRank != null) ...[
              const SizedBox(height: 8),
              Text('${summary.xpToNextRank} XP to rank ${summary.nextRank}'),
            ],
            const SizedBox(height: 8),
            Text(
              'Leaderboard: #${summary.leaderboardPosition} of ${summary.leaderboardSize}',
            ),
            const SizedBox(height: 8),
            Text(
              'Badges: ${summary.unlockedBadgeCount}/${summary.totalBadgeCount}',
            ),
          ],
        ),
      ),
    );
  }
}

final class _QuestSection extends StatelessWidget {
  const _QuestSection({required this.title, required this.quests});

  final String title;
  final List<QuestProgressModel> quests;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...quests.map(
          (quest) => Card(
            child: ListTile(
              leading: Icon(
                quest.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              ),
              title: Text(quest.title),
              subtitle: Text(
                '${quest.description}\n${quest.current}/${quest.target}',
              ),
              isThreeLine: true,
              trailing: Text('+${quest.rewardXp} XP'),
            ),
          ),
        ),
      ],
    );
  }
}

final class _BadgeSection extends StatelessWidget {
  const _BadgeSection({required this.summary});

  final GamificationSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Badge collection', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...summary.badges.map(
          (badge) => Card(
            child: ListTile(
              leading: Icon(
                badge.unlocked ? Icons.emoji_events : Icons.lock_outline,
              ),
              title: Text(badge.title),
              subtitle: Text(badge.description),
              trailing: Text(badge.category),
            ),
          ),
        ),
      ],
    );
  }
}

final class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({required this.result});

  final AsyncValue<LeaderboardModel> result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'All-time leaderboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        result.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(_friendlyError(error)),
          data: (leaderboard) => Column(
            children: leaderboard.items
                .map(
                  (entry) => Card(
                    child: ListTile(
                      title: Text(
                        entry.isCurrentUser
                            ? '${entry.displayName} (you)'
                            : entry.displayName,
                      ),
                      subtitle: Text(
                        'Rank ${entry.rank} • ${entry.totalXp} XP',
                      ),
                      leading: Text('#${entry.position}'),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

final class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
}

String _friendlyError(Object error) {
  if (error is ApiError) return error.message;
  if (error is FormatException) return 'Kalonet returned an invalid response.';
  return 'Kalonet could not load this information.';
}
