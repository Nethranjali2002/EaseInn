import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
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
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      read: json['read'] ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class WebNotificationState {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool isLoading;

  WebNotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });
}

class WebNotificationNotifier extends Notifier<WebNotificationState> {
  Timer? _timer;

  @override
  WebNotificationState build() {
    Future.microtask(() => loadNotifications());

    // Live polling: check for new notifications in background every 15 seconds
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      loadNotifications(silent: true);
    });

    ref.onDispose(() {
      _timer?.cancel();
    });

    return WebNotificationState();
  }

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      state = WebNotificationState(
        notifications: state.notifications,
        unreadCount: state.unreadCount,
        isLoading: true,
      );
    }
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/notifications');
      final items =
          (res.data['data']['notifications'] as List?)
              ?.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [];
      final unreadRes = await api.get('/notifications/unread');
      state = WebNotificationState(
        notifications: items,
        unreadCount: unreadRes.data['data']['count'] ?? 0,
        isLoading: false,
      );
    } catch (_) {
      if (!silent) {
        state = WebNotificationState(
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
      loadNotifications();
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/notifications/read-all');
      loadNotifications();
    } catch (_) {}
  }
}

final webNotificationProvider =
    NotifierProvider.autoDispose<WebNotificationNotifier, WebNotificationState>(
      WebNotificationNotifier.new,
    );

class WebNotificationsScreen extends ConsumerWidget {
  const WebNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(webNotificationProvider);
    final notifications = state.notifications;
    final unreadCount = state.unreadCount;
    final isLoading = state.isLoading;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount new',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref
                        .read(webNotificationProvider.notifier)
                        .loadNotifications(),
                  ),
                  if (unreadCount > 0)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(webNotificationProvider.notifier)
                          .markAllAsRead(),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Mark all as read'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isLoading && notifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : notifications.isEmpty
                ? const Center(child: Text('No notifications'))
                : ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (ctx, i) {
                      final n = notifications[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: n.read
                            ? null
                            : const Color(0xFFE8F5E9).withValues(alpha: 0.3),
                        child: ListTile(
                          leading: iconForType(n.type),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.read
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            n.message,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeAgo(n.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              if (!n.read)
                                IconButton(
                                  icon: const Icon(
                                    Icons.mark_email_read,
                                    size: 18,
                                  ),
                                  tooltip: 'Mark as read',
                                  onPressed: () => ref
                                      .read(webNotificationProvider.notifier)
                                      .markAsRead(n.id),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Widget iconForType(String type) {
  IconData icon;
  Color color;
  switch (type) {
    case 'booking_confirmed':
    case 'booking_cancelled':
      icon = Icons.calendar_today;
      color = Colors.blue;
      break;
    case 'payment_received':
    case 'payment_reminder':
      icon = Icons.payment;
      color = Colors.green;
      break;
    case 'task_assigned':
    case 'task_completed':
    case 'task_overdue':
      icon = Icons.task_alt;
      color = Colors.orange;
      break;
    case 'feedback_received':
      icon = Icons.star;
      color = Colors.amber;
      break;
    default:
      icon = Icons.notifications;
      color = Colors.grey;
  }
  return CircleAvatar(
    backgroundColor: color.withOpacity(0.1),
    child: Icon(icon, color: color, size: 20),
  );
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}/${date.year}';
}
