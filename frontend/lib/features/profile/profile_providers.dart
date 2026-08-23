import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import 'profile_api.dart';
import 'profile_models.dart';

final profileApiProvider = Provider<ProfileGateway>((ref) {
  return ProfileApi(client: ref.watch(apiClientProvider));
});

final profileProvider = FutureProvider<ProfileModel>(
  (ref) => ref.watch(profileApiProvider).profile(),
);

final settingsProvider = FutureProvider<SettingsModel>(
  (ref) => ref.watch(profileApiProvider).settings(),
);
