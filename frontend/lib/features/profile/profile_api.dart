import 'dart:typed_data';

import '../../core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../onboarding/onboarding_models.dart';
import 'profile_models.dart';

abstract interface class ProfileGateway {
  Future<ProfileModel> profile();
  Future<ProfileModel> updateNickname(String? nickname);
  Future<Uint8List> avatarBytes();
  Future<void> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  });
  Future<void> removeAvatar();
  Future<ProfileModel> recalculate(ProfileCalculationInputsModel inputs);
  Future<List<String>> replacePreferences(List<String> preferences);
  Future<List<MealScheduleInput>> replaceSchedule(
    List<MealScheduleInput> schedule,
  );
  Future<SettingsModel> settings();
  Future<SettingsModel> updateSettings(Map<String, dynamic> patch);
  Future<void> changePassword(String currentPassword, String newPassword);
}

final class ProfileApi implements ProfileGateway {
  ProfileApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<ProfileModel> profile() async {
    final response = await _client.get<Object?>(
      'users/me/profile',
      retryOnUnauthorized: true,
    );
    return ProfileModel.fromJson(_body(response.data));
  }

  @override
  Future<ProfileModel> updateNickname(String? nickname) async {
    // FRONTEND-BACKEND: the optional nickname is a display label only; email
    // remains the authentication identity and is never sent as a nickname.
    final response = await _client.patch<Object?>(
      'users/me/profile',
      data: <String, dynamic>{'nickname': nickname},
      retryOnUnauthorized: true,
    );
    return ProfileModel.fromJson(_body(response.data));
  }

  @override
  Future<Uint8List> avatarBytes() async {
    final response = await _client.get<List<int>>(
      'users/me/profile/avatar',
      options: Options(responseType: ResponseType.bytes),
      retryOnUnauthorized: true,
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Invalid avatar response.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    // FRONTEND-BACKEND: Multipart upload maps to PUT /api/v1/users/me/profile/avatar.
    await _client.put<Object?>(
      'users/me/profile/avatar',
      data: FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: 'profile-avatar',
          contentType: MediaType.parse(contentType),
        ),
      }),
      retryOnUnauthorized: true,
    );
  }

  @override
  Future<void> removeAvatar() async {
    // FRONTEND-BACKEND: DELETE /api/v1/users/me/profile/avatar clears the saved image.
    await _client.delete<Object?>(
      'users/me/profile/avatar',
      retryOnUnauthorized: true,
    );
  }

  @override
  Future<ProfileModel> recalculate(ProfileCalculationInputsModel inputs) async {
    await _client.post<Object?>(
      'users/me/nutrition-target-recalculations',
      data: inputs.toJson(),
      retryOnUnauthorized: true,
    );
    // The recalculation response contains the new target, while the profile
    // endpoint remains the canonical read model for all profile fields.
    return profile();
  }

  @override
  Future<List<String>> replacePreferences(List<String> preferences) async {
    final response = await _client.put<Object?>(
      'users/me/dietary-preferences',
      data: <String, dynamic>{'preferences': preferences},
      retryOnUnauthorized: true,
    );
    final body = _body(response.data);
    final values = body['preferences'];
    if (values is! List) {
      throw const FormatException('Invalid preferences response.');
    }
    return values.whereType<String>().toList();
  }

  @override
  Future<List<MealScheduleInput>> replaceSchedule(
    List<MealScheduleInput> schedule,
  ) async {
    final response = await _client.put<Object?>(
      'users/me/meal-schedule',
      data: <String, dynamic>{
        'items': schedule.map((item) => item.toJson()).toList(),
      },
      retryOnUnauthorized: true,
    );
    final values = _body(response.data)['items'];
    if (values is! List) {
      throw const FormatException('Invalid schedule response.');
    }
    return values
        .whereType<Map>()
        .map(
          (item) => MealScheduleInput.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<SettingsModel> settings() async {
    final response = await _client.get<Object?>(
      'users/me/settings',
      retryOnUnauthorized: true,
    );
    return SettingsModel.fromJson(_body(response.data));
  }

  @override
  Future<SettingsModel> updateSettings(Map<String, dynamic> patch) async {
    final response = await _client.patch<Object?>(
      'users/me/settings',
      data: patch,
      retryOnUnauthorized: true,
    );
    return SettingsModel.fromJson(_body(response.data));
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _client.post<Object?>(
      'auth/password-changes',
      data: <String, dynamic>{
        'current_password': currentPassword,
        'new_password': newPassword,
      },
      retryOnUnauthorized: true,
    );
  }
}

Map<String, dynamic> _body(Object? body) {
  if (body is! Map) throw const FormatException('Invalid profile response.');
  return Map<String, dynamic>.from(body);
}
