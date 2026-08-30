import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalonet_frontend/core/auth/refresh_token_store.dart';
import 'package:kalonet_frontend/core/auth/session_providers.dart';
import 'package:kalonet_frontend/core/auth/session_tokens.dart';
import 'package:kalonet_frontend/features/onboarding/onboarding_models.dart';
import 'package:kalonet_frontend/features/profile/profile_models.dart';
import 'package:kalonet_frontend/features/profile/profile_providers.dart';

void main() {
  test(
    'profile and avatar state is isolated across account transitions',
    () async {
      final container = ProviderContainer(
        overrides: [
          refreshTokenStoreProvider.overrideWithValue(_Store()),
          profileProvider.overrideWith(
            (ref, userId) async => _profiles[userId]!,
          ),
          profileAvatarProvider.overrideWith((ref, userId) async {
            final profile = await ref.watch(profileProvider(userId).future);
            return profile.avatarPresent ? Uint8List.fromList([1, 2, 3]) : null;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionControllerProvider.notifier);

      await controller.establish(_tokens('a', 'a@example.com'));
      expect(
        (await container.read(profileProvider('a').future)).nickname,
        'pakpak',
      );
      expect(
        (await container.read(profileAvatarProvider('a').future)),
        isNotNull,
      );

      await controller.clear();
      expect(container.read(currentProfileProvider).isLoading, isTrue);
      expect(container.read(currentProfileAvatarProvider).isLoading, isTrue);

      await controller.establish(_tokens('b', 'b@example.com'));
      expect(container.read(currentProfileProvider).isLoading, isTrue);
      expect(container.read(currentProfileAvatarProvider).isLoading, isTrue);

      final bProfile = await container.read(profileProvider('b').future);
      final bAvatar = await container.read(profileAvatarProvider('b').future);
      expect(bProfile.email, 'b@example.com');
      expect(bProfile.nickname, isNull);
      expect(bAvatar, isNull);
      expect(
        container.read(currentProfileProvider).value?.email,
        'b@example.com',
      );
      expect(container.read(currentProfileAvatarProvider).value, isNull);

      await controller.clear();
      await controller.establish(_tokens('a', 'a@example.com'));
      final aAgain = await container.read(profileProvider('a').future);
      final aAvatarAgain = await container.read(
        profileAvatarProvider('a').future,
      );
      expect(aAgain.nickname, 'pakpak');
      expect(aAvatarAgain, isNotNull);
    },
  );
}

final _profiles = <String, ProfileModel>{
  'a': _profile(
    email: 'a@example.com',
    nickname: 'pakpak',
    avatarPresent: true,
  ),
  'b': _profile(email: 'b@example.com', nickname: null, avatarPresent: false),
};

ProfileModel _profile({
  required String email,
  required String? nickname,
  required bool avatarPresent,
}) {
  final date = DateTime(2026, 8, 30);
  return ProfileModel(
    email: email,
    nickname: nickname,
    avatarPresent: avatarPresent,
    onboardingCompletedAt: date,
    inputs: ProfileCalculationInputsModel(
      goal: 'maintain_weight',
      dateOfBirth: DateTime(1995, 1, 1),
      formulaSex: 'female',
      heightCm: 170,
      weightKg: 70,
      activityLevel: 'moderately_active',
    ),
    target: ProfileTargetModel(
      id: 'target-$email',
      dailyCalories: 2000,
      proteinG: 140,
      carbohydrateG: 220,
      fatG: 65,
      effectiveFrom: date,
      ruleVersion: 'v1',
      isActive: true,
    ),
    preferences: const [],
    schedule: const [
      MealScheduleInput(preferredTime: '08:00', displayOrder: 1),
    ],
  );
}

SessionTokens _tokens(String id, String email) => SessionTokens(
  accessToken: 'access-$id',
  refreshToken: 'refresh-$id',
  accessTokenExpiresInSeconds: 900,
  refreshTokenExpiresAt: DateTime.utc(2026, 9, 1, 12),
  user: SessionUser(id: id, email: email, onboardingCompleted: true),
);

final class _Store implements RefreshTokenStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String refreshToken) async => value = refreshToken;
}
