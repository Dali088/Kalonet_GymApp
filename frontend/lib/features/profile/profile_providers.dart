import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_providers.dart';
import '../../core/errors/api_error.dart';
import '../../core/network/api_providers.dart';
import 'profile_api.dart';
import 'profile_models.dart';

final profileApiProvider = Provider<ProfileGateway>((ref) {
  return ProfileApi(client: ref.watch(apiClientProvider));
});

final profileProvider = FutureProvider.autoDispose.family<ProfileModel, String>(
  (ref, userId) {
    // The user ID is intentionally part of the provider key. A new login
    // must create a new async state instead of reusing the previous account.
    return ref.watch(profileApiProvider).profile();
  },
);

final currentProfileProvider = Provider<AsyncValue<ProfileModel>>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return const AsyncLoading<ProfileModel>();
  return ref.watch(profileProvider(userId));
});

final profileAvatarProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, userId) async {
      // FRONTEND-BACKEND: profile JSON is the authoritative existence check, so
      // an absent avatar does not create an expected 404 request in the UI.
      final profile = await ref.watch(profileProvider(userId).future);
      if (!profile.avatarPresent) return null;
      try {
        return await ref.watch(profileApiProvider).avatarBytes();
      } on ApiError catch (error) {
        if (error.statusCode == 404 || error.code == 'avatar_not_found') {
          return null;
        }
        rethrow;
      }
    });

final currentProfileAvatarProvider = Provider<AsyncValue<Uint8List?>>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return const AsyncLoading<Uint8List?>();
  return ref.watch(profileAvatarProvider(userId));
});

final settingsProvider = FutureProvider.autoDispose
    .family<SettingsModel, String>((ref, userId) {
      return ref.watch(profileApiProvider).settings();
    });

final currentSettingsProvider = Provider<AsyncValue<SettingsModel>>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return const AsyncLoading<SettingsModel>();
  return ref.watch(settingsProvider(userId));
});
