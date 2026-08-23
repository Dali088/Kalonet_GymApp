import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_providers.dart';
import '../../core/network/api_providers.dart';
import 'authentication_api.dart';
import 'session_restore_service.dart';
import 'session_service.dart';

final authenticationApiProvider = Provider<AuthenticationApi>((ref) {
  return AuthenticationApi(client: ref.watch(apiClientProvider));
});

final sessionRestoreServiceProvider = Provider<SessionRestoreService>((ref) {
  return SessionRestoreService(
    authentication: ref.watch(authenticationApiProvider),
    sessionController: ref.read(sessionControllerProvider.notifier),
  );
});

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(
    authentication: ref.watch(authenticationApiProvider),
    sessionController: ref.read(sessionControllerProvider.notifier),
  );
});
