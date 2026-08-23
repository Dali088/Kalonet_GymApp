/// User information returned with a successful authentication response.
final class SessionUser {
  const SessionUser({
    required this.id,
    required this.email,
    required this.onboardingCompleted,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: _requiredString(json, 'id'),
      email: _requiredString(json, 'email'),
      onboardingCompleted: _requiredBool(json, 'onboarding_completed'),
    );
  }

  final String id;
  final String email;
  final bool onboardingCompleted;
}

/// The short-lived response from registration, login, or token refresh.
///
/// The refresh token is deliberately transient here. The session controller
/// writes it to secure storage and does not keep it in reactive session state.
final class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresInSeconds,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    final tokenType = json['token_type'];
    if (tokenType != 'bearer') {
      throw const FormatException('Unsupported authentication token type.');
    }

    final accessTokenLifetime = json['access_token_expires_in_seconds'];
    if (accessTokenLifetime is! int || accessTokenLifetime <= 0) {
      throw const FormatException('Invalid access-token lifetime.');
    }

    final refreshTokenExpiry = json['refresh_token_expires_at'];
    if (refreshTokenExpiry is! String) {
      throw const FormatException('Invalid refresh-token expiry.');
    }

    final parsedExpiry = DateTime.tryParse(refreshTokenExpiry);
    if (parsedExpiry == null) {
      throw const FormatException('Invalid refresh-token expiry.');
    }

    final user = json['user'];
    if (user is! Map) {
      throw const FormatException('Invalid authenticated-user response.');
    }

    return SessionTokens(
      accessToken: _requiredString(json, 'access_token'),
      refreshToken: _requiredString(json, 'refresh_token'),
      accessTokenExpiresInSeconds: accessTokenLifetime,
      refreshTokenExpiresAt: parsedExpiry.toUtc(),
      user: SessionUser.fromJson(Map<String, dynamic>.from(user)),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int accessTokenExpiresInSeconds;
  final DateTime refreshTokenExpiresAt;
  final SessionUser user;
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing or invalid $field.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! bool) {
    throw FormatException('Missing or invalid $field.');
  }
  return value;
}
