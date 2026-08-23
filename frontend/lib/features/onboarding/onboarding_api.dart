import '../../core/network/api_client.dart';
import 'onboarding_models.dart';

abstract interface class OnboardingGateway {
  Future<OnboardingState> getState();

  Future<OnboardingState> saveDraft(OnboardingDraftPatch patch);

  Future<NutritionPreview> preview();

  Future<OnboardingCompletion> complete(OnboardingCompletionRequest request);
}

final class OnboardingApi implements OnboardingGateway {
  OnboardingApi({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<OnboardingState> getState() async {
    // FRONTEND-BACKEND: Maps to GET /api/v1/users/me/onboarding.
    final response = await _client.get<Object?>(
      'users/me/onboarding',
      retryOnUnauthorized: true,
    );
    return OnboardingState.fromJson(_mapBody(response.data));
  }

  @override
  Future<OnboardingState> saveDraft(OnboardingDraftPatch patch) async {
    // FRONTEND-BACKEND: Maps to PATCH /api/v1/users/me/onboarding.
    final response = await _client.patch<Object?>(
      'users/me/onboarding',
      data: patch.toJson(),
      retryOnUnauthorized: true,
    );
    return OnboardingState.fromJson(_mapBody(response.data));
  }

  @override
  Future<NutritionPreview> preview() async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/users/me/nutrition-target-previews.
    final response = await _client.post<Object?>(
      'users/me/nutrition-target-previews',
      retryOnUnauthorized: true,
    );
    return NutritionPreview.fromJson(_mapBody(response.data));
  }

  @override
  Future<OnboardingCompletion> complete(
    OnboardingCompletionRequest request,
  ) async {
    // FRONTEND-BACKEND: Maps to POST /api/v1/users/me/onboarding-completions.
    final response = await _client.post<Object?>(
      'users/me/onboarding-completions',
      data: request.toJson(),
      retryOnUnauthorized: true,
    );
    return OnboardingCompletion.fromJson(_mapBody(response.data));
  }
}

Map<String, dynamic> _mapBody(Object? body) {
  if (body is! Map) {
    throw const FormatException('Invalid onboarding response.');
  }
  return Map<String, dynamic>.from(body);
}
