import 'package:dio/dio.dart';
import 'api_exception.dart';

/// ==========================================
/// API CLIENT - The Central HTTP Messenger
/// ==========================================
/// This class wraps the Dio HTTP library to provide a clean, consistent way
/// for the entire app to communicate with the backend REST API.
/// Instead of creating new Dio instances everywhere, we use this single client
/// that handles base URL configuration, timeouts, headers, and error translation.
/// ==========================================
class ApiClient {
  /// The underlying Dio instance that actually performs HTTP requests
  final Dio dio;

  /// The root URL for all API requests (e.g., "http://localhost:3000/api/v1")
  final String baseUrl;

  /// Creates an ApiClient with optional custom Dio instance and base URL.
  /// If no Dio instance is provided, a new one is created with sensible defaults.
  ApiClient({Dio? dioClient, this.baseUrl = 'http://localhost:3000/api/v1'})
    : dio = dioClient ?? Dio() {
    // Configure default options that apply to every request made through this client
    dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10), // Max time to establish connection
      receiveTimeout: const Duration(seconds: 10), // Max time to wait for response
      headers: {
        'Content-Type': 'application/json', // Tell the server we send JSON
        'Accept': 'application/json', // Tell the server we want JSON back
      },
    );
  }

  /// Attaches a JWT access token to all future requests.
  /// This is called after a successful login to authenticate the user.
  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Removes the JWT token from headers.
  /// Called during logout to prevent sending expired/invalid tokens.
  void clearAuthToken() {
    dio.options.headers.remove('Authorization');
  }

  /// Sends a GET request to the specified path.
  /// Used for fetching data (properties, bookings, rooms, etc.)
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

  /// Sends a POST request to the specified path with JSON body data.
  /// Used for creating new resources (login, register, create booking, etc.)
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Sends a PATCH request to the specified path with JSON body data.
  /// Used for partially updating existing resources (update booking status, etc.)
  Future<Response> patch(String path, {dynamic data}) async {
    try {
      return await dio.patch(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Sends a DELETE request to the specified path.
  /// Used for removing resources (delete property, delete booking, etc.)
  Future<Response> delete(String path) async {
    try {
      return await dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// ==========================================
  /// ERROR TRANSLATOR
  /// ==========================================
  /// Converts low-level DioExceptions into our custom ApiException format.
  /// This gives the rest of the app a consistent error type to handle,
  /// regardless of whether the error was a timeout, connection issue, or HTTP error.
  ApiException _handleError(DioException e) {
    // If we got a response from the server (HTTP error like 400, 401, 500, etc.)
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 500;
      final body = e.response!.data is Map<String, dynamic>
          ? e.response!.data as Map<String, dynamic>
          : {'message': e.message ?? 'Request failed'};
      return ApiException.fromResponse(statusCode, body);
    }
    // No response at all - likely a network issue
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException(statusCode: 408, message: 'Connection timeout');
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException(statusCode: 503, message: 'No internet connection');
    }
    // Catch-all for any other Dio errors
    return ApiException(
      statusCode: 500,
      message: e.message ?? 'Unexpected error occurred',
    );
  }
}
