/// Admin User Management Screen — CRUD, role assignment, status toggle.
///
/// Manages all admin and staff users for the PMS. Provides a searchable table
/// with role-based access control, user creation/editing dialogs, and
/// quick status toggling for enabling/disabling accounts.
///
/// Key features:
/// - Summary cards: total users, active, inactive, admin count, staff count
/// - Multi-criteria filters: search, role, status, property assignment
/// - User creation/editing with role-dependent property assignment
/// - Profile image upload for user avatars
/// - Quick status toggle (active/inactive) without opening edit dialog
/// - Role badges with color coding (admin=red, manager=blue, staff=green, etc.)
///
/// State management: adminUsersProvider (Riverpod) defined in this file.
/// Users fetched from /api/admin/users with optional role/status filters.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import '../widgets/web_data_table.dart';
import '../widgets/web_form_dialog.dart';

/// State class holding user list, loading state, and error for the admin users screen.
class AdminUsersState {
  final List<User> users;
  final bool isLoading;
  final String? error;

  AdminUsersState({this.users = const [], this.isLoading = false, this.error});
}

final adminUsersProvider =
    NotifierProvider<AdminUsersNotifier, AdminUsersState>(
      AdminUsersNotifier.new,
    );

/// Notifier managing admin user CRUD operations and state.
class AdminUsersNotifier extends Notifier<AdminUsersState> {
  @override
  AdminUsersState build() => AdminUsersState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// Fetches all users from the admin users API endpoint.
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

  /// Updates a user's role (admin, manager, staff, etc.) via PATCH request.
  /// Returns true on success, false on error (error stored in state).
  Future<bool> updateUserRole(String userId, String role) async {
    try {
      final response = await _api.patch(
        '/admin/users/$userId/role',
        data: {'role': role},
      );
      final updatedUser = User.fromJson(
        response.data['data']['user'] as Map<String, dynamic>,
      );
      state = AdminUsersState(
        users: state.users
            .map((u) => u.id == userId ? updatedUser : u)
            .toList(),
      );
      return true;
    } on ApiException catch (e) {
      state = AdminUsersState(users: state.users, error: e.message);
      return false;
    }
  }

  /// Toggles user active/inactive status without deleting the account.
  Future<bool> toggleUserStatus(String userId, bool isActive) async {
    try {
      final response = await _api.patch(
        '/admin/users/$userId/status',
        data: {'isActive': isActive},
      );
      final updatedUser = User.fromJson(
        response.data['data']['user'] as Map<String, dynamic>,
      );
      state = AdminUsersState(
        users: state.users
            .map((u) => u.id == userId ? updatedUser : u)
            .toList(),
      );
      return true;
    } on ApiException catch (e) {
      state = AdminUsersState(users: state.users, error: e.message);
      return false;
    }
  }

  /// Creates a new user with the provided data (name, email, role, properties, etc.).
  Future<bool> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _api.post('/admin/users', data: data);
      final newUser = User.fromJson(
        response.data['data']['user'] as Map<String, dynamic>,
      );
      state = AdminUsersState(users: [newUser, ...state.users]);
      return true;
    } on ApiException catch (e) {
      state = AdminUsersState(users: state.users, error: e.message);
      return false;
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _api.patch('/admin/users/$userId', data: data);
      final updatedUser = User.fromJson(
        response.data['data']['user'] as Map<String, dynamic>,
      );
      state = AdminUsersState(
        users: state.users
            .map((u) => u.id == userId ? updatedUser : u)
            .toList(),
      );
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

class _WebUsersScreenState extends ConsumerState<WebUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRole = 'All';
  String _selectedPropertyId = 'All';
  String _selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ref.read(propertyProvider.notifier).fetchProperties();
    await ref.read(adminUsersProvider.notifier).fetchUsers();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedRole = 'All';
      _selectedPropertyId = 'All';
      _selectedStatus = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersProvider);
    final properties = ref.watch(propertyProvider).properties;

    // Apply filtering
    final filteredUsers = state.users.where((u) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            u.employeeId.toLowerCase().contains(q) ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.phone.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedRole != 'All') {
        if (u.role.toLowerCase() != _selectedRole.toLowerCase()) return false;
      }
      if (_selectedPropertyId != 'All') {
        if (u.property != _selectedPropertyId) return false;
      }
      if (_selectedStatus != 'All') {
        if (u.status.toLowerCase() != _selectedStatus.toLowerCase())
          return false;
      }
      return true;
    }).toList();

    // Summary calculation
    final totalUsers = filteredUsers.length;
    final activeUsers = filteredUsers
        .where((u) => u.status.toLowerCase() == 'active')
        .length;
    final inactiveUsers = filteredUsers
        .where((u) => u.status.toLowerCase() == 'inactive')
        .length;
    final managers = filteredUsers
        .where((u) => u.role.toLowerCase() == 'manager')
        .length;
    final staffMembers = filteredUsers
        .where((u) => u.role.toLowerCase() == 'staff')
        .length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Users'),
                  Tab(text: 'Roles & Permissions'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Users View
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth > 1000;
                          final cardWidth = isDesktop
                              ? (constraints.maxWidth - (12 * 4)) / 5
                              : (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Total Users',
                                  '$totalUsers',
                                  Icons.people_outline,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Active Users',
                                  '$activeUsers',
                                  Icons.check_circle_outline,
                                  Colors.green,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Inactive Users',
                                  '$inactiveUsers',
                                  Icons.pause_circle_outline,
                                  Colors.orange,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Managers',
                                  '$managers',
                                  Icons.manage_accounts,
                                  Colors.purple,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Staff Members',
                                  '$staffMembers',
                                  Icons.badge_outlined,
                                  Colors.indigo,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Filter Section
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Filters',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add User'),
                                    onPressed: () =>
                                        _showAddUserDialog(context, properties),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isDesktop = constraints.maxWidth > 1000;
                                  final double itemWidth = isDesktop
                                      ? (constraints.maxWidth - (12 * 3)) / 4
                                      : (constraints.maxWidth - 12) / 2;
                                  final double searchWidth = isDesktop
                                      ? itemWidth * 2 + 12
                                      : constraints.maxWidth;

                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: searchWidth,
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Search by ID, Name, Email, Phone...',
                                            prefixIcon: Icon(
                                              Icons.search,
                                              size: 20,
                                            ),
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedRole,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'All',
                                              child: Text('All Roles'),
                                            ),
                                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                            DropdownMenuItem(value: 'manager', child: Text('Manager')),
                                            DropdownMenuItem(value: 'staff', child: Text('Staff')),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _selectedRole = v!,
                                          ),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedPropertyId,
                                          items: [
                                            const DropdownMenuItem(
                                              value: 'All',
                                              child: Text('All Properties'),
                                            ),
                                            ...properties.map(
                                              (p) => DropdownMenuItem(
                                                value: p.id,
                                                child: Text(p.name),
                                              ),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _selectedPropertyId = v!,
                                          ),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _selectedStatus,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'All',
                                              child: Text('All Statuses'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'active',
                                              child: Text('Active'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'inactive',
                                              child: Text('Inactive'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'suspended',
                                              child: Text('Suspended'),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _selectedStatus = v!,
                                          ),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.filter_alt_off,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Clear Filters',
                                        onPressed: _clearFilters,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // User Listing Table
                      state.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredUsers.isEmpty
                          ? const Center(
                              child: Text('No users found matching filters.'),
                            )
                          : WebDataTable(
                              showSearch: false,
                              searchHint: 'Filtered Users',
                              columns: const [
                                DataColumn(label: Text('Employee ID')),
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Role')),
                                DataColumn(label: Text('Property')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Last Login')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filteredUsers
                                  .map((u) => _userRow(u, properties))
                                  .toList(),
                            ),
                    ],
                  ),
                ),

                // Tab 2: Roles & Permissions Matrix
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.admin_panel_settings, size: 20, color: Colors.indigo.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              'Roles Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Roles Table
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    showCheckboxColumn: false,
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.grey.shade50,
                                    ),
                                    dataRowColor: WidgetStateProperty.all(
                                      Colors.white,
                                    ),
                                    border: TableBorder(
                                      horizontalInside: BorderSide(
                                        color: Colors.grey.shade100,
                                      ),
                                    ),
                                    columnSpacing: 40,
                                    columns: const [
                                      DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Assigned Users', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: [
                                      _roleCountRow('Admin', Icons.shield, Colors.indigo, 'Full system access, user management, settings', state.users.where((u) => u.role.toLowerCase() == 'admin').length, true),
                                      _roleCountRow('Manager', Icons.badge, Colors.blue, 'Property management, bookings, reports', state.users.where((u) => u.role.toLowerCase() == 'manager').length, true),
                                      _roleCountRow('Staff', Icons.person, Colors.green, 'Task updates, room status, assigned work', state.users.where((u) => u.role.toLowerCase() == 'staff').length, true),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            Icon(Icons.grid_view, size: 20, color: Colors.indigo.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              'Modules & Permission Matrix',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Permission Matrix
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    showCheckboxColumn: false,
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.grey.shade50,
                                    ),
                                    dataRowColor: WidgetStateProperty.all(
                                      Colors.white,
                                    ),
                                    border: TableBorder(
                                      horizontalInside: BorderSide(
                                        color: Colors.grey.shade100,
                                      ),
                                    ),
                                    columnSpacing: 30,
                                    columns: const [
                                      DataColumn(label: Text('Module', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Manager', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: [
                                      _matrixRow('Properties', Icons.home, 'Full Access', 'Full Access', 'View Only'),
                                      _matrixRow('Rooms', Icons.king_bed, 'Full Access', 'Full Access', 'View Only'),
                                      _matrixRow('Bookings', Icons.event_available, 'Full Access', 'Full Access', 'View Only'),
                                      _matrixRow('Tasks', Icons.task_alt, 'Full Access', 'Full Access', 'Update Assigned'),
                                      _matrixRow('Payments', Icons.payments, 'Full Access', 'Full Access', 'View Only'),
                                      _matrixRow('Reports/Finance', Icons.analytics, 'Full Access', 'Full Access', 'No Access'),
                                      _matrixRow('Users/Staff', Icons.people, 'Full Access', 'View Only', 'No Access'),
                                      _matrixRow('Feedback', Icons.feedback, 'Full Access', 'Full Access', 'No Access'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _roleCountRow(String role, IconData icon, Color color, String description, int count, bool isActive) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(role, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        DataCell(
          Text(
            description,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
        DataCell(
          count > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count staff member${count == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : Text(
                  '0 staff members',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.pause_circle,
                  size: 12,
                  color: isActive ? Colors.green.shade600 : Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _matrixRow(
    String module,
    IconData icon,
    String admin,
    String manager,
    String staff,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(module, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
        DataCell(_permissionChip(admin)),
        DataCell(_permissionChip(manager)),
        DataCell(_permissionChip(staff)),
      ],
    );
  }

  Widget _permissionChip(String text) {
    Color bg = Colors.grey.shade50;
    Color fg = Colors.grey.shade600;
    IconData? icon;

    if (text == 'Full Access') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      icon = Icons.check_circle;
    } else if (text == 'View Only') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade700;
      icon = Icons.visibility;
    } else if (text == 'Update Assigned') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade700;
      icon = Icons.edit;
    } else if (text == 'No Access') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      icon = Icons.block;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }

  List<DataCell> _userRow(User u, List<Property> properties) {
    final displayId = u.code.isNotEmpty
        ? u.code
        : (u.employeeId.isNotEmpty
            ? u.employeeId
            : 'EMP-${u.id.substring(u.id.length - 4).toUpperCase()}');
    final propName = properties
        .firstWhere(
          (p) => p.id == u.property,
          orElse: () => Property(id: '', name: 'Unassigned'),
        )
        .name;

    return [
      DataCell(
        Text(displayId, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      DataCell(
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: _roleColor(u.role).withOpacity(0.1),
                    backgroundImage: (u.profileImage.isNotEmpty) ? NetworkImage(resolveImageUrl(u.profileImage)) : null,
                    child: (u.profileImage.isEmpty)
                  ? Text(
                      u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _roleColor(u.role),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(u.name, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      DataCell(Text(u.role.toUpperCase())),
      DataCell(Text(propName)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _statusColor(u.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            u.status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _statusColor(u.status),
            ),
          ),
        ),
      ),
      DataCell(
        Text(
          u.lastLogin != null
              ? DateFormat('dd MMM, hh:mm a').format(u.lastLogin!)
              : 'Never',
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
              ),
              onPressed: () => _showUserDetailsDialog(context, u, properties),
              child: const Text('View', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
              ),
              onPressed: () => _showAddUserDialog(context, properties, user: u),
              child: const Text('Edit', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    ];
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.indigo;
      case 'manager':
        return Colors.blue;
      case 'staff':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAddUserDialog(
    BuildContext context,
    List<Property> properties, {
    User? user,
  }) async {
    final formKey = GlobalKey<FormState>();
    final isEditing = user != null;
    final isAdmin = ref.read(authProvider).user?.isAdmin ?? false;
    final canEditRole = isAdmin || !isEditing;

    final nameController = TextEditingController(text: user?.name ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    String role = user?.role.isNotEmpty == true ? user!.role : 'staff';
    String? propertyId = user?.property.isNotEmpty == true
        ? user!.property
        : (properties.isNotEmpty ? properties.first.id : null);
    final passwordController = TextEditingController();
    String status = user?.status.isNotEmpty == true ? user!.status : 'Active';

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(user == null ? Icons.person_add : Icons.edit, size: 20, color: const Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Text(
                  user == null ? 'Add New Staff Member' : 'Edit Staff - ${user.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: isEditing ? 520 : 700,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing) ...[
                        _formSectionHeader('Account Details'),
                        Row(
                          children: [
                            Expanded(
                              child: WebFormField(
                                label: 'Full Name *',
                                controller: nameController,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: WebFormField(
                                label: 'Email Address *',
                                controller: emailController,
                                validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: WebFormField(
                                label: 'Phone Number *',
                                controller: phoneController,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final cleaned = v.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                                  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(cleaned)) return 'Invalid phone number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: WebFormField(
                                label: 'Password *',
                                controller: passwordController,
                                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                              ),
                            ),
                          ],
                        ),
                        _formSectionHeader('Employment'),
                        Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DropdownButtonFormField<String>(
                                  initialValue: role,
                                  decoration: const InputDecoration(labelText: 'Role *', border: OutlineInputBorder()),
                                  items: const [
                                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                                  ],
                                  onChanged: (v) => setDialogState(() => role = v!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DropdownButtonFormField<String>(
                                  initialValue: propertyId,
                                  decoration: const InputDecoration(labelText: 'Property *', border: OutlineInputBorder()),
                                  items: properties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                                  onChanged: (v) => setDialogState(() => propertyId = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (isEditing) ...[
                        _formSectionHeader('User Info (View Only)'),
                        _readOnlyField('Name', user.name),
                        _readOnlyField('Email', user.email),
                        _readOnlyField('Phone', user.phone.isNotEmpty ? user.phone : 'N/A'),
                        if (user.employeeId.isNotEmpty) _readOnlyField('Employee ID', user.employeeId),
                        const SizedBox(height: 12),
                        _formSectionHeader('Access Control'),
                        Row(
                          children: [
                            if (canEditRole)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: DropdownButtonFormField<String>(
                                    initialValue: role,
                                    decoration: const InputDecoration(labelText: 'Role *', border: OutlineInputBorder()),
                                    items: [
                                      const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                      const DropdownMenuItem(value: 'manager', child: Text('Manager')),
                                      const DropdownMenuItem(value: 'staff', child: Text('Staff')),
                                      if (!['admin', 'manager', 'staff'].contains(role))
                                        DropdownMenuItem(value: role, child: Text('${role.toUpperCase()} (Legacy)')),
                                    ],
                                    onChanged: (v) => setDialogState(() => role = v!),
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: _readOnlyField('Role', role.toUpperCase()),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DropdownButtonFormField<String>(
                                  initialValue: propertyId,
                                  decoration: const InputDecoration(labelText: 'Property', border: OutlineInputBorder()),
                                  items: properties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                                  onChanged: (v) => setDialogState(() => propertyId = v),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (canEditRole)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'Active', child: Text('Active')),
                                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                                DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
                              ],
                              onChanged: (v) => setDialogState(() => status = v!),
                            ),
                          )
                        else
                          _readOnlyField('Status', status),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(user == null ? Icons.person_add : Icons.save, size: 16),
                label: Text(isSaving ? 'Saving...' : (user == null ? 'Create Staff' : 'Save Changes')),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final data = <String, dynamic>{};
                        if (!isEditing) {
                          data['name'] = nameController.text.trim();
                          data['email'] = emailController.text.trim();
                          data['phone'] = phoneController.text.trim();
                          data['password'] = passwordController.text.trim();
                        }
                        if (canEditRole) {
                          data['role'] = role;
                          data['status'] = status;
                        }
                        data['property'] = propertyId;

                        final success = user == null
                            ? await ref.read(adminUsersProvider.notifier).createUser(data)
                            : await ref.read(adminUsersProvider.notifier).updateUser(user.id, data);

                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(user == null ? 'Staff member created successfully' : 'Staff member updated successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          fillColor: Colors.grey.shade50,
          filled: true,
        ),
      ),
    );
  }

  Widget _formSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _showUserDetailsDialog(
    BuildContext context,
    User u,
    List<Property> properties,
  ) async {
    final propName = properties
        .firstWhere(
          (p) => p.id == u.property,
          orElse: () => Property(id: '', name: 'Unassigned'),
        )
        .name;

    // Load tasks counts
    bool isLoadingTasks = true;
    int pendingTasks = 0;
    int completedTasks = 0;
    int overdueTasks = 0;

    // Load activity logs
    bool isLoadingLogs = true;
    List<dynamic> userLogs = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDetailsState) {
          if (isLoadingTasks) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                int pending = 0;
                int completed = 0;
                int overdue = 0;

                for (final p in properties) {
                  final response = await ref
                      .read(apiClientProvider)
                      .get('/properties/${p.id}/tasks');
                  final tasks = response.data['data']['tasks'] as List?;
                  if (tasks != null) {
                    for (final t in tasks) {
                      if (t['assignedTo'] is Map &&
                              t['assignedTo']['_id'] == u.id ||
                          t['assignedTo'] == u.id) {
                        final stat = t['status']?.toString().toLowerCase();
                        if (stat == 'pending') {
                          pending++;
                        } else if (stat == 'completed') {
                          completed++;
                        } else if (stat == 'overdue') {
                          overdue++;
                        }
                      }
                    }
                  }
                }

                setDetailsState(() {
                  pendingTasks = pending;
                  completedTasks = completed;
                  overdueTasks = overdue;
                  isLoadingTasks = false;
                });
              } catch (_) {
                setDetailsState(() => isLoadingTasks = false);
              }
            });
          }

          if (isLoadingLogs) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final response = await ref
                    .read(apiClientProvider)
                    .get('/admin/audit-log');
                final logs = response.data['data']['logs'] as List?;
                if (logs != null) {
                  final filtered = logs.where((log) {
                    final logUser = log['user'];
                    if (logUser is Map) {
                      return logUser['_id'] == u.id;
                    }
                    return logUser == u.id;
                  }).toList();
                  setDetailsState(() {
                    userLogs = filtered;
                    isLoadingLogs = false;
                  });
                } else {
                  setDetailsState(() => isLoadingLogs = false);
                }
              } catch (_) {
                setDetailsState(() => isLoadingLogs = false);
              }
            });
          }

            return DefaultTabController(
            length: 3,
            child: AlertDialog(
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: _roleColor(u.role).withOpacity(0.1),
              backgroundImage: (u.profileImage.isNotEmpty) ? NetworkImage(resolveImageUrl(u.profileImage)) : null,
                    child: (u.profileImage.isEmpty)
                        ? Icon(Icons.person, size: 14, color: _roleColor(u.role))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 960,
                height: 600,
                child: Column(
                  children: [
                    // Status Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: (u.isActive ? const Color(0xFF2E7D32) : Colors.red).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: (u.isActive ? const Color(0xFF2E7D32) : Colors.red).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: u.isActive ? const Color(0xFF2E7D32) : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              u.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(u.code.isNotEmpty ? u.code : 'EMP-${u.id.substring(u.id.length > 4 ? u.id.length - 4 : 0).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey.shade400)),
                          const SizedBox(width: 8),
                          Text(u.role.toUpperCase(), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                          const Spacer(),
                          Text(propName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.person), text: 'User Profile'),
                        Tab(icon: Icon(Icons.task), text: 'Assigned Tasks'),
                        Tab(
                          icon: Icon(Icons.history),
                          text: 'Activity History',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: User Profile Details
                          SingleChildScrollView(
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _detailSection(
                                  'Personal Information',
                                  [
                                    _detailRow(
                                      'Employee ID',
                                      u.code.isNotEmpty
                                          ? u.code
                                          : (u.employeeId.isNotEmpty
                                              ? u.employeeId
                                              : 'EMP-${u.id.substring(u.id.length - 4).toUpperCase()}'),
                                    ),
                                    _detailRow('Full Name', u.name),
                                    _detailRow(
                                      'Date Of Birth',
                                      u.dateOfBirth.isNotEmpty
                                          ? u.dateOfBirth
                                          : 'N/A',
                                    ),
                                    _detailRow(
                                      'Gender',
                                      u.gender.isNotEmpty ? u.gender : 'N/A',
                                    ),
                                    _detailRow(
                                      'NIC / Passport',
                                      u.nicPassport.isNotEmpty
                                          ? u.nicPassport
                                          : 'N/A',
                                    ),
                                  ],
                                ),
                                _detailSection(
                                  'Contact Information',
                                  [
                                    _detailRow(
                                      'Phone Number',
                                      u.phone.isNotEmpty ? u.phone : 'N/A',
                                    ),
                                    _detailRow('Email', u.email),
                                    _detailRow(
                                      'Address',
                                      u.address.isNotEmpty ? u.address : 'N/A',
                                    ),
                                    _detailRow(
                                      'City',
                                      u.city.isNotEmpty ? u.city : 'N/A',
                                    ),
                                    _detailRow(
                                      'District',
                                      u.district.isNotEmpty
                                          ? u.district
                                          : 'N/A',
                                    ),
                                  ],
                                ),
                                _detailSection(
                                  'Employment Information',
                                  [
                                    _detailRow('Role', u.role.toUpperCase()),
                                    _detailRow('Assigned Property', propName),
                                    _detailRow(
                                      'Join Date',
                                      u.joinDate.isNotEmpty
                                          ? u.joinDate
                                          : 'N/A',
                                    ),
                                    _detailRow(
                                      'Employment Type',
                                      u.employmentType,
                                    ),
                                  ],
                                ),
                                _detailSection(
                                  'Emergency Contact',
                                  [
                                    _detailRow(
                                      'Contact Name',
                                      u.emergencyName.isNotEmpty
                                          ? u.emergencyName
                                          : 'N/A',
                                    ),
                                    _detailRow(
                                      'Relationship',
                                      u.emergencyRelationship.isNotEmpty
                                          ? u.emergencyRelationship
                                          : 'N/A',
                                    ),
                                    _detailRow(
                                      'Phone Number',
                                      u.emergencyPhone.isNotEmpty
                                          ? u.emergencyPhone
                                          : 'N/A',
                                    ),
                                  ],
                                ),
                                _detailSection(
                                  'Account Information',
                                  [
                                    _detailRow('Username / Email', u.email),
                                    _detailRow('Status', u.status),
                                    _detailRow(
                                      'Created Date',
                                      u.createdAt != null
                                          ? DateFormat(
                                              'dd MMM yyyy',
                                            ).format(u.createdAt!)
                                          : 'N/A',
                                    ),
                                    _detailRow(
                                      'Last Login',
                                      u.lastLogin != null
                                          ? DateFormat(
                                              'dd MMM yyyy, hh:mm a',
                                            ).format(u.lastLogin!)
                                          : 'Never',
                                    ),
                                  ],
                                ),
                                _detailSection('Documents', [
                                  _documentRow('NIC Copy', u.nicCopy),
                                  _documentRow(
                                    'Employment Agreement',
                                    u.agreement,
                                  ),
                                  _documentRow('Certificates', u.certificates),
                                ]),
                              ],
                            ),
                          ),

                          // Tab 2: Assigned Tasks
                          isLoadingTasks
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildSummaryCard(
                                            'Pending Tasks',
                                            '$pendingTasks',
                                            Icons.hourglass_empty,
                                            Colors.orange,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildSummaryCard(
                                            'Completed Tasks',
                                            '$completedTasks',
                                            Icons.check_circle_outline,
                                            Colors.green,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildSummaryCard(
                                            'Overdue Tasks',
                                            '$overdueTasks',
                                            Icons.error_outline,
                                            Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Expanded(
                                      child: Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Recent Task Overview',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Expanded(
                                                child: Center(
                                                  child: Text(
                                                    'Overview maps directly to tasks module dashboard. View tasks page to manage.',
                                                    style: TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                          // Tab 3: Activity History Timeline
                          isLoadingLogs
                              ? const Center(child: CircularProgressIndicator())
                              : userLogs.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No activity logs found for this staff member.',
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: userLogs.length,
                                  separatorBuilder: (ctx, i) =>
                                      const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final log = userLogs[i];
                                    final dt =
                                        DateTime.tryParse(
                                          log['createdAt'] ?? '',
                                        ) ??
                                        DateTime.now();
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade50,
                                        child: Icon(
                                          Icons.history,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      title: Text(
                                        log['description'] ??
                                            'Activity performed',
                                      ),
                                      subtitle: Text(
                                        'Action: ${log['action']?.toUpperCase()} - Entity: ${log['entity']}',
                                      ),
                                      trailing: Text(
                                        DateFormat(
                                          'dd MMM, hh:mm a',
                                        ).format(dt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _showAddUserDialog(context, properties, user: u);
                  },
                  child: const Text('Edit User'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    IconData icon;
    Color color;

    if (title.contains('Personal')) {
      icon = Icons.person; color = const Color(0xFF1565C0);
    } else if (title.contains('Contact')) {
      icon = Icons.contact_phone; color = const Color(0xFF2E7D32);
    } else if (title.contains('Employment')) {
      icon = Icons.work; color = const Color(0xFF6A1B9A);
    } else if (title.contains('Emergency')) {
      icon = Icons.emergency; color = const Color(0xFFE65100);
    } else if (title.contains('Account')) {
      icon = Icons.account_circle; color = const Color(0xFF00695C);
    } else if (title.contains('Document')) {
      icon = Icons.folder_open; color = const Color(0xFF455A64);
    } else {
      icon = Icons.info; color = Colors.blueGrey;
    }

    return SizedBox(
      width: 420,
      child: Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          url.isNotEmpty
              ? InkWell(
                  onTap: () {},
                  child: const Text(
                    'View Document',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const Text(
                  'Not Uploaded',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ],
      ),
    );
  }
}
