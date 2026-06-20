import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

/// ==========================================
/// TASK ITEM - Staff Task Data Model
/// ==========================================
/// Represents a task assigned to staff members (housekeeping, maintenance,
/// support, etc.). Tasks are scoped to a property and can be assigned
/// to specific staff members.
///
/// Key features:
/// - Subtasks: Break a task into smaller steps
/// - Checklists: Verification items to confirm completion
/// - Completion images: Staff can upload photos as proof of work
/// - Priority levels: low, medium, high, urgent
/// - Status tracking: open -> in-progress -> completed
/// ==========================================
class TaskItem {
  final String id;
  final String code; // Human-readable code like "TSK-0001"
  final String propertyId;
  final String title;
  final String description;
  final String type; // 'housekeeping', 'maintenance', 'support', etc.
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String status; // 'open', 'in-progress', 'completed'
  final String assignedToName; // Name of the assigned staff member
  final String roomNumber; // Associated room (if applicable)
  final DateTime? dueDate;
  final DateTime? completedAt;
  final List<Map<String, dynamic>> subtasks; // Sub-steps within the task
  final List<Map<String, dynamic>> checklist; // Verification items
  final List<String> completedImages; // Photo proof of completion

  TaskItem({
    required this.id,
    this.code = '',
    required this.propertyId,
    required this.title,
    this.description = '',
    this.type = 'housekeeping',
    this.priority = 'medium',
    this.status = 'open',
    this.assignedToName = '',
    this.roomNumber = '',
    this.dueDate,
    this.completedAt,
    this.subtasks = const [],
    this.checklist = const [],
    this.completedImages = const [],
  });

  /// ==========================================
  /// JSON PARSER - Handle Populated References
  /// ==========================================
  /// The backend populates 'assignedTo' and 'room' as nested objects.
  /// This parser safely extracts names/numbers from those objects.
  /// ==========================================
  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      propertyId: json['property'] is Map
          ? (json['property']['_id'] ?? json['property']['id'] ?? '')
          : (json['property'] ?? ''),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'housekeeping',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'open',
      // Extract name from populated user object
      assignedToName: (json['assignedTo'] is Map)
          ? (json['assignedTo']['name'] ?? '')
          : '',
      // Extract room number from populated room object
      roomNumber: (json['room'] is Map)
          ? (json['room']['roomNumber'] ?? '')
          : '',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      subtasks: List<Map<String, dynamic>>.from(json['subtasks'] ?? []),
      checklist: List<Map<String, dynamic>>.from(json['checklist'] ?? []),
      completedImages: List<String>.from(json['completedImages'] ?? []),
    );
  }
}

/// ==========================================
/// TASK STATE - State Container
/// ==========================================
class TaskState {
  final List<TaskItem> tasks;
  final bool isLoading;
  final String? error;
  final int total;

  TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  TaskState copyWith({
    List<TaskItem>? tasks,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

/// ==========================================
/// TASK PROVIDER - Task State Manager
/// ==========================================
/// Manages all task operations:
/// - Fetching tasks (per-property or user's own tasks)
/// - Creating, updating, completing tasks
/// - Toggling subtasks and checklists
/// - Clearing task data on logout
/// ==========================================
final taskProvider = NotifierProvider<TaskNotifier, TaskState>(
  TaskNotifier.new,
);

class TaskNotifier extends Notifier<TaskState> {
  @override
  TaskState build() => TaskState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// ==========================================
  /// FETCH TASKS - Load Tasks for a Property
  /// ==========================================
  /// Retrieves all tasks belonging to a specific property.
  /// Used by managers/admins to view property-level task assignments.
  /// Supports optional filtering by status and task type.
  /// ==========================================
  Future<void> fetchTasks(
    String propertyId, {
    String? status,
    String? type,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get(
        '/properties/$propertyId/tasks',
        queryParameters: {'status': ?status, 'type': ?type},
      );
      final data = response.data['data'];
      final tasks = (data['tasks'] as List)
          .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        total: data['total'] ?? tasks.length,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// ==========================================
  /// FETCH MY TASKS - Load Tasks Assigned to Current User
  /// ==========================================
  /// Retrieves tasks specifically assigned to the logged-in staff member.
  /// Used on the mobile app's task list screen.
  /// ==========================================
  Future<void> fetchMyTasks({String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get(
        '/tasks/my',
        queryParameters: {'status': ?status},
      );
      final data = response.data['data'];
      final tasks = (data['tasks'] as List)
          .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        total: data['total'] ?? tasks.length,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// ==========================================
  /// CLEAR TASKS - Reset Task State
  /// ==========================================
  /// Clears all task data from memory. Called during logout to prevent
  /// stale data from appearing for the next user.
  /// ==========================================
  void clearTasks() {
    state = TaskState();
  }

  /// ==========================================
  /// CREATE TASK - Add New Task
  /// ==========================================
  /// Creates a new task and prepends it to the task list.
  /// Returns true on success, false on failure.
  /// ==========================================
  Future<bool> createTask(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post('/tasks', data: data);
      final task = TaskItem.fromJson(response.data['data']['task']);
      state = state.copyWith(tasks: [task, ...state.tasks], isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  /// ==========================================
  /// UPDATE TASK - Modify Task Details
  /// ==========================================
  /// Updates a task's information (title, status, priority, etc.).
  /// On success, replaces the old task with the updated version.
  /// ==========================================
  Future<bool> updateTask(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/tasks/$id', data: data);
      final task = TaskItem.fromJson(response.data['data']['task']);
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == id ? task : t).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  /// ==========================================
  /// COMPLETE TASK - Mark Task as Done
  /// ==========================================
  /// Marks a task as completed with optional photo proof.
  /// Staff can upload images showing the work was done.
  /// ==========================================
  Future<bool> completeTask(String id, {List<String> completedImages = const []}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = <String, dynamic>{};
      if (completedImages.isNotEmpty) data['completedImages'] = completedImages;
      final response = await _api.patch('/tasks/$id/complete', data: data.isNotEmpty ? data : null);
      final task = TaskItem.fromJson(response.data['data']['task']);
      state = state.copyWith(
        tasks: state.tasks.map((t) => t.id == id ? task : t).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  /// ==========================================
  /// DELETE TASK - Remove Task
  /// ==========================================
  /// Deletes a task from the backend and removes it from the local list.
  /// ==========================================
  Future<bool> deleteTask(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.delete('/tasks/$id');
      state = state.copyWith(
        tasks: state.tasks.where((t) => t.id != id).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }
}
