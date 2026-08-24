import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/config/app_config.dart';
import 'package:kalonet_frontend/core/network/api_client.dart';
import 'package:kalonet_frontend/features/gamification/gamification_api.dart';

void main() {
  test(
    'summary sends the selected date and parses quests and badges',
    () async {
      final adapter = _Adapter(_summaryJson);
      final api = GamificationApi(client: _client(adapter));

      final summary = await api.summary(DateTime(2026, 8, 24));

      expect(adapter.method, 'GET');
      expect(adapter.uri?.path, '/api/v1/users/me/gamification');
      expect(adapter.uri?.queryParameters['date'], '2026-08-24');
      expect(summary.totalXp, 50);
      expect(summary.dailyQuests.single.code, 'daily_meal');
      expect(summary.badges.single.unlocked, isTrue);
    },
  );

  test(
    'leaderboard uses bounded pagination and parses privacy-safe rows',
    () async {
      final adapter = _Adapter(_leaderboardJson);
      final api = GamificationApi(client: _client(adapter));

      final leaderboard = await api.leaderboard(limit: 10, offset: 20);

      expect(adapter.uri?.path, '/api/v1/users/me/gamification/leaderboard');
      expect(adapter.uri?.queryParameters['limit'], '10');
      expect(adapter.uri?.queryParameters['offset'], '20');
      expect(leaderboard.items.single.displayName, 'Kalonet member');
      expect(leaderboard.items.single.rank, 'E');
    },
  );
}

ApiClient _client(_Adapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1/'))
    ..httpClientAdapter = adapter;
  return ApiClient(
    config: const AppConfig(apiBaseUrl: 'http://test/api/v1'),
    dio: dio,
  );
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.response);

  final Map<String, dynamic> response;
  String? method;
  Uri? uri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    uri = options.uri;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _summaryJson = <String, dynamic>{
  'total_xp': 50,
  'rank': 'E',
  'next_rank': 'D',
  'xp_to_next_rank': 450,
  'daily_quests': [
    {
      'code': 'daily_meal',
      'title': 'Daily meal',
      'description': 'Log at least one meal',
      'period': 'daily',
      'period_key': '2026-08-24',
      'current': 1,
      'target': 1,
      'reward_xp': 10,
      'completed': true,
      'awarded': true,
    },
  ],
  'weekly_quests': [],
  'badges': [
    {
      'code': 'FIRST_MEAL',
      'title': 'First meal',
      'description': 'Log your first meal',
      'category': 'starter',
      'unlocked': true,
      'unlocked_at': '2026-08-24T10:00:00Z',
    },
  ],
  'unlocked_badge_count': 1,
  'total_badge_count': 13,
  'leaderboard_position': 1,
  'leaderboard_size': 2,
};

final _leaderboardJson = <String, dynamic>{
  'items': [
    {
      'position': 3,
      'display_name': 'Kalonet member',
      'total_xp': 0,
      'rank': 'E',
      'is_current_user': true,
    },
  ],
  'limit': 10,
  'offset': 20,
  'returned': 1,
  'total': 21,
};
