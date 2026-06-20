import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

/// ==========================================
/// BOOKING - Guest Reservation Data Model
/// ==========================================
/// Represents a guest booking/reservation at a property.
/// This is the most complex model in the app, tying together:
/// - Guest information (name, email, phone, ID)
/// - Room details (number, type, price per night)
/// - Stay dates (check-in, check-out, nights)
/// - Financial breakdown (room total, meal plan, addons, tax, discount)
/// - Payment tracking (amount paid, payment status)
/// - Booking lifecycle (status: pending -> confirmed -> checked-in -> checked-out)
///
/// The [fromJson] factory handles deeply nested JSON from the backend,
/// where room and property data are populated (expanded) objects.
/// ==========================================
class Booking {
  // ==========================================
  // CORE IDENTIFIERS
  // ==========================================
  final String id;
  final String code; // Confirmation code like "BKG-240518-0001"
  final String propertyId;
  final String roomId;
  final String roomNumber;
  final String roomType;

  // ==========================================
  // GUEST INFORMATION
  // ==========================================
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String guestNIC;
  final String guestNationality;

  // ==========================================
  // STAY DETAILS
  // ==========================================
  final DateTime checkIn;
  final DateTime checkOut;
  final int numberOfGuests;
  final int adults;
  final int children;
  final int nights;

  // ==========================================
  // FINANCIAL BREAKDOWN (10-Section Booking Details)
  // ==========================================
  final double totalAmount;
  final double amountPaid;
  final double roomCharge; // basePrice * nights
  final double roomPricePerNight;
  final int roomCapacity;
  final String mealPlan;
  final double mealPlanTotal;
  final double discount;
  final double tax;
  final String paymentMethod;
  final String transactionReference;

  // ==========================================
  // STATUS TRACKING
  // ==========================================
  final String paymentStatus; // 'pending', 'partial', 'paid', 'refunded', 'cancelled'
  final String bookingStatus; // 'pending-payment', 'confirmed', 'checked-in', 'checked-out', 'cancelled'

  // ==========================================
  // PROPERTY & BOOKING METADATA
  // ==========================================
  final String createdByName;
  final String propertyName;
  final String propertyAddress;
  final String propertyPhone;
  final String propertyEmail;
  final String specialRequests;
  final String notes;
  final String cancellationReason;
  final DateTime bookingDate;

  Booking({
    required this.id,
    this.code = '',
    required this.guestName,
    this.guestEmail = '',
    this.guestPhone = '',
    this.roomId = '',
    this.roomNumber = '',
    this.roomType = '',
    required this.checkIn,
    required this.checkOut,
    this.numberOfGuests = 1,
    this.adults = 1,
    this.children = 0,
    this.nights = 1,
    this.totalAmount = 0,
    this.amountPaid = 0,
    this.paymentStatus = 'pending',
    this.bookingStatus = 'confirmed',
    this.propertyId = '',
    this.createdByName = 'Manager',
    this.propertyName = 'Seaside Resort & Spa',
    this.propertyAddress = 'Matara, Sri Lanka',
    this.propertyPhone = '0412222222',
    this.propertyEmail = 'info@seasideresort.com',
    this.roomCapacity = 2,
    this.roomPricePerNight = 15000,
    this.roomCharge = 30000,
    this.mealPlan = 'none',
    this.mealPlanTotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.paymentMethod = 'PayHere',
    this.transactionReference = 'PH-123456',
    this.guestNIC = '200012345678',
    this.guestNationality = 'Sri Lankan',
    this.specialRequests = '',
    this.notes = '',
    this.cancellationReason = '',
    required this.bookingDate,
  });

  /// ==========================================
  /// JSON PARSER - Handle Deeply Nested Backend Response
  /// ==========================================
  /// The backend returns booking data with populated room, property, and createdBy
  /// objects. This parser safely extracts data from all these nested structures,
  /// handling cases where fields might be missing or in different formats.
  ///
  /// Key parsing challenges:
  /// - 'property' can be a nested object OR a string ID
  /// - 'room' can be a nested object OR a string ID
  /// - 'createdBy' is a nested user object
  /// - 'pricing' is a nested object with financial breakdown
  /// - Dates need parsing from ISO strings
  /// ==========================================
  factory Booking.fromJson(Map<String, dynamic> json) {
    // Parse dates first - needed for nights calculation
    final checkInDate = DateTime.parse(json['checkIn']);
    final checkOutDate = DateTime.parse(json['checkOut']);
    final computedNights = checkOutDate.difference(checkInDate).inDays;

    // ==========================================
    // PARSE CREATED BY (Staff member who created the booking)
    // ==========================================
    final createdByJson = json['createdBy'];
    String createdByName = 'Manager';
    if (createdByJson is Map) {
      createdByName = createdByJson['name'] ?? 'Manager';
    }

    // ==========================================
    // PARSE PROPERTY (Can be populated object or string ID)
    // ==========================================
    final propertyJson = json['property'];
    String propertyId = '';
    String propertyName = 'Seaside Resort & Spa';
    String propertyAddress = 'Matara, Sri Lanka';
    String propertyPhone = '0412222222';
    String propertyEmail = 'info@seasideresort.com';
    if (propertyJson is Map) {
      propertyId = propertyJson['_id'] ?? propertyJson['id'] ?? '';
      propertyName = propertyJson['name'] ?? 'Seaside Resort & Spa';
      // Address can be a nested object or a plain string
      final addr = propertyJson['address'];
      if (addr is Map) {
        propertyAddress = [addr['street'], addr['city'], addr['state'], addr['country']].where((e) => e != null).join(', ');
      } else {
        propertyAddress = addr ?? 'Matara, Sri Lanka';
      }
      // Contact can be nested or flat
      final contact = propertyJson['contact'];
      if (contact is Map) {
        propertyPhone = contact['phone'] ?? '0412222222';
        propertyEmail = contact['email'] ?? 'info@seasideresort.com';
      } else {
        propertyPhone = propertyJson['phone'] ?? '0412222222';
        propertyEmail = propertyJson['email'] ?? 'info@seasideresort.com';
      }
    } else if (propertyJson is String) {
      propertyId = propertyJson;
    } else if (json['propertyId'] != null) {
      propertyId = json['propertyId'].toString();
    }

    // ==========================================
    // PARSE ROOM (Can be populated object or string ID)
    // ==========================================
    final roomJson = json['room'];
    int roomCapacity = 2;
    double roomPricePerNight = (json['pricing']?['basePrice'] ?? 15000).toDouble();
    String roomNum = '';
    String roomTp = '';
    String roomIdStr = '';
    if (roomJson is Map) {
      roomIdStr = roomJson['_id'] ?? roomJson['id'] ?? '';
      roomNum = roomJson['roomNumber'] ?? '';
      roomTp = roomJson['roomType'] ?? json['roomType'] ?? '';
      roomCapacity = roomJson['capacity'] ?? 2;
      roomPricePerNight = (roomJson['basePrice'] ?? roomPricePerNight).toDouble();
    } else if (roomJson is String) {
      roomIdStr = roomJson;
      roomNum = json['roomNumber'] ?? '';
      roomTp = json['roomType'] ?? '';
    } else {
      roomNum = json['roomNumber'] ?? '';
      roomTp = json['roomType'] ?? '';
    }

    // ==========================================
    // PARSE PRICING (Nested financial breakdown)
    // ==========================================
    final pricingJson = json['pricing'] ?? {};

    return Booking(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      guestName: json['guest']?['name'] ?? '',
      guestEmail: json['guest']?['email'] ?? '',
      guestPhone: json['guest']?['phone'] ?? '',
      roomId: roomIdStr,
      roomNumber: roomNum,
      roomType: roomTp,
      checkIn: checkInDate,
      checkOut: checkOutDate,
      numberOfGuests: json['numberOfGuests'] ?? 1,
      adults: json['adults'] ?? 1,
      children: json['children'] ?? 0,
      nights: pricingJson['nights'] ?? (computedNights > 0 ? computedNights : 1),
      totalAmount: (pricingJson['totalAmount'] ?? 0).toDouble(),
      amountPaid: (json['amountPaid'] ?? 0).toDouble(),
      paymentStatus: json['paymentStatus'] ?? 'pending',
      bookingStatus: json['bookingStatus'] ?? 'confirmed',
      propertyId: propertyId,
      createdByName: createdByName,
      propertyName: propertyName,
      propertyAddress: propertyAddress,
      propertyPhone: propertyPhone,
      propertyEmail: propertyEmail,
      roomCapacity: roomCapacity,
      roomPricePerNight: roomPricePerNight,
      roomCharge: (pricingJson['roomTotal'] ?? (roomPricePerNight * computedNights)).toDouble(),
      mealPlan: json['mealPlan'] ?? 'none',
      mealPlanTotal: (pricingJson['mealPlanTotal'] ?? 0).toDouble(),
      discount: (pricingJson['discount'] ?? 0).toDouble(),
      tax: (pricingJson['tax'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'PayHere',
      transactionReference: json['transactionReference'] ?? 'PH-${(json['_id'] ?? json['id'] ?? '123456').toString().substring(0, 6)}',
      guestNIC: json['guest']?['idNumber'] ?? '200012345678',
      guestNationality: json['guest']?['nationality'] ?? 'Sri Lankan',
      specialRequests: json['specialRequests'] ?? '',
      notes: json['notes'] ?? '',
      cancellationReason: json['cancellationReason'] ?? '',
      bookingDate: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}

/// ==========================================
/// BOOKING STATE - State Container
/// ==========================================
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

  BookingState copyWith({
    List<Booking>? bookings,
    bool? isLoading,
    String? error,
    int? total,
  }) {
    return BookingState(
      bookings: bookings ?? this.bookings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

/// ==========================================
/// BOOKING PROVIDER - Booking State Manager
/// ==========================================
/// Manages all booking operations:
/// - Fetching bookings (per-property or across all properties)
/// - Creating, updating, cancelling bookings
/// - Check-in and check-out operations
///
/// Supports both property-scoped and global booking views.
/// ==========================================
final bookingProvider = NotifierProvider<BookingNotifier, BookingState>(
  BookingNotifier.new,
);

class BookingNotifier extends Notifier<BookingState> {
  @override
  BookingState build() => BookingState();

  ApiClient get _api => ref.read(apiClientProvider);

  /// ==========================================
  /// FETCH BOOKINGS - Load Bookings for a Property
  /// ==========================================
  /// Retrieves all bookings belonging to a specific property.
  /// Supports optional filtering by status and search term.
  /// ==========================================
  Future<void> fetchBookings(
    String propertyId, {
    String? status,
    String? search,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get(
        '/properties/$propertyId/bookings',
        queryParameters: {
          if (status != null) 'status': status,
          if (search != null) 'search': search,
        },
      );
      final data = response.data['data'];
      final bookings = (data['bookings'] as List)
          .map((b) => Booking.fromJson(b as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        bookings: bookings,
        isLoading: false,
        total: data['total'] ?? bookings.length,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// ==========================================
  /// FETCH ALL BOOKINGS - Load Across All Properties
  /// ==========================================
  /// Retrieves bookings from all properties the user has access to.
  /// Used on the consolidated dashboard view for admins.
  /// ==========================================
  Future<void> fetchAllBookings({
    String? status,
    String? search,
    String? propertyId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get(
        '/bookings',
        queryParameters: {
          if (status != null) 'status': status,
          if (search != null) 'search': search,
          if (propertyId != null) 'propertyId': propertyId,
        },
      );
      final data = response.data['data'];
      final bookings = (data['bookings'] as List)
          .map((b) => Booking.fromJson(b as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        bookings: bookings,
        isLoading: false,
        total: data['total'] ?? bookings.length,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// ==========================================
  /// CREATE BOOKING - Add New Reservation
  /// ==========================================
  /// Creates a new booking via the backend API.
  /// On success, prepends the new booking to the list.
  /// ==========================================
  Future<bool> createBooking(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post('/bookings', data: data);
      final booking = Booking.fromJson(response.data['data']['booking'] as Map<String, dynamic>);
      state = state.copyWith(
        bookings: [booking, ...state.bookings],
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// ==========================================
  /// UPDATE BOOKING - Modify Existing Reservation
  /// ==========================================
  /// Sends partial updates to the backend (e.g., change dates, special requests).
  /// On success, replaces the old booking with the updated version.
  /// ==========================================
  Future<bool> updateBooking(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/bookings/$id', data: data);
      final booking = Booking.fromJson(response.data['data']['booking'] as Map<String, dynamic>);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// ==========================================
  /// CANCEL BOOKING - Cancel a Reservation
  /// ==========================================
  /// Cancels a booking with a reason. The backend handles refund logic
  /// and room status updates.
  /// ==========================================
  Future<bool> cancelBooking(String id, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch(
        '/bookings/$id/cancel',
        data: {'reason': reason},
      );
      final booking = Booking.fromJson(response.data['data']['booking'] as Map<String, dynamic>);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// ==========================================
  /// CHECK-IN - Register Guest Arrival
  /// ==========================================
  /// Updates the booking status to 'checked-in' and marks the room as occupied.
  /// ==========================================
  Future<bool> checkIn(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/bookings/$id/check-in');
      final booking = Booking.fromJson(response.data['data']['booking'] as Map<String, dynamic>);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// ==========================================
  /// CHECK-OUT - Register Guest Departure
  /// ==========================================
  /// Updates the booking status to 'checked-out' and marks the room
  /// as available for cleaning/maintenance.
  /// ==========================================
  Future<bool> checkOut(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/bookings/$id/check-out');
      final booking = Booking.fromJson(response.data['data']['booking'] as Map<String, dynamic>);
      state = state.copyWith(
        bookings: state.bookings.map((b) => b.id == id ? booking : b).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
