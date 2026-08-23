import '../../core/auth/session_controller.dart';
import 'authentication_api.dart';
import 'authentication_models.dart';

/// Owns user-facing session actions that cross the API and local storage.
final class SessionService {
  SessionService({
    required AuthenticationActions authentication,
    required SessionController sessionController,
  }) : _authentication = authentication,
       _sessionController = sessionController;

  final AuthenticationActions _authentication;
  final SessionController _sessionController;

  Future<void> logout() async {
    final refreshToken = await _sessionController.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _sessionController.clear();
      return;
    }

    try {
      await _authentication.logout(LogoutRequest(refreshToken: refreshToken));
    } finally {
      // Local logout must succeed even when the server cannot be reached.
      await _sessionController.clear();
    }
  }
}
