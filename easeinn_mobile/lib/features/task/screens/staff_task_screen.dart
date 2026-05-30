import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../task/data/task_provider.dart';
import '../../auth/data/auth_provider.dart';

class StaffTaskScreen extends ConsumerStatefulWidget {
  const StaffTaskScreen({super.key});

  @override
  ConsumerState<StaffTaskScreen> createState() => _StaffTaskScreenState();
}

class _StaffTaskScreenState extends ConsumerState<StaffTaskScreen> {
  String _selectedFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskProvider.notifier).fetchMyTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('All')),
                ButtonSegment(value: 'open', label: Text('Open')),
                ButtonSegment(value: 'in-progress', label: Text('In Progress')),
                ButtonSegment(value: 'completed', label: Text('Completed')),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (v) {
                setState(() => _selectedFilter = v.first);
                ref.read(taskProvider.notifier).fetchMyTasks(
                  status: v.first.isEmpty ? null : v.first,
                );
              },
            ),
          ),
          Expanded(
            child: taskState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : taskState.error != null
                    ? Center(child: Text('Error: \${taskState.error}', style: const TextStyle(color: Colors.red)))
                    : taskState.tasks.isEmpty
                        ? const Center(child: Text('No tasks assigned'))
                        : RefreshIndicator(
                        onRefresh: () => ref.read(taskProvider.notifier).fetchMyTasks(
                          status: _selectedFilter.isEmpty ? null : _selectedFilter,
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: taskState.tasks.length,
                          itemBuilder: (ctx, i) {
                            final task = taskState.tasks[i];
                            return _TaskCard(task: task);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final TaskItem task;
  const _TaskCard({required this.task});

  Color get _statusColor {
    switch (task.status) {
      case 'completed': return Colors.green;
      case 'in-progress': return Colors.blue;
      case 'blocked': return Colors.red;
      default: return Colors.orange;
    }
  }

  Color get _priorityColor {
    switch (task.priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.amber;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: _priorityColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text('${task.title} (Assigned to: ${task.assignedToName.isNotEmpty ? task.assignedToName : "None"})', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${task.type} • ${task.roomNumber.isNotEmpty ? "Room ${task.roomNumber}" : "No room"}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(task.status, style: TextStyle(fontSize: 11, color: _statusColor)),
        ),
        children: [
          if (task.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(task.description, style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
          if (task.dueDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          if (task.subtasks.isNotEmpty) ...[
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Subtasks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            ...task.subtasks.asMap().entries.map((entry) {
              final index = entry.key;
              final subtask = entry.value;
              final completed = subtask['completed'] ?? false;
              return CheckboxListTile(
                value: completed,
                onChanged: (val) async {
                  await ref.read(taskProvider.notifier).updateTask(task.id, {});
                  // Use the API directly for subtask toggle
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.patch('/tasks/${task.id}/subtasks/$index', data: {'completed': !completed});
                    ref.read(taskProvider.notifier).fetchMyTasks();
                  } catch (_) {}
                },
                title: Text(
                  subtask['title'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    color: completed ? Colors.grey : Colors.black87,
                  ),
                ),
                dense: true,
              );
            }),
          ],
          if (task.checklist.isNotEmpty) ...[
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Checklist', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            ...task.checklist.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final checked = item['checked'] ?? false;
              return CheckboxListTile(
                value: checked,
                onChanged: (val) async {
                  try {
                    final api = ref.read(apiClientProvider);
                    await api.patch('/tasks/${task.id}/checklist/$index', data: {'checked': !checked});
                    ref.read(taskProvider.notifier).fetchMyTasks();
                  } catch (_) {}
                },
                title: Text(
                  item['item'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked ? Colors.grey : Colors.black87,
                  ),
                ),
                dense: true,
              );
            }),
          ],
          if (task.status != 'completed')
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (task.status == 'open')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final api = ref.read(apiClientProvider);
                            await api.patch('/tasks/${task.id}', data: {'status': 'in-progress'});
                            ref.read(taskProvider.notifier).fetchMyTasks();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Task started'), backgroundColor: Colors.blue),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Start'),
                      ),
                    ),
                  if (task.status == 'in-progress') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(taskProvider.notifier).completeTask(task.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Task completed!'), backgroundColor: Colors.green),
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final api = ref.read(apiClientProvider);
                            await api.patch('/tasks/${task.id}', data: {'status': 'blocked', 'notes': 'Blocked by staff'});
                            ref.read(taskProvider.notifier).fetchMyTasks();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Task marked as blocked'), backgroundColor: Colors.orange),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Block'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (task.status == 'completed')
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text('Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final api = ref.read(apiClientProvider);
                          await api.post('/upload/single');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Upload feature ready — connect camera/gallery'), backgroundColor: Colors.blue),
                            );
                          }
                        } catch (e) {}
                      },
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Upload Evidence Photo'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
