import 'package:dio/dio.dart';
import 'api_exception.dart';

class ApiClient {
  final Dio dio;
  final String baseUrl;

  ApiClient({Dio? dioClient, this.baseUrl = 'http://localhost:3000/api/v1'})
    : dio = dioClient ?? Dio() {
    dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 500;
      final body = e.response!.data is Map<String, dynamic>
          ? e.response!.data as Map<String, dynamic>
          : {'message': e.message ?? 'Request failed'};
      return ApiException.fromResponse(statusCode, body);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException(statusCode: 408, message: 'Connection timeout');
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException(statusCode: 503, message: 'No internet connection');
    }
    return ApiException(
      statusCode: 500,
      message: e.message ?? 'Unexpected error',
    );
  }
}
