import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/data/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF1B5E20).withValues(alpha: 0.1),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
              ),
            ),
            const SizedBox(height: 16),
            Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user.email, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
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
            AppButton(
              label: 'Change Password',
              isOutlined: true,
              onPressed: () => context.go('/change-password'),
            ),
            const SizedBox(height: 12),
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
