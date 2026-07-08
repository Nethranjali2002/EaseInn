import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'web_notifications.dart';

class WebShell extends ConsumerWidget {
  final Widget child;

  const WebShell({super.key, required this.child});

  static const _sidebarWidth = 260.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final currentPath = GoRouterState.of(context).matchedLocation;

    final menuItems = _getMenuItems(user?.role ?? '');

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: _sidebarWidth,
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.hotel,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EaseInn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user?.role == 'admin'
                                  ? 'Admin Portal'
                                  : (user?.role == 'manager'
                                        ? 'Manager Portal'
                                        : 'Staff Portal'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                const SizedBox(height: 8),
                if (user != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: _roleColor(user.role),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user.role.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white24),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isActive = currentPath.startsWith(item.route);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          leading: Icon(
                            item.icon,
                            color: isActive ? Colors.white : Colors.white60,
                            size: 20,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white70,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          selected: isActive,
                          selectedTileColor: Colors.white.withOpacity(0.15),
                          onTap: () => context.go(item.route),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, ref, user, currentPath),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    UserInfo? user,
    String currentPath,
  ) {
    String title = 'Dashboard';
    if (currentPath.startsWith('/web/properties')) {
      title = 'Properties';
    } else if (currentPath.startsWith('/web/bookings'))
      title = 'Bookings';
    else if (currentPath.startsWith('/web/rooms'))
      title = 'Rooms';
    else if (currentPath.startsWith('/web/tasks'))
      title = 'Tasks';
    else if (currentPath.startsWith('/web/payments'))
      title = 'Financial Reports';
    else if (currentPath.startsWith('/web/users'))
      title = 'Users';
    else if (currentPath.startsWith('/web/feedback'))
      title = 'Feedback';
    else if (currentPath.startsWith('/web/calendar'))
      title = 'Calendar';
    else if (currentPath.startsWith('/web/notifications'))
      title = 'Notifications';
    else if (currentPath.startsWith('/web/audit-log'))
      title = 'Audit Log';
    else if (currentPath.startsWith('/web/profile'))
      title = 'Profile';

    final notifState = ref.watch(notificationProvider);
    final unread = notifState.unreadCount;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          Theme(
            data: Theme.of(context).copyWith(cardColor: Colors.white),
            child: PopupMenuButton<void>(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: Colors.grey.shade700,
                    size: 26,
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              offset: const Offset(0, 48),
              tooltip: 'Notifications',
              surfaceTintColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (ctx) => [
                PopupMenuItem<void>(
                  enabled: false,
                  child: Container(
                    width: 360,
                    constraints: const BoxConstraints(maxHeight: 450),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Notifications',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            if (unread > 0)
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(notificationProvider.notifier)
                                      .markAllAsRead();
                                  Navigator.pop(ctx);
                                },
                                child: const Text(
                                  'Mark all as read',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        const Divider(),
                        if (notifState.notifications.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No new notifications',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: notifState.notifications
                                  .take(5)
                                  .length,
                              itemBuilder: (c, idx) {
                                final n = notifState.notifications[idx];
                                return InkWell(
                                  onTap: () {
                                    if (!n.read) {
                                      ref
                                          .read(notificationProvider.notifier)
                                          .markAsRead(n.id);
                                    }
                                    Navigator.pop(ctx);
                                    context.go('/web/notifications');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        iconForType(n.type),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                n.title,
                                                style: TextStyle(
                                                  fontWeight: n.read
                                                      ? FontWeight.normal
                                                      : FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                n.message,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                timeAgo(n.createdAt),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!n.read)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const Divider(),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.go('/web/notifications');
                            },
                            child: const Text('See All Notifications'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Theme(
            data: Theme.of(context).copyWith(cardColor: Colors.white),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 48),
              surfaceTintColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (val) async {
                switch (val) {
                  case 'profile':
                    context.go('/web/profile?tab=profile');
                    break;
                  case 'settings':
                    context.go('/web/profile?tab=settings');
                    break;
                  case 'change_password':
                    context.go('/web/profile?tab=password');
                    break;
                  case 'activity':
                    context.go('/web/profile?tab=activity');
                    break;
                  case 'logout':
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) {
                        bool isChecked = false;
                        return StatefulBuilder(
                          builder: (ctx, setDialogState) {
                            return AlertDialog(
                              title: const Text('Confirm Logout'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Are you sure you want to log out of your EaseInn account?',
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isChecked,
                                        onChanged: (val) {
                                          setDialogState(() {
                                            isChecked = val ?? false;
                                          });
                                        },
                                      ),
                                      const Expanded(
                                        child: Text(
                                          'I confirm I want to end my active session.',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isChecked
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                  onPressed: isChecked
                                      ? () => Navigator.pop(ctx, true)
                                      : null,
                                  child: const Text('Logout'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                    if (confirmed == true && context.mounted) {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/web/login');
                    }
                    break;
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                      child: Text(
                        user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: Colors.black87,
                      ),
                      SizedBox(width: 10),
                      Text('My Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: Colors.black87,
                      ),
                      SizedBox(width: 10),
                      Text('Account Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'change_password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: Colors.black87),
                      SizedBox(width: 10),
                      Text('Change Password'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'activity',
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18, color: Colors.black87),
                      SizedBox(width: 10),
                      Text('Activity Log'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ==========================================
  /// ROLE COLOR - Visual Role Indicator
  /// ==========================================
  /// Returns a color associated with each user role.
  /// Used for the role badge displayed next to the user's name.
  /// ==========================================
  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFF6F00);
      case 'manager':
        return const Color(0xFF1565C0);
      case 'staff':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  /// ==========================================
  /// MENU ITEMS - Role-Based Navigation
  /// ==========================================
  /// Builds the sidebar navigation menu based on the user's role.
  /// Different roles see different menu items:
  ///
  /// ALL ROLES:
  ///   - Dashboard
  ///   - Tasks
  ///   - Notifications
  ///   - Calendar
  ///
  /// ADMIN & MANAGER:
  ///   - Properties
  ///   - Bookings
  ///   - Rooms
  ///   - Financial Reports
  ///   - Feedback
  ///
  /// ADMIN ONLY:
  ///   - Users
  ///   - Audit Log
  /// ==========================================
  List<_MenuItem> _getMenuItems(String role) {
    final items = <_MenuItem>[
      _MenuItem(Icons.dashboard_outlined, 'Dashboard', '/web/dashboard'),
    ];

    if (role == 'admin' || role == 'manager') {
      items.add(
        _MenuItem(Icons.business_outlined, 'Properties', '/web/properties'),
      );
      items.add(
        _MenuItem(Icons.calendar_today_outlined, 'Bookings', '/web/bookings'),
      );
      items.add(_MenuItem(Icons.king_bed_outlined, 'Rooms', '/web/rooms'));
    }

    items.add(_MenuItem(Icons.task_outlined, 'Tasks', '/web/tasks'));

    if (role == 'admin' || role == 'manager') {
      items.add(
        _MenuItem(
          Icons.bar_chart_outlined,
          'Financial Reports',
          '/web/payments',
        ),
      );
    }

    if (role == 'admin') {
      items.add(_MenuItem(Icons.people_outlined, 'Users', '/web/users'));
    }

    if (role == 'admin' || role == 'manager') {
      items.add(_MenuItem(Icons.star_outline, 'Feedback', '/web/feedback'));
    }

    items.add(
      _MenuItem(
        Icons.notifications_outlined,
        'Notifications',
        '/web/notifications',
      ),
    );

    items.add(
      _MenuItem(Icons.calendar_month_outlined, 'Calendar', '/web/calendar'),
    );

    if (role == 'admin') {
      items.add(_MenuItem(Icons.history, 'Audit Log', '/web/audit-log'));
    }

    return items;
  }
}

/// ==========================================
/// MENU ITEM - Sidebar Navigation Item Data
/// ==========================================
/// Simple data class holding the icon, label, and route for a sidebar menu item.
/// ==========================================
class _MenuItem {
  final IconData icon;
  final String label;
  final String route;

  _MenuItem(this.icon, this.label, this.route);
}
