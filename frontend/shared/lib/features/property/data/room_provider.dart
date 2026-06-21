import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

/// ==========================================
/// ROOM - Individual Room Data Model
/// ==========================================
/// Represents a single room within a property. Each room has a type,
/// capacity, nightly price, and current status (available, occupied, maintenance).
///
/// Rooms are always scoped to a property - you fetch rooms via
/// /properties/:propertyId/rooms.
/// ==========================================
class Room {
  final String id;
  final String code; // Human-readable code like "RM-0001"
  final String propertyId; // Which property this room belongs to
  final String roomNumber; // Physical room number (e.g., "101", "A-205")
  final String roomType; // Category (e.g., "Deluxe", "Suite", "Standard")
  final String name; // Display name (e.g., "Deluxe Room 1")
  final int capacity; // Max guests allowed
  final double basePrice; // Nightly rate
  final String status; // 'available', 'occupied', 'booked', 'maintenance'
  final int floor; // Floor number for organizing rooms
  final List<String> amenities; // Room-specific amenities
  final List<String> images; // Room photos
  final String currentBooking; // Summary of current booking (if occupied)
  final String? currentBookingId; // ID of the active booking (if any)

  Room({
    required this.id,
    this.code = '',
    required this.propertyId,
    required this.roomNumber,
    required this.roomType,
    this.name = '',
    this.capacity = 1,
    this.basePrice = 0,
    this.status = 'available',
    this.floor = 0,
    this.amenities = const [],
    this.images = const [],
    this.currentBooking = '-',
    this.currentBookingId,
  });

  /// ==========================================
  /// JSON PARSER - Handle Flexible Property Reference
  /// ==========================================
  /// The 'property' field can come as either a populated object or a plain string ID.
  /// This parser handles both formats gracefully.
  /// ==========================================
  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      // Property can be a nested object (populated) or a string ID
      propertyId: json['property'] is Map
          ? (json['property']['_id'] ?? json['property']['id'] ?? '')
          : (json['property'] ?? ''),
      roomNumber: json['roomNumber'] ?? '',
      roomType: json['roomType'] ?? '',
      name: json['name'] ?? '',
      capacity: json['capacity'] ?? 1,
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      status: json['status'] ?? 'available',
      floor: json['floor'] ?? 0,
      amenities: List<String>.from(json['amenities'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      currentBooking: json['currentBooking'] ?? '-',
      currentBookingId: json['currentBookingId'],
    );
  }
}

/// ==========================================
/// ROOM STATE - State Container
/// ==========================================
class RoomState {
  final List<Room> rooms;
  final bool isLoading;
  final String? error;
  final int total;

  RoomState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  RoomState copyWith({
    List<Room>? rooms,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return RoomState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

/// ==========================================
/// ROOM PROVIDER - Room State Manager
/// ==========================================
/// Manages room CRUD operations for a specific property.
/// All operations are scoped to a property via its ID.
/// ==========================================
final roomProvider = NotifierProvider<RoomNotifier, RoomState>(
  RoomNotifier.new,
);

class RoomNotifier extends Notifier<RoomState> {
  @override
  RoomState build() => RoomState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// ==========================================
  /// FETCH ROOMS - Load Rooms for a Property
  /// ==========================================
  /// Retrieves all rooms belonging to a specific property.
  /// Supports optional filtering by status and room type.
  /// ==========================================
  Future<void> fetchRooms(
    String propertyId, {
    String? status,
    String? roomType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get(
        '/properties/$propertyId/rooms',
        queryParameters: {'status': ?status, 'roomType': ?roomType},
      );
      final data = response.data['data'];
      final rooms = (data['rooms'] as List)
          .map((r) => Room.fromJson(r as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        rooms: rooms,
        isLoading: false,
        total: data['total'] ?? rooms.length,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// ==========================================
  /// CREATE ROOM - Add New Room to Property
  /// ==========================================
  /// Creates a new room under the specified property.
  /// On success, prepends the new room to the list.
  /// ==========================================
  Future<bool> createRoom(String propertyId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post(
        '/properties/$propertyId/rooms',
        data: data,
      );
      final room = Room.fromJson(response.data['data']['room']);
      state = state.copyWith(rooms: [room, ...state.rooms], isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  /// ==========================================
  /// UPDATE ROOM - Modify Room Details
  /// ==========================================
  /// Updates a room's information (type, price, status, etc.).
  /// On success, replaces the old room with the updated version.
  /// ==========================================
  Future<bool> updateRoom(String roomId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/rooms/$roomId', data: data);
      final room = Room.fromJson(response.data['data']['room']);
      state = state.copyWith(
        rooms: state.rooms.map((r) => r.id == roomId ? room : r).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  /// ==========================================
  /// DELETE ROOM - Remove Room
  /// ==========================================
  /// Deletes a room from the backend and removes it from the local list.
  /// ==========================================
  Future<bool> deleteRoom(String roomId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.delete('/rooms/$roomId');
      state = state.copyWith(
        rooms: state.rooms.where((r) => r.id != roomId).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }
}
