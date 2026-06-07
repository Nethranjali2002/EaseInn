const String _backendBaseUrl = 'http://localhost:3000';

/// Resolves an image path to a full URL.
/// If the path is already a full URL, it is returned as-is.
/// If the path is relative (e.g. /uploads/images/file.jpg), the backend base URL is prepended.
String resolveImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '$_backendBaseUrl$path';
}
