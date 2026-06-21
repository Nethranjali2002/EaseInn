import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiInterceptor extends Interceptor {
  final SecureStorage _storage;
  final Dio _dio;

  ApiInterceptor({required SecureStorage storage, required Dio dio})
      : _storage = storage,
        _dio = dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
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

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && err.requestOptions.path != '/auth/refresh') {
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken != null) {
          final response = await _dio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          final newAccessToken = response.data['data']['accessToken'] as String;
          final newRefreshToken = response.data['data']['refreshToken'] as String;
          await _storage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          final retryResponse = await _dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (_) {
        await _storage.clearTokens();
      }
    }
    handler.next(err);
  }
}
