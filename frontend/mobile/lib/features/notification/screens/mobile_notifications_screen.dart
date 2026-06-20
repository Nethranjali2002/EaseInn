/// Mobile Notifications Screen - Displays a chronological list of user notifications.
///
/// This screen provides:
/// - Real-time notification list from the backend
/// - Visual differentiation by notification type (booking, payment, task, feedback)
/// - Read/unread status with visual indicators (bold text + green dot)
/// - "Mark all as read" action in the app bar
/// - Pull-to-refresh for manual sync
/// - Relative time formatting (e.g., "5m ago", "2d ago")
///
/// Architecture notes:
/// - Uses [ConsumerStatefulWidget] because we need lifecycle hooks (initState)
///   to trigger initial data load, plus Riverpod for state management.
/// - The notification provider handles both the data fetching and read/unread
///   state management, keeping this screen focused on presentation.
/// - The [RefreshIndicator] wrapper enables pull-to-refresh, which is a
///   standard mobile pattern for list screens.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

class MobileNotificationsScreen extends ConsumerStatefulWidget {
  const MobileNotificationsScreen({super.key});

  @override
  ConsumerState<MobileNotificationsScreen> createState() =>
      _MobileNotificationsScreenState();
}

class _MobileNotificationsScreenState
    extends ConsumerState<MobileNotificationsScreen> {
  /// Load notifications after the widget tree is built.
  /// Using postFrameCallback ensures we don't trigger a rebuild during build phase.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the notification provider for reactive updates
    final state = ref.watch(notificationProvider);
    final notifications = state.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        // "Mark all read" button - only shown when there are unread notifications.
        // This avoids visual clutter when everything is already read.
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () async {
                await ref.read(notificationProvider.notifier).markAllAsRead();
              },
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      // Three-state body: loading, empty, or list.
      // The loading check `state.isLoading && notifications.isEmpty` prevents
      // showing a spinner when refreshing an already-loaded list.
      body: state.isLoading && notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No notifications', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    ],
                  ),
                )
              // RefreshIndicator enables pull-to-refresh - standard mobile pattern
              // for list screens that can be updated from the server.
              : RefreshIndicator(
                  onRefresh: () => ref.read(notificationProvider.notifier).loadNotifications(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return ListTile(
                        leading: _notificationIcon(n.type),
                        // Unread notifications are bold for visual emphasis
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(n.message, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(height: 4),
                            // Relative time display (e.g., "5m ago") is more
                            // intuitive than absolute timestamps for recent events
                            Text(
                              _formatTime(n.createdAt),
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                            ),
                          ],
                        ),
                        // Green dot indicator for unread notifications
                        // (same color as the app's primary brand color)
                        trailing: !n.read
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B5E20),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        // Tapping marks the notification as read - no deep navigation
                        // because these are informational, not actionable.
                        onTap: () {
                          if (!n.read) {
                            ref.read(notificationProvider.notifier).markAsRead(n.id);
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }

  /// Maps notification types to appropriate icons and colors.
  ///
  /// Color coding helps users quickly identify notification categories:
  /// - Blue: Booking-related (calendar icon)
  /// - Green: Payment-related (payment icon)
  /// - Orange: Task-related (task icon)
  /// - Purple: Feedback (star icon)
  /// - Grey: Default/info
  Widget _notificationIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'booking_confirmed':
      case 'booking_cancelled':
        icon = Icons.calendar_today;
        color = const Color(0xFF1565C0);
        break;
      case 'payment_received':
      case 'payment_reminder':
        icon = Icons.payment;
        color = const Color(0xFF2E7D32);
        break;
      case 'task_assigned':
      case 'task_completed':
      case 'task_overdue':
        icon = Icons.task_alt;
        color = const Color(0xFFE65100);
        break;
      case 'feedback_received':
        icon = Icons.star;
        color = const Color(0xFF6A1B9A);
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, size: 16, color: color),
    );
  }

  /// Formats a DateTime into a human-friendly relative time string.
  ///
  /// Uses progressive granularity:
  /// - < 1 minute: "Just now" (avoids "0m ago" which looks odd)
  /// - < 1 hour: "Xm ago"
  /// - < 1 day: "Xh ago"
  /// - < 7 days: "Xd ago"
  /// - Older: Full date format "dd MMM yyyy"
  ///
  /// This is more user-friendly than showing absolute timestamps,
  /// especially for a mobile app where users check notifications frequently.
  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy').format(dt);
  }
}
