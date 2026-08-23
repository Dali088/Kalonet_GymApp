/// Request body for the public registration endpoint.
final class RegistrationRequest {
  const RegistrationRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'email': email, 'password': password};
  }
}

/// Request body for the public login endpoint.
final class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'email': email, 'password': password};
  }
}

/// Request body for refresh-token rotation.
final class RefreshTokenRequest {
  const RefreshTokenRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'refresh_token': refreshToken};
  }
}

/// Request body for revoking the current refresh-token session.
final class LogoutRequest {
  const LogoutRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'refresh_token': refreshToken};
  }
}

/// Request body for starting password recovery.
final class PasswordResetRequest {
  const PasswordResetRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'email': email};
  }
}

/// Request body for consuming a password-reset token.
final class PasswordResetCompletionRequest {
  const PasswordResetCompletionRequest({
    required this.resetToken,
    required this.newPassword,
  });

  final String resetToken;
  final String newPassword;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'reset_token': resetToken,
      'new_password': newPassword,
    };
  }
}
