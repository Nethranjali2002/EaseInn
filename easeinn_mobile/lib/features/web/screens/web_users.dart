import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../profile/data/user_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

class AdminUsersState {
  final List<User> users;
  final bool isLoading;
  final String? error;

  AdminUsersState({this.users = const [], this.isLoading = false, this.error});
}

final adminUsersProvider = NotifierProvider<AdminUsersNotifier, AdminUsersState>(AdminUsersNotifier.new);

class AdminUsersNotifier extends Notifier<AdminUsersState> {
  @override
  AdminUsersState build() => AdminUsersState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetchUsers() async {
    state = AdminUsersState(isLoading: true);
    try {
      final response = await _api.get('/admin/users');
      final users = (response.data['data']['users'] as List)
          .map((u) => User.fromJson(u as Map<String, dynamic>))
          .toList();
      state = AdminUsersState(users: users);
    } on ApiException catch (e) {
      state = AdminUsersState(error: e.message);
    } catch (e) {
      state = AdminUsersState(error: 'Failed to load users');
    }
  }

  Future<bool> updateUserRole(String userId, String role) async {
    try {
      final response = await _api.patch('/admin/users/$userId/role', data: {'role': role});
      final updatedUser = User.fromJson(response.data['data']['user'] as Map<String, dynamic>);
      state = AdminUsersState(users: state.users.map((u) => u.id == userId ? updatedUser : u).toList());
      return true;
    } on ApiException catch (e) {
      state = AdminUsersState(users: state.users, error: e.message);
      return false;
    }
  }

  Future<bool> toggleUserStatus(String userId, bool isActive) async {
    try {
      final response = await _api.patch('/admin/users/$userId/status', data: {'isActive': isActive});
      final updatedUser = User.fromJson(response.data['data']['user'] as Map<String, dynamic>);
      state = AdminUsersState(users: state.users.map((u) => u.id == userId ? updatedUser : u).toList());
      return true;
    } on ApiException catch (e) {
      state = AdminUsersState(users: state.users, error: e.message);
      return false;
    }
  }

  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/admin/users', data: data);
      final newUser = User.fromJson(response.data['data']['user'] as Map<String, dynamic>);
      state = AdminUsersState(users: [newUser, ...state.users]);
      return true;
    } on ApiException catch (e) {
      state = AdminUsersState(users: state.users, error: e.message);
      return false;
    }
  }
}

class WebUsersScreen extends ConsumerStatefulWidget {
  const WebUsersScreen({super.key});

  @override
  ConsumerState<WebUsersScreen> createState() => _WebUsersScreenState();
}

class _WebUsersScreenState extends ConsumerState<WebUsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminUsersProvider.notifier).fetchUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('User Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add User'),
                    onPressed: () => _showAddUserDialog(context),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.read(adminUsersProvider.notifier).fetchUsers()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.users.isEmpty
                    ? const Center(child: Text('No users found'))
                    : Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Joined')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: state.users.map((u) => DataRow(cells: [
                              DataCell(Row(children: [
                                CircleAvatar(radius: 14, backgroundColor: _roleColor(u.role).withValues(alpha: 0.1), child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?', style: TextStyle(color: _roleColor(u.role), fontSize: 12, fontWeight: FontWeight.bold))),
                                const SizedBox(width: 8),
                                Text(u.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ])),
                              DataCell(Text(u.email)),
                              DataCell(SizedBox(
                                width: 130,
                                child: DropdownButton<String>(
                                  value: ['admin', 'manager', 'staff'].contains(u.role) ? u.role : 'staff',
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                                  ],
                                  onChanged: (newRole) async {
                                    if (newRole != null && newRole != u.role) {
                                      final success = await ref.read(adminUsersProvider.notifier).updateUserRole(u.id, newRole);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(success ? 'Role updated to $newRole' : 'Failed'), backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red),
                                        );
                                      }
                                    }
                                  },
                                ),
                              )),
                              DataCell(Text(u.createdAt != null ? DateFormat('MMM dd, yyyy').format(u.createdAt!) : '-')),
                              DataCell(IconButton(
                                icon: Icon(u.isActive ? Icons.toggle_on : Icons.toggle_off, color: u.isActive ? Colors.green : Colors.red),
                                onPressed: () async {
                                  final success = await ref.read(adminUsersProvider.notifier).toggleUserStatus(u.id, !(u.isActive));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(success ? 'User ${u.isActive ? "deactivated" : "activated"}' : 'Failed'), backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red),
                                    );
                                  }
                                },
                              )),
                            ])).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddUserDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String role = 'staff';
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Add New User'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                          obscureText: true,
                          validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: role,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'staff', child: Text('Staff')),
                            DropdownMenuItem(value: 'manager', child: Text('Manager')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => role = v);
                          },
                          decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        
                        final data = {
                          'name': nameController.text.trim(),
                          'email': emailController.text.trim(),
                          'password': passwordController.text.trim(),
                          'role': role,
                        };
                        
                        final success = await ref.read(adminUsersProvider.notifier).createUser(data);
                        if (ctx.mounted) Navigator.pop(ctx, success);
                      },
                child: isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created successfully'), backgroundColor: Color(0xFF2E7D32)),
      );
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return const Color(0xFFFF6F00);
      case 'manager': return const Color(0xFF1565C0);
      case 'staff': return const Color(0xFF2E7D32);
      default: return Colors.grey;
    }
  }
}
