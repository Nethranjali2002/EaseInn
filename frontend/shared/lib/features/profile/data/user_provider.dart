import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

/// ==========================================
/// USER - Staff Member Data Model
/// ==========================================
/// Represents a staff member or admin user in the system.
/// Contains both personal information and employment details.
///
/// This model is used for:
/// - Displaying staff profiles
/// - Admin user management (CRUD operations)
/// - Profile updates
/// - Account deletion
/// ==========================================
class User {
  final String id;
  final String code; // Employee code like "USR-0001"
  final String name;
  final String email;
  final String role; // 'admin', 'manager', 'staff'
  final bool isActive;
  final DateTime? createdAt;

  // Employment Details
  final String employeeId;
  final String dateOfBirth;
  final String gender;
  final String nicPassport;
  final String phone;
  final String address;
  final String city;
  final String district;
  final String postalCode;
  final String joinDate;
  final String employmentType; // 'Full Time', 'Part Time', 'Contract'
  final String property; // Assigned property ID

  // Emergency Contact
  final String emergencyName;
  final String emergencyRelationship;
  final String emergencyPhone;

  // Status & Documents
  final String status; // 'Active', 'Inactive', 'On Leave'
  final DateTime? lastLogin;
  final String nicCopy; // URL to uploaded NIC document
  final String agreement; // URL to employment agreement
  final String certificates; // URL to uploaded certificates
  final String profileImage; // URL to profile avatar

  User({
    required this.id,
    this.code = '',
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.createdAt,
    this.employeeId = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.nicPassport = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.district = '',
    this.postalCode = '',
    this.joinDate = '',
    this.employmentType = 'Full Time',
    this.property = '',
    this.emergencyName = '',
    this.emergencyRelationship = '',
    this.emergencyPhone = '',
    this.status = 'Active',
    this.lastLogin,
    this.nicCopy = '',
    this.agreement = '',
    this.certificates = '',
    this.profileImage = '',
  });

  /// ==========================================
  /// JSON PARSER - Convert Backend Response to User Object
  /// ==========================================
  /// Handles the 'property' field which can be a populated object or a string ID.
  /// Uses null-safe defaults for all optional fields.
  /// ==========================================
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      employeeId: json['employeeId'] ?? '',
      dateOfBirth: json['dateOfBirth'] ?? '',
      gender: json['gender'] ?? '',
      nicPassport: json['nicPassport'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      postalCode: json['postalCode'] ?? '',
      joinDate: json['joinDate'] ?? '',
      employmentType: json['employmentType'] ?? 'Full Time',
      // Property can be a nested object or a plain string ID
      property: json['property'] is Map
          ? (json['property']['_id'] ?? json['property']['id'] ?? '')
          : (json['property'] ?? ''),
      emergencyName: json['emergencyName'] ?? '',
      emergencyRelationship: json['emergencyRelationship'] ?? '',
      emergencyPhone: json['emergencyPhone'] ?? '',
      status: json['status'] ?? 'Active',
      lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
      nicCopy: json['nicCopy'] ?? '',
      agreement: json['agreement'] ?? '',
      certificates: json['certificates'] ?? '',
      profileImage: json['profileImage'] ?? '',
    );
  }

  /// ==========================================
  /// TO JSON - Convert User Object to Map
  /// ==========================================
  /// Serializes the User object back to a JSON-compatible map.
  /// Used when sending updated user data to the backend.
  /// ==========================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'isActive': isActive,
      'employeeId': employeeId,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'nicPassport': nicPassport,
      'phone': phone,
      'address': address,
      'city': city,
      'district': district,
      'postalCode': postalCode,
      'joinDate': joinDate,
      'employmentType': employmentType,
      'property': property,
      'emergencyName': emergencyName,
      'emergencyRelationship': emergencyRelationship,
      'emergencyPhone': emergencyPhone,
      'status': status,
      'nicCopy': nicCopy,
      'agreement': agreement,
      'certificates': certificates,
      'profileImage': profileImage,
    };
  }
}

/// ==========================================
/// USER STATE - State Container
/// ==========================================
class UserState {
  final User? user;
  final bool isLoading;
  final String? error;

  UserState({this.user, this.isLoading = false, this.error});

  UserState copyWith({User? user, bool? isLoading, String? error, bool clearUser = false}) {
    return UserState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// ==========================================
/// USER PROVIDER - User Profile State Manager
/// ==========================================
/// Manages user profile operations:
/// - Fetching the current user's profile
/// - Updating profile (name, avatar)
/// - Deleting the user's account
/// ==========================================
final userProvider = NotifierProvider<UserNotifier, UserState>(UserNotifier.new);

class UserNotifier extends Notifier<UserState> {
  @override
  UserState build() => UserState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// ==========================================
  /// FETCH PROFILE - Load Current User's Data
  /// ==========================================
  /// Retrieves the full profile for the currently logged-in user
  /// from the backend's /users/me endpoint.
  /// ==========================================
  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/users/me');
      final userData = response.data['data'] ?? response.data['user'];
      final user = User.fromJson(userData as Map<String, dynamic>);
      state = state.copyWith(user: user, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load profile');
    }
  }

  /// ==========================================
  /// UPDATE PROFILE - Modify User Information
  /// ==========================================
  /// Updates the current user's profile with the provided fields.
  /// Only non-null fields are sent to the backend (partial update).
  /// After a successful update, the local state is refreshed.
  /// ==========================================
  Future<void> updateProfile({String? name, String? profileImage}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (profileImage != null) data['profileImage'] = profileImage;
      final response = await _api.patch('/users/me', data: data);
      final userData = response.data['data'] ?? response.data['user'];
      final user = User.fromJson(userData as Map<String, dynamic>);
      state = state.copyWith(user: user, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to update profile');
    }
  }

  /// ==========================================
  /// DELETE ACCOUNT - Permanently Remove User
  /// ==========================================
  /// Deletes the current user's account from the backend.
  /// After deletion, automatically logs the user out.
  /// ==========================================
  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.delete('/users/me');
      await ref.read(authProvider.notifier).logout();
      state = UserState();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to delete account');
      return false;
    }
  }
}
