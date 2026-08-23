import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import 'onboarding_api.dart';

final onboardingApiProvider = Provider<OnboardingGateway>((ref) {
  return OnboardingApi(client: ref.watch(apiClientProvider));
});
