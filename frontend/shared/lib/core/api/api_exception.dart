/// ==========================================
/// API EXCEPTION - Custom Error Handler
/// ==========================================
/// When the backend returns an HTTP error (like 401 Unauthorized, 404 Not Found,
/// or 500 Server Error), we need a consistent way to represent that error
/// throughout the Flutter app. This class wraps HTTP error responses into a
/// clean, readable format that the UI can display to the user.
/// ==========================================
class ApiException implements Exception {
  /// The HTTP status code from the server (e.g., 401, 404, 500)
  final int statusCode;

  /// A human-readable error message to display to the user
  final String message;

  ApiException({required this.statusCode, required this.message});

  /// ==========================================
  /// FACTORY CONSTRUCTOR - Parses Server Responses
  /// ==========================================
  /// The backend typically returns errors in this JSON format:
  /// { "success": false, "message": "User not found" }
  /// This factory extracts the message from that response body.
  /// It checks multiple possible keys ('message', 'error') for flexibility.
  /// ==========================================
  factory ApiException.fromResponse(int statusCode, Map<String, dynamic> body) {
    // Try 'message' first, then 'error', then fall back to a generic message
    final message = body['message'] ?? body['error'] ?? 'Unknown error occurred';
    return ApiException(statusCode: statusCode, message: message.toString());
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
