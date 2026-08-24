import '../../core/network/api_client.dart';
import 'gamification_models.dart';

abstract interface class GamificationGateway {
  Future<GamificationSummaryModel> summary(DateTime date);
  Future<LeaderboardModel> leaderboard({int limit = 50, int offset = 0});
}

final class GamificationApi implements GamificationGateway {
  GamificationApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<GamificationSummaryModel> summary(DateTime date) async {
    // FRONTEND-BACKEND: the date selects the local daily quest and ISO-week
    // period; XP and completion are still calculated on the server.
    final response = await _client.get<Object?>(
      'users/me/gamification',
      queryParameters: <String, dynamic>{'date': _dateOnly(date)},
      retryOnUnauthorized: true,
    );
    return GamificationSummaryModel.fromJson(_body(response.data));
  }

  @override
  Future<LeaderboardModel> leaderboard({int limit = 50, int offset = 0}) async {
    final response = await _client.get<Object?>(
      'users/me/gamification/leaderboard',
      queryParameters: <String, dynamic>{'limit': limit, 'offset': offset},
      retryOnUnauthorized: true,
    );
    return LeaderboardModel.fromJson(_body(response.data));
  }
}

Map<String, dynamic> _body(Object? body) {
  if (body is! Map) {
    throw const FormatException('Invalid gamification response.');
  }
  return Map<String, dynamic>.from(body);
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
