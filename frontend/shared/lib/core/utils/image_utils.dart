/// ==========================================
/// IMAGE UTILS - URL Resolution Helpers
/// ==========================================
/// EaseInn stores images in two ways:
/// 1. Cloud-hosted (ImgBB, Cloudinary) - full URLs like "https://i.ibb.co/abc123.jpg"
/// 2. Local uploads - relative paths like "/uploads/images/room1.jpg"
///
/// This utility resolves relative paths to full URLs by prepending the backend
/// base URL. This allows the app to work seamlessly with both cloud and local
/// image storage without the rest of the code worrying about the difference.
/// ==========================================

/// The backend server's base URL - used to convert relative paths to full URLs
const String _backendBaseUrl = 'http://localhost:3000';

/// ==========================================
/// resolveImageUrl - Convert Paths to Full URLs
/// ==========================================
/// Takes an image path and returns a complete, fetchable URL.
///
/// Logic:
/// - If path is null or empty -> returns empty string (no image)
/// - If path starts with http:// or https:// -> it's already a full URL, return as-is
/// - If path is relative (e.g., /uploads/img.jpg) -> prepend the backend base URL
///
/// Example:
///   resolveImageUrl("https://i.ibb.co/abc/photo.jpg") -> "https://i.ibb.co/abc/photo.jpg"
///   resolveImageUrl("/uploads/images/room1.jpg") -> "http://localhost:3000/uploads/images/room1.jpg"
///   resolveImageUrl(null) -> ""
/// ==========================================
String resolveImageUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '$_backendBaseUrl$path';
}

/// ==========================================
/// isCloudImageUrl - Check if Image is Cloud-Hosted
/// ==========================================
/// Determines if a URL points to a cloud-hosted image service.
/// Useful for deciding whether to use caching, special headers,
/// or different loading strategies for cloud vs local images.
///
/// Checks for known image hosting services:
/// - ImgBB (https://i.ibb.co/...)
/// - Imgur (https://i.imgur.com/...)
/// - Cloudinary (https://res.cloudinary.com/...)
/// ==========================================
bool isCloudImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.startsWith('https://i.ibb.co/') ||
      url.startsWith('https://i.imgur.com/') ||
      url.startsWith('https://res.cloudinary.com/');
}
