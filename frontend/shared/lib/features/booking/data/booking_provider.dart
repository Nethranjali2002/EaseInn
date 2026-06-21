import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

class Booking {
  final String id;
  final String code;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final String roomId;
  final String roomNumber;
  final String roomType;
  final DateTime checkIn;
  final DateTime checkOut;
  final int numberOfGuests;
  final int adults;
  final int children;
  final int nights;
  final double totalAmount;
  final double amountPaid;
  final String paymentStatus;
  final String bookingStatus;

  // Detailed fields for 10 Sections Booking details view
  final String propertyId;
  final String createdByName;
  final String propertyName;
  final String propertyAddress;
  final String propertyPhone;
  final String propertyEmail;
  final int roomCapacity;
  final double roomPricePerNight;
  final double roomCharge;
  final String mealPlan;
  final double mealPlanTotal;
  final double discount;
  final double tax;
  final String paymentMethod;
  final String transactionReference;
  final String guestNIC;
  final String guestNationality;
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

  factory Booking.fromJson(Map<String, dynamic> json) {
    final checkInDate = DateTime.parse(json['checkIn']);
    final checkOutDate = DateTime.parse(json['checkOut']);
    final computedNights = checkOutDate.difference(checkInDate).inDays;

    final createdByJson = json['createdBy'];
    String createdByName = 'Manager';
    if (createdByJson is Map) {
      createdByName = createdByJson['name'] ?? 'Manager';
    }

    final propertyJson = json['property'];
    String propertyId = '';
    String propertyName = 'Seaside Resort & Spa';
    String propertyAddress = 'Matara, Sri Lanka';
    String propertyPhone = '0412222222';
    String propertyEmail = 'info@seasideresort.com';
    if (propertyJson is Map) {
      propertyId = propertyJson['_id'] ?? propertyJson['id'] ?? '';
      propertyName = propertyJson['name'] ?? 'Seaside Resort & Spa';
      final addr = propertyJson['address'];
      if (addr is Map) {
        propertyAddress = [addr['street'], addr['city'], addr['state'], addr['country']].where((e) => e != null).join(', ');
      } else {
        propertyAddress = addr ?? 'Matara, Sri Lanka';
      }
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

    final roomJson = json['room'];
    int roomCapacity = 2;
    double roomPricePerNight = (json['pricing']?['basePrice'] ?? 15000)
        .toDouble();
    String roomNum = '';
    String roomTp = '';
    String roomIdStr = '';
    if (roomJson is Map) {
      roomIdStr = roomJson['_id'] ?? roomJson['id'] ?? '';
      roomNum = roomJson['roomNumber'] ?? '';
      roomTp = roomJson['roomType'] ?? json['roomType'] ?? '';
      roomCapacity = roomJson['capacity'] ?? 2;
      roomPricePerNight = (roomJson['basePrice'] ?? roomPricePerNight)
          .toDouble();
    } else if (roomJson is String) {
      roomIdStr = roomJson;
      roomNum = json['roomNumber'] ?? '';
      roomTp = json['roomType'] ?? '';
    } else {
      roomNum = json['roomNumber'] ?? '';
      roomTp = json['roomType'] ?? '';
    }

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
      nights:
          pricingJson['nights'] ?? (computedNights > 0 ? computedNights : 1),
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
      roomCharge:
          (pricingJson['roomTotal'] ?? (roomPricePerNight * computedNights))
              .toDouble(),
      mealPlan: json['mealPlan'] ?? 'none',
      mealPlanTotal: (pricingJson['mealPlanTotal'] ?? 0).toDouble(),
      discount: (pricingJson['discount'] ?? 0).toDouble(),
      tax: (pricingJson['tax'] ?? 0).toDouble(),
      paymentMethod: json['paymentMethod'] ?? 'PayHere',
      transactionReference:
          json['transactionReference'] ??
          'PH-${(json['_id'] ?? json['id'] ?? '123456').toString().substring(0, 6)}',
      guestNIC: json['guest']?['idNumber'] ?? '200012345678',
      guestNationality: json['guest']?['nationality'] ?? 'Sri Lankan',
      specialRequests: json['specialRequests'] ?? '',
      notes: json['notes'] ?? '',
      cancellationReason: json['cancellationReason'] ?? '',
      bookingDate: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
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

final bookingProvider = NotifierProvider<BookingNotifier, BookingState>(
  BookingNotifier.new,
);

class BookingNotifier extends Notifier<BookingState> {
  @override
  BookingState build() => BookingState();

  ApiClient get _api => ref.read(apiClientProvider);

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
