import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

class Booking {
  final String id;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String roomNumber;
  final String roomType;
  final DateTime checkIn;
  final DateTime checkOut;
  final int numberOfGuests;
  final double totalAmount;
  final double amountPaid;
  final String paymentStatus;
  final String bookingStatus;

  Booking({
    required this.id,
    required this.guestName,
    this.guestEmail = '',
    this.guestPhone = '',
    this.roomNumber = '',
    this.roomType = '',
    required this.checkIn,
    required this.checkOut,
    this.numberOfGuests = 1,
    this.totalAmount = 0,
    this.amountPaid = 0,
    this.paymentStatus = 'pending',
    this.bookingStatus = 'confirmed',
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['_id'] ?? json['id'] ?? '',
      guestName: json['guest']?['name'] ?? '',
      guestEmail: json['guest']?['email'] ?? '',
      guestPhone: json['guest']?['phone'] ?? '',
      roomNumber: json['room']?['roomNumber'] ?? '',
      roomType: json['room']?['roomType'] ?? json['roomType'] ?? '',
      checkIn: DateTime.parse(json['checkIn']),
      checkOut: DateTime.parse(json['checkOut']),
      numberOfGuests: json['numberOfGuests'] ?? 1,
      totalAmount: (json['pricing']?['totalAmount'] ?? 0).toDouble(),
      amountPaid: (json['amountPaid'] ?? 0).toDouble(),
      paymentStatus: json['paymentStatus'] ?? 'pending',
      bookingStatus: json['bookingStatus'] ?? 'confirmed',
    );
  }
}

class BookingState {
  final List<Booking> bookings;
  final bool isLoading;
  final String? error;
  final int total;

  BookingState({
    this.bookings = const [],
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  BookingState copyWith({List<Booking>? bookings, bool? isLoading, String? error, int? total}) {
    return BookingState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

final bookingProvider = NotifierProvider<BookingNotifier, BookingState>(BookingNotifier.new);

class BookingNotifier extends Notifier<BookingState> {
  @override
  BookingState build() => BookingState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetchBookings(String propertyId, {String? status, String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/properties/$propertyId/bookings', queryParameters: {
        if (status != null) 'status': status,
        if (search != null) 'search': search,
      });
      final data = response.data['data'];
      final bookings = (data['bookings'] as List)
          .map((b) => Booking.fromJson(b as Map<String, dynamic>))
          .toList();
      state = state.copyWith(bookings: bookings, isLoading: false, total: data['total'] ?? bookings.length);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<bool> createBooking(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post('/bookings', data: data);
      final booking = Booking.fromJson(response.data['data']['booking']);
      state = state.copyWith(bookings: [booking, ...state.bookings], isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> updateBooking(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/bookings/$id', data: data);
      final booking = Booking.fromJson(response.data['data']['booking']);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> cancelBooking(String id, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/bookings/$id/cancel', data: {'reason': reason});
      final booking = Booking.fromJson(response.data['data']['booking']);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> checkIn(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/bookings/$id/check-in');
      final booking = Booking.fromJson(response.data['data']['booking']);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> checkOut(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/bookings/$id/check-out');
      final booking = Booking.fromJson(response.data['data']['booking']);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }
}
