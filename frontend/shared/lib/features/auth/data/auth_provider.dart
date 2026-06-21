import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../../task/data/task_provider.dart';

/// ==========================================
/// USER INFO - User Data Model
/// ==========================================
/// Represents a logged-in user's profile information.
/// This model is used across the app to display user details,
/// check permissions (admin/manager/staff), and manage profiles.
///
/// The factory constructor [fromJson] handles parsing the JSON response
/// from the backend's /users/me endpoint.
/// ==========================================
class UserInfo {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin', 'manager', or 'staff'

  // Optional profile fields
  final String? employeeId;
  final String? dateOfBirth;
  final String? gender;
  final String? nicPassport;
  final String? phone;
  final String? address;
  final String? joinDate;
  final String? employmentType;
  final String? lastLogin;
  final String? status;
  final String profileImage;

  UserInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.employeeId,
    this.dateOfBirth,
    this.gender,
    this.nicPassport,
    this.phone,
    this.address,
    this.joinDate,
    this.employmentType,
    this.lastLogin,
    this.status,
    this.profileImage = '',
  });

  /// ==========================================
  /// JSON PARSER - Convert Backend Response to Dart Object
  /// ==========================================
  /// Handles the conversion from the backend's JSON response to a UserInfo object.
  /// Uses null-safe defaults so missing fields don't cause crashes.
  /// ==========================================
  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      employeeId: json['employeeId']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      gender: json['gender']?.toString(),
      nicPassport: json['nicPassport']?.toString() ?? json['nicPassportPassport']?.toString() ?? json['nicPassport']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      joinDate: json['joinDate']?.toString(),
      employmentType: json['employmentType']?.toString(),
      lastLogin: json['lastLogin']?.toString(),
      status: json['status']?.toString(),
      profileImage: json['profileImage'] ?? '',
    );
  }

  // ==========================================
  // ROLE-BASED PERMISSION CHECKS
  // ==========================================
  // These getters simplify permission checks throughout the app.
  // Example: if (user.isAdmin) { showAdminPanel(); }

  /// True only for admin users - has access to everything
  bool get isAdmin => role == 'admin';

  /// True for managers AND admins - can manage properties, bookings, tasks
  bool get isManager => role == 'manager' || role == 'admin';

  /// True for staff, managers, AND admins - can view and update tasks
  bool get isStaff => role == 'staff' || role == 'manager' || role == 'admin';
}

/// ==========================================
/// AUTH STATE - Authentication State Container
/// ==========================================
/// Holds the current authentication status and user data.
/// This is the "source of truth" for whether the user is logged in.
///
/// Fields:
/// - isLoading: True during login/register API calls (shows loading spinners)
/// - error: Error message to display (null when no error)
/// - isAuthenticated: True when a valid token and user data exist
/// - user: The logged-in user's info (null when not authenticated)
/// ==========================================
class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final UserInfo? user;

  AuthState({this.isLoading = false, this.error, this.isAuthenticated = false, this.user});

  /// Creates a copy of this state with optional field updates.
  /// Used to update individual fields without losing the others.
  /// The clearUser flag allows explicitly setting user to null.
  AuthState copyWith({bool? isLoading, String? error, bool? isAuthenticated, UserInfo? user, bool clearUser = false}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error, // Note: error is nullable, passing null clears it
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

// ==========================================
// RIVERPOD PROVIDERS - Dependency Injection
// ==========================================
// These providers make SecureStorage and ApiClient available to any widget
// or notifier in the app without manual dependency passing.

/// Provides a single SecureStorage instance for token persistence
final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

/// Provides a single ApiClient instance for all API communication
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// The main authentication provider - manages login state, user data, and auth operations
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// ==========================================
/// AUTH NOTIFIER - Authentication State Manager
/// ==========================================
/// Manages all authentication-related operations:
/// - Auto-login (check for existing token on app start)
/// - Login with email/password
/// - Register new account
/// - Logout (clear tokens and user data)
/// - Refresh user data
/// - Forgot/reset password
///
/// Uses Riverpod's Notifier pattern for clean state management.
/// All API errors are caught and stored in state for UI display.
/// ==========================================
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  // Convenience getters to access dependencies from the provider container
  ApiClient get _api => ref.read(apiClientProvider);
  SecureStorage get _storage => ref.read(secureStorageProvider);

  /// ==========================================
  /// AUTO-LOGIN - Check for Existing Session
  /// ==========================================
  /// Called when the app first starts. Checks if there's a stored access token,
  /// and if so, validates it by fetching the user profile. If the token is valid,
  /// the user is automatically logged in without seeing the login screen.
  ///
  /// Returns true if auto-login succeeded, false otherwise.
  /// ==========================================
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
        // Token is invalid or expired - clear it
        await _storage.clearTokens();
        _api.clearAuthToken();
        return false;
      }
    }
    return false;
  }

  /// ==========================================
  /// LOGIN - Authenticate with Credentials
  /// ==========================================
  /// Sends email/password to the backend. On success:
  /// 1. Saves the access and refresh tokens to secure storage
  /// 2. Sets the access token on the API client for future requests
  /// 3. Fetches the user profile and updates the state
  ///
  /// On failure, stores the error message in state for UI display.
  /// ==========================================
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

  /// ==========================================
  /// REGISTER - Create New Account
  /// ==========================================
  /// Sends name/email/password to the backend to create a new user.
  /// On success, automatically logs in the new user (saves tokens and fetches profile).
  /// ==========================================
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

  /// ==========================================
  /// LOGOUT - End User Session
  /// ==========================================
  /// Clears all stored tokens, removes the auth header from the API client,
  /// clears task data, and resets the auth state to unauthenticated.
  /// The logout API call is fire-and-forget (errors are silently ignored).
  /// ==========================================
  Future<void> logout() async {
    try { await _api.post('/auth/logout'); } catch (_) {}
    await _storage.clearTokens();
    _api.clearAuthToken();
    try {
      ref.read(taskProvider.notifier).clearTasks();
    } catch (_) {}
    state = AuthState();
  }

  /// ==========================================
  /// REFRESH USER - Re-fetch Current User Profile
  /// ==========================================
  /// Re-fetches the user profile from the backend and updates the state.
  /// Used after profile updates (name change, avatar upload) to sync the UI.
  /// ==========================================
  Future<void> refreshUser() async {
    try {
      final response = await _api.get('/users/me');
      final user = UserInfo.fromJson(response.data['data']['user']);
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  /// ==========================================
  /// FORGOT PASSWORD - Request Password Reset Email
  /// ==========================================
  /// Sends the user's email to the backend, which triggers a password reset email.
  /// Returns true if the email was sent successfully.
  /// ==========================================
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

  /// ==========================================
  /// CHANGE PASSWORD - Update Password for Logged-in User
  /// ==========================================
  /// Changes the password for the currently authenticated user.
  /// Requires the current password for verification.
  /// Returns true if the password was changed successfully.
  /// ==========================================
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
