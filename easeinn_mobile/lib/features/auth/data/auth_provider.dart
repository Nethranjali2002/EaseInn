import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../task/data/task_provider.dart';

class UserInfo {
  final String id;
  final String name;
  final String email;
  final String role;

  UserInfo({required this.id, required this.name, required this.email, required this.role});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';
  bool get isStaff => role == 'staff' || role == 'manager' || role == 'admin';
}

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final UserInfo? user;

  AuthState({this.isLoading = false, this.error, this.isAuthenticated = false, this.user});

  AuthState copyWith({bool? isLoading, String? error, bool? isAuthenticated, UserInfo? user, bool clearUser = false}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  ApiClient get _api => ref.read(apiClientProvider);
  SecureStorage get _storage => ref.read(secureStorageProvider);

  Future<bool> tryAutoLogin() async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      _api.setAuthToken(token);
      try {
        final response = await _api.get('/users/me');
        final user = UserInfo.fromJson(response.data['data']['user']);
        state = state.copyWith(isAuthenticated: true, user: user);
        return true;
      } catch (_) {
        await _storage.clearTokens();
        _api.clearAuthToken();
        return false;
      }
    }
    return false;
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post('/auth/login', data: {'email': email, 'password': password});
      final data = response.data['data'];
      await _storage.saveTokens(accessToken: data['accessToken'], refreshToken: data['refreshToken']);
      _api.setAuthToken(data['accessToken']);
      final userResponse = await _api.get('/users/me');
      final user = UserInfo.fromJson(userResponse.data['data']['user']);
      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred');
    }
  }

  Future<void> register({required String name, required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post('/auth/register', data: {'name': name, 'email': email, 'password': password});
      final data = response.data['data'];
      await _storage.saveTokens(accessToken: data['accessToken'], refreshToken: data['refreshToken']);
      _api.setAuthToken(data['accessToken']);
      final userResponse = await _api.get('/users/me');
      final user = UserInfo.fromJson(userResponse.data['data']['user']);
      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'An unexpected error occurred');
    }
  }

  Future<void> logout() async {
    try { await _api.post('/auth/logout'); } catch (_) {}
    await _storage.clearTokens();
    _api.clearAuthToken();
    try {
      ref.read(taskProvider.notifier).clearTasks();
    } catch (_) {}
    state = AuthState();
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post('/auth/forgot-password', data: {'email': email});
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> resetPassword(String token, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post('/auth/reset-password', data: {'token': token, 'password': password});
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post('/auth/change-password', data: {'currentPassword': currentPassword, 'newPassword': newPassword});
      state = state.copyWith(isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }
}
