const String _backendBaseUrl = 'http://localhost:3000';

/// Resolves an image path to a full URL.
/// - If the path is already a full URL (http/https), returns it as-is (ImgBB, etc.)
/// - If the path is a relative local path (e.g. /uploads/images/file.jpg), prepends the backend base URL
/// - Returns empty string for null/empty paths
String resolveImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '$_backendBaseUrl$path';
}

/// Check if a URL is a cloud-hosted image (ImgBB, etc.)
bool isCloudImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.startsWith('https://i.ibb.co/') ||
      url.startsWith('https://i.imgur.com/') ||
      url.startsWith('https://res.cloudinary.com/');
}
