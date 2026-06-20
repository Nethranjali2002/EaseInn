import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

/// ==========================================
/// API INTERCEPTOR - Automatic Token Management
/// ==========================================
/// This Dio interceptor automatically handles two critical tasks:
///
/// 1. REQUEST INTERCEPTOR (onRequest):
///    Before every API request, it checks if we have a stored access token
///    and attaches it to the Authorization header. This means we don't need
///    to manually add the token to every single API call throughout the app.
///
/// 2. ERROR INTERCEPTOR (onError):
///    When a request fails with a 401 (Unauthorized/Token Expired), it
///    automatically tries to refresh the access token using the stored
///    refresh token. If successful, it retries the original request with
///    the new token. This gives users a seamless experience - they don't
///    get logged out just because their token expired.
/// ==========================================
class ApiInterceptor extends Interceptor {
  /// Secure storage for persisting tokens on the device
  final SecureStorage _storage;

  /// A separate Dio instance for making the refresh token request
  /// (We use a separate instance to avoid infinite interceptor loops)
  final Dio _dio;

  ApiInterceptor({required SecureStorage storage, required Dio dio})
      : _storage = storage,
        _dio = dio;

  /// ==========================================
  /// REQUEST INTERCEPTOR - Attach Auth Token
  /// ==========================================
  /// Runs before every API request. Skips attaching tokens for authentication
  /// endpoints (login, register, refresh) since those don't require a token.
  /// ==========================================
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Don't add tokens to authentication endpoints - they don't need them
    if (options.path != '/auth/login' &&
        options.path != '/auth/register' &&
        options.path != '/auth/refresh') {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  /// ==========================================
  /// ERROR INTERCEPTOR - Auto-Refresh Tokens
  /// ==========================================
  /// When a request fails with 401 (Unauthorized), this attempts to refresh
  /// the access token using the stored refresh token. If successful, it
  /// retries the original request with the new token transparently.
  ///
  /// Flow:
  /// 1. Request fails with 401
  /// 2. Grab the refresh token from secure storage
  /// 3. POST to /auth/refresh to get a new access token
  /// 4. Save the new tokens to storage
  /// 5. Update the failed request's header with the new token
  /// 6. Retry the original request
  /// 7. If refresh also fails, clear tokens (user must re-login)
  /// ==========================================
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only attempt refresh on 401 errors, and not for the refresh endpoint itself
    if (err.response?.statusCode == 401 && err.requestOptions.path != '/auth/refresh') {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken != null) {
          // Request a new access token using the refresh token
          final response = await _dio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          final newAccessToken = response.data['data']['accessToken'] as String;
          final newRefreshToken = response.data['data']['refreshToken'] as String;

          // Persist the new tokens for future requests
          await _storage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          // Update the failed request's header with the fresh token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          // Retry the original request that failed
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (_) {
        // Refresh failed - clear all tokens so user gets redirected to login
        await _storage.clearTokens();
      }
    }
    // Pass the error along if we couldn't handle it
    handler.next(err);
  }
}
