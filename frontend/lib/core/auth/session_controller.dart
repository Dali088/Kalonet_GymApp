import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'refresh_token_store.dart';
import 'session_tokens.dart';

final class SessionState {
  const SessionState.unauthenticated() : accessToken = null, user = null;

  const SessionState.authenticated({
    required this.accessToken,
    required this.user,
  });

  final String? accessToken;
  final SessionUser? user;

  bool get isAuthenticated => accessToken != null && user != null;
}

/// Reactive memory boundary for the current access token and user.
final class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    return const SessionState.unauthenticated();
  }

  String? get accessToken => state.accessToken;

  Future<void> establish(SessionTokens tokens) async {
    // Store the refresh token before publishing authenticated state. If secure
    // storage fails, the UI does not observe a half-created session.
    await ref.read(refreshTokenStoreProvider).write(tokens.refreshToken);
    state = SessionState.authenticated(
      accessToken: tokens.accessToken,
      user: tokens.user,
    );
  }

  Future<String?> readRefreshToken() {
    return ref.read(refreshTokenStoreProvider).read();
  }

  Future<void> clear() async {
    await ref.read(refreshTokenStoreProvider).clear();
    state = const SessionState.unauthenticated();
  }

  void markOnboardingCompleted() {
    final currentUser = state.user;
    final currentAccessToken = state.accessToken;
    if (currentUser == null || currentAccessToken == null) {
      return;
    }

    state = SessionState.authenticated(
      accessToken: currentAccessToken,
      user: SessionUser(
        id: currentUser.id,
        email: currentUser.email,
        onboardingCompleted: true,
      ),
    );
  }
}
