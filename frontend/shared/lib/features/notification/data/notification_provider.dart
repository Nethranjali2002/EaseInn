import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
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

class NotificationNotifier extends Notifier<NotificationState> {
  Timer? _timer;

  @override
  NotificationState build() {
    Future.microtask(() => loadNotifications());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      loadNotifications(silent: true);
    });
    ref.onDispose(() {
      _timer?.cancel();
    });
    return NotificationState();
  }

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
      final res = await api.get('/notifications');
      final items = (res.data['data']['notifications'] as List?)
              ?.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [];
      final unreadRes = await api.get('/notifications/unread');
      state = NotificationState(
        notifications: items,
        unreadCount: unreadRes.data['data']['count'] ?? 0,
        isLoading: false,
      );
    } catch (_) {
      if (!silent) {
        state = NotificationState(
          notifications: state.notifications,
          unreadCount: state.unreadCount,
          isLoading: false,
        );
      }
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/notifications/$id/read');
      loadNotifications(silent: true);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/notifications/read-all');
      loadNotifications(silent: true);
    } catch (_) {}
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
      NotificationNotifier.new,
    );
