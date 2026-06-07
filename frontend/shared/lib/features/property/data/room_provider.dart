import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

class Room {
  final String id;
  final String code;
  final String propertyId;
  final String roomNumber;
  final String roomType;
  final String name;
  final int capacity;
  final double basePrice;
  final String status;
  final int floor;
  final List<String> amenities;
  final List<String> images;
  final String currentBooking;
  final String? currentBookingId;

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

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
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

final roomProvider = NotifierProvider<RoomNotifier, RoomState>(
  RoomNotifier.new,
);

class RoomNotifier extends Notifier<RoomState> {
  @override
  RoomState build() => RoomState();

  ApiClient get _api => ref.read(apiClientProvider);

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
