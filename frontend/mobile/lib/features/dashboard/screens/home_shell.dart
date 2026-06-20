import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

/// ==========================================
/// HOME SHELL - Mobile App Layout with Bottom Navigation
/// ==========================================
/// Provides the persistent layout for the mobile staff app:
/// - Top AppBar with app title, notification badge, and profile button
/// - Bottom navigation bar with 3 tabs: Home, Tasks, Profile
/// - Content area that displays the current tab's screen
///
/// This widget is used as a ShellRoute wrapper in the router,
/// providing the persistent chrome while the content area changes.
///
/// NOTE: This widget is currently unused in the router (routes go
/// directly to screens). It's kept as a template for when bottom
/// navigation is implemented.
/// ==========================================
class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  /// Index of the currently selected bottom navigation tab
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch properties on first load (needed for task context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(propertyProvider.notifier).fetchProperties();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final isAdmin = user?.isAdmin ?? false;
    final isManager = user?.isManager ?? false;
    final notifState = ref.watch(notificationProvider);

    // ==========================================
    // BOTTOM NAVIGATION - Staff-Only Simplified Nav
    // ==========================================
    // The mobile app is STAFF-ONLY, so navigation is simplified
    // to just three tabs: Home, Tasks, Profile.
    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tasks'),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
    ];

    // Route paths for each tab
    final routes = <String>[
      '/dashboard',
      '/tasks',
      '/profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('EaseInn${isAdmin ? ' (Admin)' : isManager ? ' (Manager)' : ' (Staff)'}'),
        actions: [
          // ==========================================
          // NOTIFICATION BADGE - Unread Count
          // ==========================================
          IconButton(
            icon: Badge(
              isLabelVisible: notifState.unreadCount > 0,
              label: notifState.unreadCount > 99 ? const Text('99+') : Text('${notifState.unreadCount}'),
              backgroundColor: Colors.red,
              textColor: Colors.white,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.go('/notifications'),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: widget.child,
      // ==========================================
      // BOTTOM NAVIGATION BAR
      // ==========================================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          context.go(routes[index]);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey,
        items: navItems,
      ),
    );
  }
}
