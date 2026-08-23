import '../../core/auth/session_controller.dart';
import '../../core/errors/api_error.dart';
import 'authentication_api.dart';
import 'authentication_models.dart';

/// Coordinates one startup refresh attempt without creating retry loops.
final class SessionRestoreService {
  SessionRestoreService({
    required AuthenticationGateway authentication,
    required SessionController sessionController,
  }) : _authentication = authentication,
       _sessionController = sessionController;

  final AuthenticationGateway _authentication;
  final SessionController _sessionController;

  Future<bool> restore() async {
    final storedRefreshToken = await _sessionController.readRefreshToken();
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      return false;
    }

    try {
      final tokens = await _authentication.refresh(
        RefreshTokenRequest(refreshToken: storedRefreshToken),
      );
      await _sessionController.establish(tokens);
      return true;
    } on ApiError catch (error) {
      if (error.code == 'invalid_refresh_token' ||
          error.code == 'refresh_token_reuse_detected') {
        await _sessionController.clear();
        return false;
      }
      rethrow;
    }
  }
}
