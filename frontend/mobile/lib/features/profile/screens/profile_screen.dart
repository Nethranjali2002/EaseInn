/// Profile Screen - Displays user information and role-based access details.
///
/// This screen serves as both a profile viewer and a settings hub:
/// - Shows user avatar (or initials fallback), name, email, and role badge
/// - Displays detailed user info (Staff ID, permissions, accessible features)
/// - Provides navigation to Change Password screen
/// - Handles logout with proper cleanup and navigation to login
///
/// The screen is role-aware: admins see full permission details, managers see
/// operational access, and staff see limited task-only access. This transparency
/// helps users understand what they can do within the app.
///
/// Architecture notes:
/// - Uses [ConsumerWidget] (stateless) because the profile is read-only data
///   from the auth provider. No local state management needed.
/// - Logout captures the router reference before async gap to avoid context
///   issues after await (a common Flutter gotcha).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth provider for current user data - rebuilds if user state changes
    final auth = ref.watch(authProvider);
    final user = auth.user;

    // Guard clause: if somehow accessed without being logged in, show fallback
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar with fallback: shows profile image if available,
            // otherwise displays the user's first initial as a placeholder.
            // This pattern is common in apps where profile images are optional.
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.1),
              backgroundImage: (user.profileImage.isNotEmpty) ? NetworkImage(resolveImageUrl(user.profileImage)) : null,
              child: (user.profileImage.isEmpty)
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            // User identity section
            Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user.email, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            // Role badge with color coding: red=admin, blue=manager, green=staff.
            // Color coding provides instant visual recognition of user level.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: user.isAdmin ? Colors.red.shade50 : user.isManager ? Colors.blue.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.role.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: user.isAdmin ? Colors.red : user.isManager ? Colors.blue : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // User details card - shows all account information
            // SelectableText for Staff ID allows easy copying (useful for support)
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Name'),
                    subtitle: Text(user.name),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Staff ID'),
                    subtitle: SelectableText(user.id),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(user.email),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Role'),
                    subtitle: Text(user.role == 'admin' ? 'Administrator (Full Access)' : user.role == 'manager' ? 'Manager (Operations)' : 'Staff (Task Only)'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Permissions'),
                    subtitle: Text(user.isAdmin
                        ? 'Properties, Rooms, Bookings, Tasks, Payments, Analytics, Users'
                        : user.isManager
                            ? 'Rooms, Bookings, Tasks, Payments, Analytics'
                            : 'View/Complete Assigned Tasks'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Feature access matrix - visual permission overview.
            // Helps users quickly see what they can and cannot access,
            // reducing confusion and support tickets about "missing features".
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Accessible Features', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _PermissionChip(label: 'Dashboard', allowed: true),
                    _PermissionChip(label: 'Tasks', allowed: true),
                    _PermissionChip(label: 'Bookings', allowed: user.isManager),
                    _PermissionChip(label: 'Properties/Rooms', allowed: user.isManager),
                    _PermissionChip(label: 'Payments', allowed: user.isManager),
                    _PermissionChip(label: 'Analytics', allowed: user.isManager),
                    if (user.isAdmin) _PermissionChip(label: 'User Management', allowed: true),
                    if (user.isAdmin) _PermissionChip(label: 'AI Insights', allowed: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            AppButton(
              label: 'Change Password',
              isOutlined: true,
              onPressed: () => context.go('/change-password'),
            ),
            const SizedBox(height: 12),
            // Logout button - captures router reference before async operation.
            // This is critical: after await, the context may be disposed if the
            // widget is unmounted, so we save the router reference beforehand.
            AppButton(
              label: 'Sign Out',
              isOutlined: true,
              onPressed: () async {
                final router = GoRouter.of(context);
                await ref.read(authProvider.notifier).logout();
                router.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual permission indicator that shows whether a feature is accessible.
///
/// Displays a green checkmark with normal text for allowed features,
/// and a red cancel icon with strikethrough text for denied features.
/// This visual pattern (icon + text + strikethrough) is a universally
/// understood way to convey allowed/denied states without requiring
/// additional explanation.
class _PermissionChip extends StatelessWidget {
  final String label;
  final bool allowed;
  const _PermissionChip({required this.label, required this.allowed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(allowed ? Icons.check_circle : Icons.cancel, size: 16, color: allowed ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: allowed ? Colors.black87 : Colors.grey, decoration: allowed ? null : TextDecoration.lineThrough)),
        ],
      ),
    );
  }
}
