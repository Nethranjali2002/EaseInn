const String _backendBaseUrl = 'http://localhost:3000';

String resolveImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '$_backendBaseUrl$path';
}
