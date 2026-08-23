import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import 'tracking_api.dart';
import 'tracking_models.dart';

final trackingApiProvider = Provider<TrackingGateway>((ref) {
  return TrackingApi(client: ref.watch(apiClientProvider));
});

final selectedDateProvider = NotifierProvider<SelectedDateController, DateTime>(
  SelectedDateController.new,
);

final dashboardProvider = FutureProvider.family<DailyDashboardModel, DateTime>(
  (ref, date) => ref.watch(trackingApiProvider).dashboard(date),
);

final mealsProvider = FutureProvider.family<MealsResponseModel, DateTime>(
  (ref, date) => ref.watch(trackingApiProvider).meals(date),
);

final waterProvider = FutureProvider.family<WaterListModel, DateTime>(
  (ref, date) => ref.watch(trackingApiProvider).water(date),
);

final stepsProvider = FutureProvider.family<DailyStepsModel, DateTime>(
  (ref, date) => ref.watch(trackingApiProvider).steps(date),
);

final activitiesProvider = FutureProvider.family<ActivityListModel, DateTime>(
  (ref, date) => ref.watch(trackingApiProvider).activities(date),
);

final class SelectedDateController extends Notifier<DateTime> {
  @override
  DateTime build() => _dateOnly(DateTime.now());

  void set(DateTime value) => state = _dateOnly(value);

  void previous() => set(state.subtract(const Duration(days: 1)));

  void next() => set(state.add(const Duration(days: 1)));

  void today() => set(DateTime.now());
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
