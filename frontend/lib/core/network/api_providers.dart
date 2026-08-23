import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../config/app_config.dart';
import '../../features/auth/authentication_api.dart';
import '../../features/auth/session_refresh_coordinator.dart';
import 'api_client.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final sessionController = ref.read(sessionControllerProvider.notifier);
  return ApiClient(
    config: ref.watch(appConfigProvider),
    readAccessToken: () => sessionController.accessToken,
    refreshAccessToken: () =>
        ref.read(sessionRefreshCoordinatorProvider).refreshAccessToken(),
  );
});

// The refresh endpoint must use a client that cannot recursively refresh itself.
final _refreshAuthenticationApiProvider = Provider<AuthenticationApi>((ref) {
  return AuthenticationApi(
    client: ApiClient(config: ref.watch(appConfigProvider)),
  );
});

final sessionRefreshCoordinatorProvider = Provider<SessionRefreshCoordinator>((
  ref,
) {
  return SessionRefreshCoordinator(
    authentication: ref.watch(_refreshAuthenticationApiProvider),
    sessionController: ref.read(sessionControllerProvider.notifier),
  );
});
