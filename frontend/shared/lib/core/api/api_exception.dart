class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  factory ApiException.fromResponse(int statusCode, Map<String, dynamic> body) {
    final message = body['message'] ?? body['error'] ?? 'Unknown error occurred';
    return ApiException(statusCode: statusCode, message: message.toString());
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
