import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_controller.dart';
import '../core/auth/session_providers.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/registration_page.dart';
import '../features/auth/presentation/reset_password_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(sessionControllerProvider, (_, _) {
    refreshNotifier.refresh();
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final deepLinkLocation = normalizeKalonetDeepLink(state.uri);
      if (deepLinkLocation != null) {
        return deepLinkLocation;
      }

      return authRedirect(
        session: ref.read(sessionControllerProvider),
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const KalonetShellPlaceholder(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordPage(resetToken: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
  );
});

String? normalizeKalonetDeepLink(Uri uri) {
  if (uri.scheme != 'kalonet' || uri.host != 'password-reset') {
    return null;
  }

  final token = uri.queryParameters['token'];
  return Uri(
    path: '/reset-password',
    queryParameters: token == null ? null : <String, String>{'token': token},
  ).toString();
}

String? authRedirect({
  required SessionState session,
  required String location,
}) {
  final isAuthenticated = session.isAuthenticated;
  final isPublicLocation =
      location == '/' ||
      location == '/login' ||
      location == '/register' ||
      location == '/forgot-password';
  final isProtectedLocation =
      location == '/onboarding' || location == '/dashboard';

  if (!isAuthenticated && isProtectedLocation) {
    return '/';
  }

  if (isAuthenticated && isPublicLocation) {
    return session.user!.onboardingCompleted ? '/dashboard' : '/onboarding';
  }

  return null;
}

final class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class KalonetShellPlaceholder extends StatelessWidget {
  const KalonetShellPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kalonet', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/register'),
              child: const Text('Create account'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Log in'),
            ),
          ],
        ),
      ),
    );
  }
}
