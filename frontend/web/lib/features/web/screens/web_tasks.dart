import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import '../widgets/web_data_table.dart';
import '../widgets/web_form_dialog.dart';
import 'web_users.dart';

class WebTasksScreen extends ConsumerStatefulWidget {
  const WebTasksScreen({super.key});

  @override
  ConsumerState<WebTasksScreen> createState() => _WebTasksScreenState();
}

class _WebTasksScreenState extends ConsumerState<WebTasksScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedPropertyId = 'All';
  String _selectedTaskType = 'All';
  String _selectedStatus = 'All';
  String _selectedPriority = 'All';
  String _selectedStaffId = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = ref.read(authProvider);
    final isManager =
        auth.user?.role == 'admin' || auth.user?.role == 'manager';

    await ref.read(propertyProvider.notifier).fetchProperties();
    await ref.read(adminUsersProvider.notifier).fetchUsers();

    final properties = ref.read(propertyProvider).properties;
    if (properties.isNotEmpty) {
      // Pre-load rooms for first property
      await ref.read(roomProvider.notifier).fetchRooms(properties.first.id);
    }

    if (isManager) {
      await _fetchTasksForProperty(_selectedPropertyId);
    } else {
      await ref.read(taskProvider.notifier).fetchMyTasks();
    }
  }

  Future<void> _fetchTasksForProperty(String pid) async {
    final properties = ref.read(propertyProvider).properties;
    if (pid == 'All') {
      ref.read(taskProvider.notifier).state = TaskState(
        isLoading: true,
        tasks: [],
      );
      try {
        final List<TaskItem> allTasks = [];
        for (final p in properties) {
          final response = await ref
              .read(apiClientProvider)
              .get('/properties/${p.id}/tasks');
          final data = response.data['data'];
          final tasks = (data['tasks'] as List)
              .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
              .toList();
          allTasks.addAll(tasks);
        }
        ref.read(taskProvider.notifier).state = TaskState(
          tasks: allTasks,
          isLoading: false,
          total: allTasks.length,
        );
      } catch (e) {
        ref.read(taskProvider.notifier).state = TaskState(
          isLoading: false,
          error: e.toString(),
        );
      }
    } else {
      await ref.read(taskProvider.notifier).fetchTasks(pid);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedTaskType = 'All';
      _selectedStatus = 'All';
      _selectedPriority = 'All';
      _selectedStaffId = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final properties = ref.watch(propertyProvider).properties;
    final staffUsers = ref
        .watch(adminUsersProvider)
        .users
        .where(
          (u) => u.role == 'staff' || u.role == 'manager' || u.role == 'admin',
        )
        .toList();
    final auth = ref.watch(authProvider);
    final isManager =
        auth.user?.role == 'admin' || auth.user?.role == 'manager';

    // Local filtering
    final filteredTasks = state.tasks.where((t) {
      final isOverdue =
          t.dueDate != null &&
          t.dueDate!.isBefore(DateTime.now()) &&
          t.status != 'completed';

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            t.id.toLowerCase().contains(q) ||
            t.title.toLowerCase().contains(q) ||
            t.assignedToName.toLowerCase().contains(q) ||
            t.roomNumber.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedTaskType != 'All') {
        if (_mapTypeToLabel(t.type).toLowerCase() !=
            _selectedTaskType.toLowerCase())
          return false;
      }
      if (_selectedStatus != 'All') {
        if (_selectedStatus == 'Overdue') {
          if (!isOverdue) return false;
        } else {
          if (_mapStatusToLabel(t.status).toLowerCase() !=
              _selectedStatus.toLowerCase())
            return false;
        }
      }
      if (_selectedPriority != 'All') {
        if (t.priority.toLowerCase() != _selectedPriority.toLowerCase())
          return false;
      }
      if (_selectedStaffId != 'All') {
        final staffName = staffUsers
            .firstWhere(
              (u) => u.id == _selectedStaffId,
              orElse: () => staffUsers.first,
            )
            .name;
        if (t.assignedToName.toLowerCase() != staffName.toLowerCase())
          return false;
      }
      return true;
    }).toList();

    // Summary Card counts
    final totalCount = state.tasks.length;
    final pendingCount = state.tasks.where((t) => t.status == 'open').length;
    final inProgressCount = state.tasks
        .where((t) => t.status == 'in-progress')
        .length;
    final completedCount = state.tasks
        .where((t) => t.status == 'completed')
        .length;
    final overdueCount = state.tasks
        .where(
          (t) =>
              t.dueDate != null &&
              t.dueDate!.isBefore(DateTime.now()) &&
              t.status != 'completed',
        )
        .length;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isManager ? 'Task Management' : 'My Tasks',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (isManager)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Task'),
                    onPressed: () => _showTaskDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards (Manager View only)
            if (isManager) ...[
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
                          'Total Tasks',
                          '$totalCount',
                          Icons.assignment,
                          const Color(0xFF2563EB),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildSummaryCard(
                          'Pending',
                          '$pendingCount',
                          Icons.hourglass_empty,
                          const Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildSummaryCard(
                          'In Progress',
                          '$inProgressCount',
                          Icons.pending_actions,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildSummaryCard(
                          'Completed',
                          '$completedCount',
                          Icons.task_alt,
                          const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _buildSummaryCard(
                          'Overdue',
                          '$overdueCount',
                          Icons.warning_amber_rounded,
                          const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // Filters Card
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
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
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
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: searchWidth,
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search Task ID, Title, Staff, Room...',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            if (isManager) ...[
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
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => _selectedPropertyId = v);
                                      _fetchTasksForProperty(v);
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(
                              width: itemWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedTaskType,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Types'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Cleaning',
                                    child: Text('Cleaning'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Maintenance',
                                    child: Text('Maintenance'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Guest Request',
                                    child: Text('Guest Request'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Laundry',
                                    child: Text('Laundry'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Transport',
                                    child: Text('Transport'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Inventory',
                                    child: Text('Inventory'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedTaskType = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
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
                                    value: 'Pending',
                                    child: Text('Pending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'In Progress',
                                    child: Text('In Progress'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Completed',
                                    child: Text('Completed'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Cancelled',
                                    child: Text('Cancelled'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Overdue',
                                    child: Text('Overdue'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedStatus = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
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
                                initialValue: _selectedPriority,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Priorities'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'low',
                                    child: Text('Low'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'medium',
                                    child: Text('Medium'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'high',
                                    child: Text('High'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'urgent',
                                    child: Text('Urgent'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedPriority = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            if (isManager) ...[
                              SizedBox(
                                width: itemWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedStaffId,
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'All',
                                      child: Text('All Staff'),
                                    ),
                                    ...staffUsers.map(
                                      (u) => DropdownMenuItem(
                                        value: u.id,
                                        child: Text(u.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedStaffId = v!),
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
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

            // Tasks Data Table
            state.isLoading && state.tasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredTasks.isEmpty
                ? const Center(child: Text('No tasks matching filters.'))
                : WebDataTable(
                    showSearch: false,
                    searchHint: 'Filtered Tasks',
                    columns: isManager
                        ? [
                            const DataColumn(label: Text('Task ID')),
                            const DataColumn(label: Text('Task')),
                            const DataColumn(label: Text('Property')),
                            const DataColumn(label: Text('Room')),
                            const DataColumn(label: Text('Assigned To')),
                            const DataColumn(label: Text('Priority')),
                            const DataColumn(label: Text('Status')),
                            const DataColumn(label: Text('Due Date')),
                            const DataColumn(label: Text('Actions')),
                          ]
                        : [
                            const DataColumn(label: Text('Task')),
                            const DataColumn(label: Text('Room')),
                            const DataColumn(label: Text('Priority')),
                            const DataColumn(label: Text('Status')),
                            const DataColumn(label: Text('Actions')),
                          ],
                    rows: filteredTasks
                        .map((t) => _taskRow(t, isManager, properties))
                        .toList(),
                  ),
          ],
        ),
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

  List<DataCell> _taskRow(
    TaskItem t,
    bool isManager,
    List<Property> properties,
  ) {
    final displayId = t.code.isNotEmpty
        ? t.code
        : 'TSK-${t.id.length > 4 ? t.id.substring(t.id.length - 4).toUpperCase() : t.id.toUpperCase()}';
    final propertyName = properties
        .firstWhere(
          (p) => p.id == t.propertyId,
          orElse: () => Property(id: '', name: 'Resort'),
        )
        .name;

    final isOverdue =
        t.dueDate != null &&
        t.dueDate!.isBefore(DateTime.now()) &&
        t.status != 'completed';

    if (isManager) {
      return [
        DataCell(
          Text(displayId, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        DataCell(Text(t.title)),
        DataCell(Text(propertyName)),
        DataCell(Text(t.roomNumber.isNotEmpty ? t.roomNumber : '-')),
        DataCell(Text(t.assignedToName.isNotEmpty ? t.assignedToName : '-')),
        DataCell(_buildPriorityBadge(t.priority)),
        DataCell(_buildStatusBadge(t.status, isOverdue)),
        DataCell(
          t.dueDate != null
              ? Text(DateFormat('dd MMM yyyy').format(t.dueDate!))
              : const Text('-', style: TextStyle(color: Colors.grey)),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                tooltip: 'View Detail',
                onPressed: () =>
                    _showTaskDetailsDialog(context, t, propertyName),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                onPressed: () => _showTaskDialog(context, taskToEdit: t),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                tooltip: 'Delete',
                onPressed: () => _deleteTask(t),
              ),
            ],
          ),
        ),
      ];
    } else {
      // Staff View Table Cells
      return [
        DataCell(
          Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        DataCell(Text(t.roomNumber.isNotEmpty ? t.roomNumber : '-')),
        DataCell(_buildPriorityBadge(t.priority)),
        DataCell(_buildStatusBadge(t.status, isOverdue)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                tooltip: 'View Detail',
                onPressed: () =>
                    _showTaskDetailsDialog(context, t, propertyName),
              ),
              if (t.status == 'open')
                ElevatedButton(
                  onPressed: () => _updateTaskStatus(t.id, 'in-progress'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              if (t.status == 'in-progress')
                ElevatedButton(
                  onPressed: () => _completeTask(t),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ];
    }
  }

  Widget _buildPriorityBadge(String priority) {
    Color badgeColor = Colors.grey;
    if (priority == 'low') badgeColor = Colors.green;
    if (priority == 'medium') badgeColor = Colors.orange;
    if (priority == 'high') badgeColor = Colors.deepOrange;
    if (priority == 'urgent') badgeColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isOverdue) {
    if (isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'OVERDUE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
    }

    Color statusColor = Colors.grey;
    String label = status;
    if (status == 'open') {
      statusColor = Colors.grey.shade600;
      label = 'PENDING';
    } else if (status == 'in-progress') {
      statusColor = Colors.blue;
      label = 'IN PROGRESS';
    } else if (status == 'completed') {
      statusColor = Colors.green;
      label = 'COMPLETED';
    } else if (status == 'blocked') {
      statusColor = Colors.purple;
      label = 'BLOCKED';
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
      label = 'CANCELLED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    final success = await ref.read(taskProvider.notifier).updateTask(taskId, {
      'status': newStatus,
    });
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task status updated'),
          backgroundColor: Colors.blue,
        ),
      );
      _loadData();
    }
  }

  Future<void> _completeTask(TaskItem task) async {
    final List<String> completedImages = [];
    bool isUploading = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                const Text('Complete Task'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to mark "${task.title}" as completed?',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.camera_alt, size: 16, color: Color(0xFF1565C0)),
                      const SizedBox(width: 8),
                      Text('Upload Proof Images', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (completedImages.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: completedImages.asMap().entries.map((entry) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(resolveImageUrl(entry.value), width: 80, height: 80, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setDialogState(() => completedImages.removeAt(entry.key)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isUploading ? null : () async {
                        final input = html.FileUploadInputElement()..accept = 'image/*';
                        input.click();
                        input.onChange.listen((_) async {
                          if (input.files == null || input.files!.isEmpty) return;
                          final file = input.files!.first;
                          final reader = html.FileReader();
                          reader.readAsArrayBuffer(file);
                          await reader.onLoad.first;
                          final result = reader.result;
                          final Uint8List bytes;
                          if (result is Uint8List) {
                            bytes = result;
                          } else if (result is ByteBuffer) {
                            bytes = result.asUint8List();
                          } else {
                            bytes = (result as dynamic).asUint8List() as Uint8List;
                          }
                          setDialogState(() => isUploading = true);
                          try {
                            final api = ref.read(apiClientProvider);
                            final formData = FormData.fromMap({
                              'file': MultipartFile.fromBytes(bytes, filename: file.name),
                            });
                            final response = await api.dio.post('/upload/single', data: formData);
                            final rawUrl = response.data['data']['url'] as String;
                            final fullUrl = resolveImageUrl(rawUrl);
                            setDialogState(() => completedImages.add(fullUrl));
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setDialogState(() => isUploading = false);
                          }
                        });
                      },
                      icon: isUploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_photo_alternate, size: 18),
                      label: Text(isUploading ? 'Uploading...' : 'Add Image'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );

    if (result != true) return;

    final success = await ref.read(taskProvider.notifier).completeTask(task.id, completedImages: completedImages);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Task completed successfully!' : 'Failed to complete task'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      _loadData();
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isConfirmed = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete "${task.title}"? This action cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isConfirmed,
                        onChanged: (val) {
                          setDialogState(() {
                            isConfirmed = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I confirm I want to permanently delete this task.',
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
                    backgroundColor: isConfirmed
                        ? const Color(0xFFC62828)
                        : Colors.grey,
                  ),
                  onPressed: isConfirmed
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      final success = await ref.read(taskProvider.notifier).deleteTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Task deleted' : 'Failed to delete task'),
            backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
          ),
        );
        _loadData();
      }
    }
  }

  void _showTaskDetailsDialog(
    BuildContext context,
    TaskItem t,
    String propertyName,
  ) {
    final displayId = t.code.isNotEmpty
        ? t.code
        : 'TSK-${t.id.length > 4 ? t.id.substring(t.id.length - 4).toUpperCase() : t.id.toUpperCase()}';
    final isOverdue =
        t.dueDate != null &&
        t.dueDate!.isBefore(DateTime.now()) &&
        t.status != 'completed';

    final Color statusColor;
    final String statusLabel;
    switch (t.status) {
      case 'completed':
        statusColor = const Color(0xFF2E7D32);
        statusLabel = 'COMPLETED';
        break;
      case 'in-progress':
        statusColor = const Color(0xFF1565C0);
        statusLabel = 'IN PROGRESS';
        break;
      case 'pending':
        statusColor = isOverdue ? Colors.red : const Color(0xFFE65100);
        statusLabel = isOverdue ? 'OVERDUE' : 'PENDING';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = t.status.toUpperCase();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.task_alt, size: 20, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Task Details',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Text(displayId, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 960,
          height: MediaQuery.of(context).size.height * 0.75,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.priority == 'high' ? Colors.red.shade50 : t.priority == 'medium' ? Colors.orange.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${t.priority.toUpperCase()} PRIORITY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: t.priority == 'high' ? Colors.red.shade700 : t.priority == 'medium' ? Colors.orange.shade700 : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _detailBlock('Task Information', Icons.assignment, const Color(0xFF1565C0), [
                    _detailRow('Task ID', displayId),
                    _detailRow('Title', t.title),
                    _detailRow('Type', _mapTypeToLabel(t.type)),
                    _detailRow('Created At', t.dueDate != null ? DateFormat('dd MMM yyyy').format(t.dueDate!) : '-'),
                  ]),
                  _detailBlock('Location', Icons.location_on, const Color(0xFF6A1B9A), [
                    _detailRow('Property', propertyName),
                    _detailRow('Room', t.roomNumber.isNotEmpty ? t.roomNumber : 'Not room-related'),
                  ]),
                  _detailBlock('Assignment', Icons.person, const Color(0xFF00695C), [
                    _detailRow('Assigned To', t.assignedToName.isNotEmpty ? t.assignedToName : 'Unassigned'),
                    _detailRow('Priority', t.priority.toUpperCase()),
                    _detailRow('Due Date', t.dueDate != null ? DateFormat('dd MMM yyyy').format(t.dueDate!) : '-'),
                    if (isOverdue)
                      Row(
                        children: [
                          Icon(Icons.warning_amber, size: 14, color: Colors.red.shade600),
                          const SizedBox(width: 6),
                          Text('Overdue by ${DateTime.now().difference(t.dueDate!).inDays} days', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ]),
                  _detailBlock('Description', Icons.notes, const Color(0xFF795548), [
                    Text(
                      t.description.isNotEmpty ? t.description : 'No description provided.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ]),
                  _detailBlock('Timeline', Icons.timeline, const Color(0xFF4527A0), [
                    _timelineItem('Task Created', t.dueDate != null ? DateFormat('dd MMM yyyy').format(t.dueDate!) : '-', true, const Color(0xFF2E7D32)),
                    if (t.assignedToName.isNotEmpty)
                      _timelineItem('Assigned to ${t.assignedToName}', '-', t.assignedToName.isNotEmpty, const Color(0xFF1565C0)),
                    if (t.status == 'in-progress' || t.status == 'completed')
                      _timelineItem('In Progress', '-', t.status == 'in-progress' || t.status == 'completed', const Color(0xFFE65100)),
                    if (t.status == 'completed')
                      _timelineItem('Completed', t.completedAt != null ? DateFormat('dd MMM yyyy HH:mm').format(t.completedAt!) : '-', true, const Color(0xFF2E7D32)),
                    if (t.status != 'completed')
                      _timelineItem('Completed', '-', false, Colors.grey),
                  ]),
                  if (t.completedImages.isNotEmpty)
                    _detailBlock('Completion Proof', Icons.photo_library, const Color(0xFF2E7D32), [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: t.completedImages.map((img) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(resolveImageUrl(img), width: 100, height: 100, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(width: 100, height: 100, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                          ),
                        )).toList(),
                      ),
                    ]),
                ],
              ),
            ],
          ),
        ),
      ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(String title, String time, bool isActive, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isActive ? color : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                color: isActive ? color : Colors.grey.shade500,
              ),
            ),
          ),
          if (time.isNotEmpty && time != '-')
            Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBlock(String title, IconData icon, Color color, List<Widget> children) {
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
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTaskDialog(
    BuildContext context, {
    TaskItem? taskToEdit,
  }) async {
    final properties = ref.read(propertyProvider).properties;
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a property first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final staffUsers = ref
        .read(adminUsersProvider)
        .users
        .where(
          (u) => u.role == 'staff' || u.role == 'manager' || u.role == 'admin',
        )
        .toList();
    final rooms = ref.read(roomProvider).rooms;

    String selectedPropertyId = taskToEdit?.propertyId ?? properties.first.id;
    final titleController = TextEditingController(
      text: taskToEdit?.title ?? '',
    );
    final descController = TextEditingController(
      text: taskToEdit?.description ?? '',
    );
    String taskType = taskToEdit?.type ?? 'housekeeping';
    String priority = taskToEdit?.priority ?? 'medium';

    String? selectedAssigneeId;
    if (taskToEdit != null && taskToEdit.assignedToName.isNotEmpty) {
      try {
        selectedAssigneeId = staffUsers
            .firstWhere((u) => u.name == taskToEdit.assignedToName)
            .id;
      } catch (_) {}
    } else if (staffUsers.isNotEmpty) {
      selectedAssigneeId = staffUsers.first.id;
    }

    String? selectedRoomId;
    if (taskToEdit != null && taskToEdit.roomNumber.isNotEmpty) {
      try {
        selectedRoomId = rooms
            .firstWhere((r) => r.roomNumber == taskToEdit.roomNumber)
            .id;
      } catch (_) {}
    }

    DateTime? dueDate =
        taskToEdit?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    bool isSaving = false;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filteredRoomsForSelectedProperty = rooms
              .where((r) => r.propertyId == selectedPropertyId)
              .toList();

          return AlertDialog(
            title: Text(taskToEdit == null ? 'Create Task' : 'Edit Task'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PROPERTY ASSIGNMENT (FIRST FIELD, MANDATORY)
                      const Text(
                        'Property Assignment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPropertyId,
                        items: properties
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: taskToEdit != null
                            ? null
                            : (v) {
                                if (v != null) {
                                  setDialogState(() {
                                    selectedPropertyId = v;
                                    selectedRoomId =
                                        null; // Reset room when property changes
                                  });
                                }
                              },
                        decoration: const InputDecoration(
                          labelText: 'Property *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // BASIC INFORMATION
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      WebFormField(
                        label: 'Task Title *',
                        controller: titleController,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: _mapTypeToLabel(taskType),
                          items: const [
                            DropdownMenuItem(
                              value: 'Cleaning',
                              child: Text('Cleaning'),
                            ),
                            DropdownMenuItem(
                              value: 'Maintenance',
                              child: Text('Maintenance'),
                            ),
                            DropdownMenuItem(
                              value: 'Guest Request',
                              child: Text('Guest Request'),
                            ),
                            DropdownMenuItem(
                              value: 'Laundry',
                              child: Text('Laundry'),
                            ),
                            DropdownMenuItem(
                              value: 'Transport',
                              child: Text('Transport'),
                            ),
                            DropdownMenuItem(
                              value: 'Inventory',
                              child: Text('Inventory'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(
                                () => taskType = _mapLabelToType(v),
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Task Type *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      WebFormField(
                        label: 'Description',
                        controller: descController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // ROOM & ASSIGNMENT
                      const Text(
                        'Room & Assignment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedRoomId,
                          hint: const Text('None (General Task)'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('None (General Task)'),
                            ),
                            ...filteredRoomsForSelectedProperty.map(
                              (r) => DropdownMenuItem(
                                value: r.id,
                                child: Text(
                                  'Room ${r.roomNumber} (${r.roomType.toUpperCase()})',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedRoomId = v),
                          decoration: const InputDecoration(
                            labelText: 'Related Room (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedAssigneeId,
                          isExpanded: true,
                          items: staffUsers
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(u.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedAssigneeId = v),
                          decoration: const InputDecoration(
                            labelText: 'Assign Staff *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          initialValue: priority,
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('High'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('Urgent'),
                            ),
                          ],
                          onChanged: (v) => setDialogState(() => priority = v!),
                          decoration: const InputDecoration(
                            labelText: 'Priority *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => dueDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Due Date *',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              dueDate != null
                                  ? DateFormat('dd MMM yyyy').format(dueDate!)
                                  : 'Select Date',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        final data = {
                          'property': selectedPropertyId,
                          'title': titleController.text.trim(),
                          'description': descController.text.trim(),
                          'type': taskType,
                          'priority': priority,
                          'assignedTo': selectedAssigneeId,
                          'room': ?selectedRoomId,
                          if (dueDate != null)
                            'dueDate': dueDate!.toIso8601String(),
                        };
                        bool success;
                        if (taskToEdit != null) {
                          success = await ref
                              .read(taskProvider.notifier)
                              .updateTask(taskToEdit.id, data);
                        } else {
                          success = await ref
                              .read(taskProvider.notifier)
                              .createTask(data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx, success);
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(taskToEdit == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            taskToEdit == null
                ? 'Task created successfully'
                : 'Task updated successfully',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadData();
    }
  }

  String _mapTypeToLabel(String type) {
    switch (type) {
      case 'housekeeping':
        return 'Cleaning';
      case 'maintenance':
        return 'Maintenance';
      case 'guest_service':
      case 'room_service':
      case 'concierge':
        return 'Guest Request';
      case 'inspection':
        return 'Laundry';
      case 'other':
      default:
        return 'Transport';
    }
  }

  String _mapLabelToType(String label) {
    switch (label) {
      case 'Cleaning':
        return 'housekeeping';
      case 'Maintenance':
        return 'maintenance';
      case 'Guest Request':
        return 'guest_service';
      case 'Laundry':
        return 'inspection';
      case 'Transport':
        return 'other';
      case 'Inventory':
        return 'other';
      default:
        return 'other';
    }
  }

  String _mapStatusToLabel(String status) {
    switch (status) {
      case 'open':
        return 'Pending';
      case 'in-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}
