import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';

/// ==========================================
/// NOTIFICATION ITEM - In-App Notification Model
/// ==========================================
/// Represents a single notification sent to the user.
/// Notifications are created by the backend for events like:
/// - New booking created
/// - Task assigned
/// - Payment received
/// - System announcements
///
/// Each notification has a read/unread status and a timestamp.
/// ==========================================
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'booking', 'task', 'payment', 'system', etc.
  final bool read;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.read = false,
    required this.createdAt,
  });

  /// JSON parser with fallback defaults for missing fields
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      read: json['read'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// ==========================================
/// NOTIFICATION STATE - Notification Container
/// ==========================================
class NotificationState {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });
}

/// ==========================================
/// NOTIFICATION PROVIDER - Auto-Polling Notifications
/// ==========================================
/// Manages in-app notifications with automatic background polling.
///
/// Key features:
/// - Auto-loads notifications when the provider is first created
/// - Polls the backend every 15 seconds for new notifications
/// - Silently updates in the background (no loading spinner on refresh)
/// - Cleans up the timer when the provider is disposed
/// - Supports marking individual or all notifications as read
/// ==========================================
class NotificationNotifier extends Notifier<NotificationState> {
  Timer? _timer;

  @override
  NotificationState build() {
    // ==========================================
    // INITIAL LOAD
    // ==========================================
    // Uses Future.microtask to schedule the initial load after the current
    // frame builds, preventing setState-during-build errors.
    Future.microtask(() => loadNotifications());

    // ==========================================
    // BACKGROUND POLLING
    // ==========================================
    // Sets up a timer that fetches new notifications every 15 seconds.
    // This keeps the notification badge count up-to-date without
    // requiring the user to manually refresh.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      loadNotifications(silent: true);
    });

    // Clean up the timer when the provider is disposed (user logs out, etc.)
    ref.onDispose(() {
      _timer?.cancel();
    });

    return NotificationState();
  }

  /// ==========================================
  /// LOAD NOTIFICATIONS - Fetch from Backend
  /// ==========================================
  /// Fetches the full notification list and unread count from the backend.
  ///
  /// The [silent] parameter controls whether to show a loading indicator:
  /// - silent=false (default): Shows loading spinner (used on initial load)
  /// - silent=true: Updates silently in background (used by polling timer)
  /// ==========================================
  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      state = NotificationState(
        notifications: state.notifications,
        unreadCount: state.unreadCount,
        isLoading: true,
      );
    }
    try {
      final api = ref.read(apiClientProvider);

      // Fetch the full notification list
      final res = await api.get('/notifications');
      final items = (res.data['data']['notifications'] as List?)
              ?.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [];

      // Fetch just the unread count separately (more efficient than counting client-side)
      final unreadRes = await api.get('/notifications/unread');
      state = NotificationState(
        notifications: items,
        unreadCount: unreadRes.data['data']['count'] ?? 0,
        isLoading: false,
      );
    } catch (_) {
      // On error, preserve existing data if doing a silent refresh
      if (!silent) {
        state = NotificationState(
          notifications: state.notifications,
          unreadCount: state.unreadCount,
          isLoading: false,
        );
      }
    }
  }

  /// ==========================================
  /// MARK AS READ - Mark Single Notification
  /// ==========================================
  /// Tells the backend that a specific notification has been read,
  /// then silently refreshes the notification list to update the unread count.
  /// ==========================================
  Future<void> markAsRead(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/notifications/$id/read');
      loadNotifications(silent: true);
    } catch (_) {}
  }

  /// ==========================================
  /// MARK ALL AS READ - Clear All Notifications
  /// ==========================================
  /// Marks every notification as read, resetting the unread count to zero.
  /// Used by the "Mark all as read" button in the notification panel.
  /// ==========================================
  Future<void> markAllAsRead() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/notifications/read-all');
      loadNotifications(silent: true);
    } catch (_) {}
  }
}

/// Provider that exposes the notification state to the widget tree
final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );
