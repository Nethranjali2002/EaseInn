import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../task/data/task_provider.dart';
import '../../property/data/property_provider.dart';
import '../../property/data/room_provider.dart';
import '../widgets/web_data_table.dart';
import '../widgets/web_form_dialog.dart';
import 'web_users.dart';

class WebTasksScreen extends ConsumerStatefulWidget {
  const WebTasksScreen({super.key});

  @override
  ConsumerState<WebTasksScreen> createState() => _WebTasksScreenState();
}

class _WebTasksScreenState extends ConsumerState<WebTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await ref.read(propertyProvider.notifier).fetchProperties();
    final properties = ref.read(propertyProvider).properties;
    if (properties.isNotEmpty) {
      final pid = properties.first.id;
      await ref.read(taskProvider.notifier).fetchTasks(pid);
      await ref.read(roomProvider.notifier).fetchRooms(pid);
      await ref.read(adminUsersProvider.notifier).fetchUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tasks',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Task'),
                onPressed: () => _showTaskDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: state.isLoading && state.tasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.tasks.isEmpty
                    ? const Center(child: Text('No tasks found'))
                    : WebDataTable(
                        searchHint: 'Search tasks...',
                        columns: const [
                          DataColumn(label: Text('Title')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Priority')),
                          DataColumn(label: Text('Assigned To')),
                          DataColumn(label: Text('Room')),
                          DataColumn(label: Text('Due Date')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: state.tasks.map((t) => _taskRow(t)).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  List<DataCell> _taskRow(TaskItem t) {
    return [
      DataCell(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title, style: const TextStyle(fontWeight: FontWeight.w500)),
            if (t.description.isNotEmpty)
              Text(
                t.description,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _typeColor(t.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            t.type.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _typeColor(t.type),
            ),
          ),
        ),
      ),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _priorityColor(t.priority).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            t.priority.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _priorityColor(t.priority),
            ),
          ),
        ),
      ),
      DataCell(Text(t.assignedToName.isNotEmpty ? t.assignedToName : '-')),
      DataCell(Text(t.roomNumber.isNotEmpty ? t.roomNumber : '-')),
      DataCell(
        t.dueDate != null
            ? Text(DateFormat('MMM dd, yyyy').format(t.dueDate!))
            : const Text('-', style: TextStyle(color: Colors.grey)),
      ),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _taskStatusColor(t.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            t.status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _taskStatusColor(t.status),
            ),
          ),
        ),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t.status != 'completed')
              IconButton(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                tooltip: 'Complete',
                color: const Color(0xFF2E7D32),
                onPressed: () => _completeTask(t),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              color: const Color(0xFF1565C0),
              onPressed: () => _showTaskDialog(context, taskToEdit: t),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              color: const Color(0xFFC62828),
              onPressed: () => _deleteTask(t),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _deleteTask(TaskItem task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(taskProvider.notifier).deleteTask(task.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Task deleted' : 'Failed to delete task'),
          backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
        ),
      );
    }
  }

  Future<void> _completeTask(TaskItem task) async {
    final success =
        await ref.read(taskProvider.notifier).completeTask(task.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Task completed' : 'Failed to complete task'),
          backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
        ),
      );
    }
  }

  Future<void> _showTaskDialog(BuildContext context, {TaskItem? taskToEdit}) async {
    final properties = ref.read(propertyProvider).properties;
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No properties available. Create a property first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Ensure users are loaded before showing the dialog
    if (ref.read(adminUsersProvider).users.isEmpty) {
      await ref.read(adminUsersProvider.notifier).fetchUsers();
    }
    
    final rooms = ref.read(roomProvider).rooms;

    final titleController = TextEditingController(text: taskToEdit?.title ?? '');
    final descController = TextEditingController(text: taskToEdit?.description ?? '');
    final formKey = GlobalKey<FormState>();
    String taskType = taskToEdit?.type ?? 'housekeeping';
    String priority = taskToEdit?.priority ?? 'medium';
    
    // Find the room ID by looking at rooms that match the room number
    String? selectedRoomId;
    if (taskToEdit != null && taskToEdit.roomNumber.isNotEmpty) {
      try {
        selectedRoomId = rooms.firstWhere((r) => r.roomNumber == taskToEdit.roomNumber).id;
      } catch (_) {}
    }
    
    // Find the assigned user ID
    String? selectedAssigneeId;
    if (taskToEdit != null && taskToEdit.assignedToName.isNotEmpty) {
      final staffUsers = ref.read(adminUsersProvider).users.where((u) => u.role == 'staff' || u.role == 'manager').toList();
      try {
        selectedAssigneeId = staffUsers.firstWhere((u) => u.name == taskToEdit.assignedToName).id;
      } catch (_) {}
    }
    
    DateTime? dueDate = taskToEdit?.dueDate;
    bool isSaving = false;

    final staffUsers = ref.read(adminUsersProvider).users.where((u) => u.role == 'staff' || u.role == 'manager').toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(taskToEdit == null ? 'New Task' : 'Edit Task'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WebFormField(
                        label: 'Title',
                        controller: titleController,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      WebFormField(
                        label: 'Description',
                        controller: descController,
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: taskType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'housekeeping',
                                child: Text('Housekeeping')),
                            DropdownMenuItem(
                                value: 'maintenance',
                                child: Text('Maintenance')),
                            DropdownMenuItem(
                                value: 'room_service',
                                child: Text('Room Service')),
                            DropdownMenuItem(
                                value: 'concierge',
                                child: Text('Concierge')),
                            DropdownMenuItem(
                                value: 'inspection',
                                child: Text('Inspection')),
                            DropdownMenuItem(
                                value: 'other', child: Text('Other')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => taskType = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'low', child: Text('Low')),
                            DropdownMenuItem(
                                value: 'medium', child: Text('Medium')),
                            DropdownMenuItem(
                                value: 'high', child: Text('High')),
                            DropdownMenuItem(
                                value: 'urgent', child: Text('Urgent')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => priority = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: selectedAssigneeId,
                          isExpanded: true,
                          items: staffUsers
                              .map((u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text('${u.name} (${u.role})'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setDialogState(() => selectedAssigneeId = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Assign To',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: selectedRoomId,
                          isExpanded: true,
                          items: rooms
                              .map((r) => DropdownMenuItem(
                                    value: r.id,
                                    child: Text(
                                        '${r.roomNumber} - ${r.roomType}'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setDialogState(() => selectedRoomId = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Room (optional)',
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
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
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
                              labelText: 'Due Date (optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              dueDate != null
                                  ? DateFormat('MMM dd, yyyy').format(dueDate!)
                                  : 'Select date',
                              style: TextStyle(
                                color: dueDate != null
                                    ? null
                                    : Colors.grey.shade600,
                              ),
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
                        final data = <String, dynamic>{
                          'property': properties.first.id,
                          'title': titleController.text.trim(),
                          'description': descController.text.trim(),
                          'type': taskType,
                          'priority': priority,
                        };
                        if (selectedAssigneeId != null) {
                          data['assignedTo'] = selectedAssigneeId;
                        }
                        if (selectedRoomId != null) {
                          data['room'] = selectedRoomId;
                        }
                        if (dueDate != null) {
                          data['dueDate'] = dueDate!.toIso8601String();
                        }
                        final success = taskToEdit == null 
                            ? await ref.read(taskProvider.notifier).createTask(data)
                            : await ref.read(taskProvider.notifier).updateTask(taskToEdit.id, data);
                            
                        if (ctx.mounted) Navigator.pop(ctx, success);
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
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
          content: Text(taskToEdit == null ? 'Task created' : 'Task updated'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadData();
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'housekeeping':
        return const Color(0xFF2E7D32);
      case 'maintenance':
        return const Color(0xFFE65100);
      case 'room_service':
        return const Color(0xFF1565C0);
      case 'concierge':
        return const Color(0xFF6A1B9A);
      case 'inspection':
        return const Color(0xFFC62828);
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFC62828);
      case 'high':
        return const Color(0xFFE65100);
      case 'medium':
        return const Color(0xFFF9A825);
      case 'low':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  Color _taskStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'in_progress':
        return const Color(0xFF1565C0);
      case 'open':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
