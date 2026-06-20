import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ==========================================
/// SECURE STORAGE - Encrypted Token Persistence
/// ==========================================
/// This class wraps FlutterSecureStorage to provide a safe, encrypted way
/// to store sensitive authentication tokens (access + refresh) on the device.
///
/// Why not SharedPreferences?
/// SharedPreferences stores data in plain text. JWT tokens are essentially
/// passwords - if someone extracts them from the device, they can impersonate
/// the user. FlutterSecureStorage uses iOS Keychain / Android Keystore to
/// encrypt tokens at the OS level, making them unreadable even on rooted/jailbroken devices.
/// ==========================================
class SecureStorage {
  /// The underlying secure storage instance from the flutter_secure_storage package
  final FlutterSecureStorage _storage;

  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Storage keys - used as unique identifiers for each stored value.
  /// These are constants so they can't be accidentally changed elsewhere in the app.
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  /// ==========================================
  /// SAVE TOKENS - Store Both Tokens Simultaneously
  /// ==========================================
  /// Saves both access and refresh tokens to secure storage.
  /// Uses Future.wait to write both tokens in parallel for faster performance.
  /// ==========================================
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  /// Retrieves the stored access token. Returns null if no token exists.
  /// Used by ApiClient to attach the token to API requests.
  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  /// Retrieves the stored refresh token. Returns null if no token exists.
  /// Used by ApiInterceptor when the access token expires.
  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  /// ==========================================
  /// CLEAR TOKENS - Remove All Stored Auth Data
  /// ==========================================
  /// Deletes both tokens from secure storage. Called during logout or when
  /// the refresh token has expired and the user needs to re-authenticate.
  /// Uses Future.wait to delete both in parallel.
  /// ==========================================
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
