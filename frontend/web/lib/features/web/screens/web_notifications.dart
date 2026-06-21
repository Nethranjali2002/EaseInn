import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

class WebNotificationsScreen extends ConsumerStatefulWidget {
  const WebNotificationsScreen({super.key});

  @override
  ConsumerState<WebNotificationsScreen> createState() =>
      _WebNotificationsScreenState();
}

class _WebNotificationsScreenState
    extends ConsumerState<WebNotificationsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final notifications = state.notifications;
    final unreadCount = state.unreadCount;
    final isLoading = state.isLoading;

    final filtered = notifications.where((n) {
      if (_selectedFilter == 'All') return true;
      final type = n.type.toLowerCase();
      final msg = n.message.toLowerCase();
      final title = n.title.toLowerCase();
      switch (_selectedFilter) {
        case 'Bookings':
          return type.contains('booking') || msg.contains('bk-') || title.contains('booking');
        case 'Rooms':
          return type.contains('room') || msg.contains('room') || title.contains('room');
        case 'Tasks':
          return type.contains('task') || msg.contains('task') || title.contains('task');
        case 'Users':
          return type.contains('user') || title.contains('user') || type.contains('profile');
        case 'Feedback':
          return type.contains('feedback') || msg.contains('review') || title.contains('feedback');
        default:
          return true;
      }
    }).toList();

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
                  const Text('Real-Time Alert Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                      child: Text('$unreadCount Unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh Notifications', onPressed: () => ref.read(notificationProvider.notifier).loadNotifications()),
                  const SizedBox(width: 8),
                  if (unreadCount > 0)
                    ElevatedButton.icon(
                      onPressed: () => ref.read(notificationProvider.notifier).markAllAsRead(),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark All as Read'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Bookings', 'Rooms', 'Tasks', 'Users', 'Feedback'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) { if (selected) setState(() => _selectedFilter = filter); },
                    selectedColor: const Color(0xFF1B5E20).withOpacity(0.15),
                    labelStyle: TextStyle(color: isSelected ? const Color(0xFF1B5E20) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
              child: isLoading && filtered.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('No matching notifications found.'))
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                    child: DataTable(
                                      showCheckboxColumn: false,
                                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                                      columns: const [
                                        DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Message', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: filtered.map((n) {
                                        final timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(n.createdAt);
                                        return DataRow(
                                          onSelectChanged: (_) => _handleNotificationClick(context, ref, n),
                                          cells: [
                                            DataCell(Text(timeStr, style: const TextStyle(fontSize: 13))),
                                            DataCell(_buildTypeBadge(n.type)),
                                            DataCell(Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
                                                const SizedBox(height: 2),
                                                Text(n.message, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis),
                                              ],
                                            )),
                                            DataCell(Text(n.read ? 'READ' : 'UNREAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: n.read ? Colors.grey : Colors.red))),
                                            DataCell(Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (!n.read)
                                                  IconButton(
                                                    icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                                                    tooltip: 'Mark as read',
                                                    onPressed: () => ref.read(notificationProvider.notifier).markAsRead(n.id),
                                                  ),
                                                IconButton(
                                                  icon: const Icon(Icons.launch, size: 16),
                                                  tooltip: 'View details',
                                                  onPressed: () => _handleNotificationClick(context, ref, n),
                                                ),
                                              ],
                                            )),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color = Colors.grey;
    final cleanType = type.toLowerCase();
    if (cleanType.contains('booking')) {
      color = Colors.blue;
    } else if (cleanType.contains('room')) {
      color = Colors.indigo;
    } else if (cleanType.contains('task')) {
      color = Colors.orange;
    } else if (cleanType.contains('feedback') || cleanType.contains('review')) {
      color = Colors.amber;
    } else if (cleanType.contains('user') || cleanType.contains('profile')) {
      color = Colors.teal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(cleanType.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  void _handleNotificationClick(BuildContext context, WidgetRef ref, NotificationItem n) {
    if (!n.read) {
      ref.read(notificationProvider.notifier).markAsRead(n.id);
    }
    final msg = n.message.toLowerCase();
    final type = n.type.toLowerCase();
    if (type.contains('booking') || msg.contains('bk-')) {
      context.go('/web/bookings');
    } else if (type.contains('task') || msg.contains('task')) {
      context.go('/web/tasks');
    } else if (type.contains('feedback') || msg.contains('review') || msg.contains('feedback')) {
      context.go('/web/feedback');
    } else if (type.contains('user') || type.contains('profile')) {
      context.go('/web/users');
    } else if (type.contains('room') || msg.contains('room')) {
      context.go('/web/rooms');
    } else {
      context.go('/web/dashboard');
    }
  }
}

Widget iconForType(String type) {
  IconData icon;
  Color color;
  final cleanType = type.toLowerCase();
  if (cleanType.contains('booking')) {
    icon = Icons.calendar_today;
    color = Colors.blue;
  } else if (cleanType.contains('payment')) {
    icon = Icons.payment;
    color = Colors.green;
  } else if (cleanType.contains('task')) {
    icon = Icons.task_alt;
    color = Colors.orange;
  } else if (cleanType.contains('feedback') || cleanType.contains('review')) {
    icon = Icons.star;
    color = Colors.amber;
  } else if (cleanType.contains('room')) {
    icon = Icons.king_bed_outlined;
    color = Colors.indigo;
  } else {
    icon = Icons.notifications;
    color = Colors.grey;
  }
  return CircleAvatar(
    backgroundColor: color.withOpacity(0.1),
    radius: 16,
    child: Icon(icon, color: color, size: 16),
  );
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('dd MMM').format(date);
}
