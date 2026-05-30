import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';

class Property {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> address;
  final Map<String, dynamic> contact;
  final List<String> amenities;
  final List<String> images;
  final bool isActive;
  final int totalRooms;

  Property({
    required this.id,
    required this.name,
    this.description = '',
    this.address = const {},
    this.contact = const {},
    this.amenities = const [],
    this.images = const [],
    this.isActive = true,
    this.totalRooms = 0,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? {},
      contact: json['contact'] ?? {},
      amenities: List<String>.from(json['amenities'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      isActive: json['isActive'] ?? true,
      totalRooms: json['totalRooms'] ?? 0,
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
      selectedProperty: clearSelected ? null : (selectedProperty ?? this.selectedProperty),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      total: total ?? this.total,
    );
  }
}

final propertyProvider = NotifierProvider<PropertyNotifier, PropertyState>(PropertyNotifier.new);

class PropertyNotifier extends Notifier<PropertyState> {
  @override
  PropertyState build() => PropertyState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetchProperties({String? search}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/properties', queryParameters: {
        if (search != null) 'search': search,
      });
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

  Future<void> fetchPropertyById(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/properties/$id');
      final property = Property.fromJson(response.data['data']['property']);
      state = state.copyWith(selectedProperty: property, isLoading: false);
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
        properties: state.properties.map((p) => p.id == id ? property : p).toList(),
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
