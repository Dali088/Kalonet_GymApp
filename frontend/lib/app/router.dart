import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_controller.dart';
import '../core/auth/session_providers.dart';
import '../core/theme/kalonet_tokens.dart';
import '../core/widgets/kalonet_brand_mark.dart';
import '../core/widgets/kalonet_surface.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/registration_page.dart';
import '../features/auth/presentation/reset_password_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/gamification/presentation/gamification_page.dart';
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
        pageBuilder: (context, state) =>
            _page(context, state, const KalonetShellPlaceholder()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            _page(context, state, const RegistrationPage()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _page(context, state, const LoginPage()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            _page(context, state, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) => _page(
          context,
          state,
          ResetPasswordPage(resetToken: state.uri.queryParameters['token']),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _page(context, state, const OnboardingPage()),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) =>
            _page(context, state, const DashboardPage()),
      ),
      GoRoute(
        path: '/gamification',
        pageBuilder: (context, state) =>
            _page(context, state, const GamificationPage()),
      ),
    ],
  );
});

Page<void> _page(BuildContext context, GoRouterState state, Widget child) {
  final duration = KalonetMotion.resolve(context, KalonetMotion.standard);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: duration,
    reverseTransitionDuration: KalonetMotion.resolve(
      context,
      KalonetMotion.quick,
    ),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).chain(CurveTween(curve: KalonetMotion.curve)).animate(animation);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}

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
      location == '/onboarding' ||
      location == '/dashboard' ||
      location == '/gamification';

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
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: KalonetGradients.page),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(KalonetSpacing.page),
                child: SizedBox(
                  width: constraints.maxWidth - (KalonetSpacing.page * 2),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: wide
                        ? const _WelcomeWideLayout()
                        : const _WelcomeCompactLayout(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _WelcomeWideLayout extends StatelessWidget {
  const _WelcomeWideLayout();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 620,
      child: Row(
        children: [
          const Expanded(child: _WelcomeStory()),
          const SizedBox(width: KalonetSpacing.section),
          Expanded(child: _WelcomeActions()),
        ],
      ),
    );
  }
}

final class _WelcomeCompactLayout extends StatelessWidget {
  const _WelcomeCompactLayout();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: KalonetSpacing.xl),
        const _WelcomeStory(compact: true),
        const SizedBox(height: KalonetSpacing.xl),
        _WelcomeActions(),
      ],
    );
  }
}

final class _WelcomeStory extends StatelessWidget {
  const _WelcomeStory({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        const KalonetBrandMark(size: 88),
        const SizedBox(height: KalonetSpacing.sm),
        Text('Kalonet', style: textTheme.titleLarge),
        const SizedBox(height: KalonetSpacing.lg),
        Text(
          'Train with intention.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: textTheme.displaySmall,
        ),
        const SizedBox(height: KalonetSpacing.sm),
        Text(
          'A calmer way to build the habits that make you feel stronger.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

final class _WelcomeActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      padding: const EdgeInsets.all(KalonetSpacing.xl),
      gradient: KalonetGradients.surface,
      semanticLabel: 'Kalonet account access',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your day, in focus',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: KalonetSpacing.xs),
          const Text('Track the small wins. Keep your momentum visible.'),
          const SizedBox(height: KalonetSpacing.xl),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            child: const Text('Create account'),
          ),
          const SizedBox(height: KalonetSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
  }
}
