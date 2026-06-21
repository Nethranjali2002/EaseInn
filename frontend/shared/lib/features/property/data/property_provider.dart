import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

class Property {
  final String id;
  final String code;
  final String name;
  final String description;
  final Map<String, dynamic> address;
  final Map<String, dynamic> contact;
  final List<String> amenities;
  final List<String> images;
  final bool isActive;
  final int totalRooms;
  final int availableRooms;
  final double occupancyRate;
  final int activeBookings;
  final double revenueThisMonth;
  final String createdAt;
  final String propertyType;
  final String website;
  final String checkInTime;
  final String checkOutTime;
  final String logo;
  final String coverImage;

  Property({
    required this.id,
    this.code = '',
    required this.name,
    this.description = '',
    this.address = const {},
    this.contact = const {},
    this.amenities = const [],
    this.images = const [],
    this.isActive = true,
    this.totalRooms = 0,
    this.availableRooms = 0,
    this.occupancyRate = 0.0,
    this.activeBookings = 0,
    this.revenueThisMonth = 0.0,
    this.createdAt = '',
    this.propertyType = 'Resort',
    this.website = '',
    this.checkInTime = '14:00',
    this.checkOutTime = '11:00',
    this.logo = '',
    this.coverImage = '',
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    final contactMap = json['contact'] ?? {};
    return Property(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? {},
      contact: contactMap,
      amenities: List<String>.from(json['amenities'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      isActive: json['isActive'] ?? true,
      totalRooms: json['totalRooms'] ?? 0,
      availableRooms: json['availableRooms'] ?? 0,
      occupancyRate: (json['occupancyRate'] as num?)?.toDouble() ?? 0.0,
      activeBookings: json['activeBookings'] ?? 0,
      revenueThisMonth: (json['revenueThisMonth'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] ?? '',
      propertyType: json['propertyType'] ?? 'Resort',
      website: json['website'] ?? contactMap['website'] ?? '',
      checkInTime: json['checkInTime'] ?? '14:00',
      checkOutTime: json['checkOutTime'] ?? '11:00',
      logo: json['logo'] ?? '',
      coverImage: json['coverImage'] ?? '',
    );
  }
}

class PropertyState {
  final List<Property> properties;
  final Property? selectedProperty;
  final bool isLoading;
  final String? error;
  final int total;

  PropertyState({
    this.properties = const [],
    this.selectedProperty,
    this.isLoading = false,
    this.error,
    this.total = 0,
  });

  PropertyState copyWith({
    List<Property>? properties,
    Property? selectedProperty,
    bool? isLoading,
    String? error,
    int? total,
    bool clearSelected = false,
  }) {
    return PropertyState(
      properties: properties ?? this.properties,
      selectedProperty: clearSelected
          ? null
          : (selectedProperty ?? this.selectedProperty),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

final propertyProvider = NotifierProvider<PropertyNotifier, PropertyState>(
  PropertyNotifier.new,
);

class PropertyNotifier extends Notifier<PropertyState> {
  @override
  PropertyState build() => PropertyState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetchProperties({String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get(
        '/properties',
        queryParameters: {'search': ?search},
      );
      final data = response.data['data'];
      final properties = (data['properties'] as List)
          .map((p) => Property.fromJson(p as Map<String, dynamic>))
          .toList();
      state = state.copyWith(
        properties: properties,
        isLoading: false,
        total: data['total'] ?? properties.length,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  Future<bool> createProperty(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.post('/properties', data: data);
      final property = Property.fromJson(response.data['data']['property']);
      state = state.copyWith(
        properties: [property, ...state.properties],
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> updateProperty(String id, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.patch('/properties/$id', data: data);
      final property = Property.fromJson(response.data['data']['property']);
      state = state.copyWith(
        properties: state.properties
            .map((p) => p.id == id ? property : p)
            .toList(),
        selectedProperty: property,
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> deleteProperty(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.delete('/properties/$id');
      state = state.copyWith(
        properties: state.properties.where((p) => p.id != id).toList(),
        isLoading: false,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    }
  }
}
