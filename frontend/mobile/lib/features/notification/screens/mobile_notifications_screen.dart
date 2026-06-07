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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final notifications = state.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
                            Text(
                              _formatTime(n.createdAt),
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                            ),
                          ],
                        ),
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
