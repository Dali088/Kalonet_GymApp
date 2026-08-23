import '../../core/auth/session_controller.dart';
import '../../core/errors/api_error.dart';
import 'authentication_api.dart';
import 'authentication_models.dart';

/// Coordinates one refresh request for all protected requests in this app.
final class SessionRefreshCoordinator {
  SessionRefreshCoordinator({
    required AuthenticationGateway authentication,
    required SessionController sessionController,
  }) : _authentication = authentication,
       _sessionController = sessionController;

  final AuthenticationGateway _authentication;
  final SessionController _sessionController;
  Future<String?>? _inFlightRefresh;

  Future<String?> refreshAccessToken() {
    final activeRefresh = _inFlightRefresh;
    if (activeRefresh != null) {
      return activeRefresh;
    }

    final refresh = _trackRefresh();
    _inFlightRefresh = refresh;
    return refresh;
  }

  Future<String?> _trackRefresh() async {
    try {
      return await _performRefresh();
    } finally {
      _inFlightRefresh = null;
    }
  }

  Future<String?> _performRefresh() async {
    final storedRefreshToken = await _sessionController.readRefreshToken();
    if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
      return null;
    }

    try {
      final tokens = await _authentication.refresh(
        RefreshTokenRequest(refreshToken: storedRefreshToken),
      );
      await _sessionController.establish(tokens);
      return tokens.accessToken;
    } on ApiError catch (error) {
      if (error.code == 'invalid_refresh_token' ||
          error.code == 'refresh_token_reuse_detected') {
        await _sessionController.clear();
        return null;
      }
      rethrow;
    }
  }
}
