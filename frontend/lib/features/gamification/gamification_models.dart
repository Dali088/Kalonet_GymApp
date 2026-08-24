class QuestProgressModel {
  const QuestProgressModel({
    required this.code,
    required this.title,
    required this.description,
    required this.period,
    required this.periodKey,
    required this.current,
    required this.target,
    required this.rewardXp,
    required this.completed,
    required this.awarded,
  });

  final String code;
  final String title;
  final String description;
  final String period;
  final String periodKey;
  final int current;
  final int target;
  final int rewardXp;
  final bool completed;
  final bool awarded;

  factory QuestProgressModel.fromJson(Map<String, dynamic> json) {
    return QuestProgressModel(
      code: _string(json, 'code'),
      title: _string(json, 'title'),
      description: _string(json, 'description'),
      period: _string(json, 'period'),
      periodKey: _string(json, 'period_key'),
      current: _integer(json, 'current'),
      target: _integer(json, 'target'),
      rewardXp: _integer(json, 'reward_xp'),
      completed: json['completed'] == true,
      awarded: json['awarded'] == true,
    );
  }
}

class BadgeProgressModel {
  const BadgeProgressModel({
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.unlocked,
    required this.unlockedAt,
  });

  final String code;
  final String title;
  final String description;
  final String category;
  final bool unlocked;
  final DateTime? unlockedAt;

  factory BadgeProgressModel.fromJson(Map<String, dynamic> json) {
    return BadgeProgressModel(
      code: _string(json, 'code'),
      title: _string(json, 'title'),
      description: _string(json, 'description'),
      category: _string(json, 'category'),
      unlocked: json['unlocked'] == true,
      unlockedAt: _optionalDateTime(json['unlocked_at']),
    );
  }
}

class GamificationSummaryModel {
  const GamificationSummaryModel({
    required this.totalXp,
    required this.rank,
    required this.nextRank,
    required this.xpToNextRank,
    required this.dailyQuests,
    required this.weeklyQuests,
    required this.badges,
    required this.unlockedBadgeCount,
    required this.totalBadgeCount,
    required this.leaderboardPosition,
    required this.leaderboardSize,
  });

  final int totalXp;
  final String rank;
  final String? nextRank;
  final int xpToNextRank;
  final List<QuestProgressModel> dailyQuests;
  final List<QuestProgressModel> weeklyQuests;
  final List<BadgeProgressModel> badges;
  final int unlockedBadgeCount;
  final int totalBadgeCount;
  final int leaderboardPosition;
  final int leaderboardSize;

  factory GamificationSummaryModel.fromJson(Map<String, dynamic> json) {
    return GamificationSummaryModel(
      totalXp: _integer(json, 'total_xp'),
      rank: _string(json, 'rank'),
      nextRank: json['next_rank'] as String?,
      xpToNextRank: _integer(json, 'xp_to_next_rank'),
      dailyQuests: _list(
        json,
        'daily_quests',
      ).map(QuestProgressModel.fromJson).toList(),
      weeklyQuests: _list(
        json,
        'weekly_quests',
      ).map(QuestProgressModel.fromJson).toList(),
      badges: _list(json, 'badges').map(BadgeProgressModel.fromJson).toList(),
      unlockedBadgeCount: _integer(json, 'unlocked_badge_count'),
      totalBadgeCount: _integer(json, 'total_badge_count'),
      leaderboardPosition: _integer(json, 'leaderboard_position'),
      leaderboardSize: _integer(json, 'leaderboard_size'),
    );
  }
}

class LeaderboardEntryModel {
  const LeaderboardEntryModel({
    required this.position,
    required this.displayName,
    required this.totalXp,
    required this.rank,
    required this.isCurrentUser,
  });

  final int position;
  final String displayName;
  final int totalXp;
  final String rank;
  final bool isCurrentUser;

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      position: _integer(json, 'position'),
      displayName: _string(json, 'display_name'),
      totalXp: _integer(json, 'total_xp'),
      rank: _string(json, 'rank'),
      isCurrentUser: json['is_current_user'] == true,
    );
  }
}

class LeaderboardModel {
  const LeaderboardModel({
    required this.items,
    required this.limit,
    required this.offset,
    required this.returned,
    required this.total,
  });

  final List<LeaderboardEntryModel> items;
  final int limit;
  final int offset;
  final int returned;
  final int total;

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      items: _list(json, 'items').map(LeaderboardEntryModel.fromJson).toList(),
      limit: _integer(json, 'limit'),
      offset: _integer(json, 'offset'),
      returned: _integer(json, 'returned'),
      total: _integer(json, 'total'),
    );
  }
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('Invalid $key.');
  return value;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.toInt()) return value.toInt();
  throw FormatException('Invalid $key.');
}

DateTime? _optionalDateTime(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  return parsed?.toLocal();
}

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Invalid $key.');
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
