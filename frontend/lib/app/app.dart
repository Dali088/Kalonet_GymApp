import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/kalonet_theme.dart';
import '../features/auth/authentication_providers.dart';
import 'router.dart';

typedef RestoreSession = Future<bool> Function();

enum _StartupStatus { loading, ready, error }

class KalonetApp extends ConsumerStatefulWidget {
  const KalonetApp({super.key, this.restoreSession});

  /// Allows startup behavior to be deterministic in widget tests.
  final RestoreSession? restoreSession;

  @override
  ConsumerState<KalonetApp> createState() => _KalonetAppState();
}

class _KalonetAppState extends ConsumerState<KalonetApp> {
  _StartupStatus _status = _StartupStatus.loading;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (_status != _StartupStatus.loading) {
      setState(() => _status = _StartupStatus.loading);
    }

    try {
      final restore =
          widget.restoreSession ??
          () => ref.read(sessionRestoreServiceProvider).restore();
      await restore();
      if (!mounted) return;
      setState(() => _status = _StartupStatus.ready);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _StartupStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _StartupStatus.loading) {
      return MaterialApp(
        title: 'Kalonet',
        debugShowCheckedModeBanner: false,
        theme: KalonetTheme.dark(),
        home: const _StartupLoadingScreen(),
      );
    }

    if (_status == _StartupStatus.error) {
      return MaterialApp(
        title: 'Kalonet',
        debugShowCheckedModeBanner: false,
        theme: KalonetTheme.dark(),
        home: _StartupErrorScreen(onRetry: _restoreSession),
      );
    }

    return MaterialApp.router(
      title: 'Kalonet',
      debugShowCheckedModeBanner: false,
      theme: KalonetTheme.dark(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class KalonetAppRoot extends StatelessWidget {
  const KalonetAppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: KalonetApp());
  }
}

final class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Restoring your session...'),
          ],
        ),
      ),
    );
  }
}

final class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We could not restore your session.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Check your connection and try again. Your account has not been changed.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
