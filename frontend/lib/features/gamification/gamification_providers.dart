import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import '../tracking/tracking_providers.dart';
import 'gamification_api.dart';
import 'gamification_models.dart';

final gamificationApiProvider = Provider<GamificationGateway>((ref) {
  return GamificationApi(client: ref.watch(apiClientProvider));
});

final gamificationProvider =
    FutureProvider.family<GamificationSummaryModel, DateTime>((ref, date) {
      return ref.watch(gamificationApiProvider).summary(date);
    });

final leaderboardProvider = FutureProvider<LeaderboardModel>((ref) {
  // FRONTEND-BACKEND: the leaderboard is a bounded protected read and never
  // trusts client-supplied XP or email labels.
  ref.watch(selectedDateProvider);
  return ref.watch(gamificationApiProvider).leaderboard();
});

final achievementsRefreshControllerProvider =
    Provider<AchievementsRefreshController>(AchievementsRefreshController.new);

final class AchievementsRefreshController {
  AchievementsRefreshController(this._ref);

  final Ref _ref;
  Future<void>? _inFlight;

  Future<void> refresh(DateTime date) {
    return _inFlight ??= _refresh(date).whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh(DateTime date) async {
    _ref.invalidate(gamificationProvider(date));
    _ref.invalidate(leaderboardProvider);
    await Future.wait<Object?>([
      _ref.read(gamificationProvider(date).future),
      _ref.read(leaderboardProvider.future),
    ]);
  }
}
