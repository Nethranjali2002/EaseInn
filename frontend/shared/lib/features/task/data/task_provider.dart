import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

class TaskItem {
  final String id;
  final String code;
  final String propertyId;
  final String title;
  final String description;
  final String type;
  final String priority;
  final String status;
  final String assignedToName;
  final String roomNumber;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final List<Map<String, dynamic>> subtasks;
  final List<Map<String, dynamic>> checklist;
  final List<String> completedImages;

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
      assignedToName: (json['assignedTo'] is Map)
          ? (json['assignedTo']['name'] ?? '')
          : '',
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

final taskProvider = NotifierProvider<TaskNotifier, TaskState>(
  TaskNotifier.new,
);

class TaskNotifier extends Notifier<TaskState> {
  @override
  TaskState build() => TaskState();

  ApiClient get _api => ref.read(apiClientProvider);

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

  void clearTasks() {
    state = TaskState();
  }

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
