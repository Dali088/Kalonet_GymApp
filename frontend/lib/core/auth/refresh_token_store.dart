import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class RefreshTokenStore {
  Future<String?> read();

  Future<void> write(String refreshToken);

  Future<void> clear();
}

/// Secure device storage for the opaque refresh token.
final class SecureRefreshTokenStore implements RefreshTokenStore {
  SecureRefreshTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  static const _storageKey = 'kalonet.refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() {
    return _storage.read(key: _storageKey);
  }

  @override
  Future<void> write(String refreshToken) {
    if (refreshToken.isEmpty) {
      throw ArgumentError.value(refreshToken, 'refreshToken');
    }
    return _storage.write(key: _storageKey, value: refreshToken);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _storageKey);
  }
}

final refreshTokenStoreProvider = Provider<RefreshTokenStore>((ref) {
  return SecureRefreshTokenStore();
});
