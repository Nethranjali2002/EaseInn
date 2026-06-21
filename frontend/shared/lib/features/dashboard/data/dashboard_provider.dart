import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';
import '../../booking/data/booking_provider.dart';
import '../../task/data/task_provider.dart';

class DashboardStats {
  final int totalRooms;
  final int availableRooms;
  final int bookedRooms;
  final int todayCheckIns;
  final int todayCheckOuts;
  final int activeBookings;
  final int pendingPayments;
  final int openTasks;
  final int overdueTasks;
  final double totalRevenue;
  final double todayRevenue;

  const DashboardStats({
    this.totalRooms = 0,
    this.availableRooms = 0,
    this.bookedRooms = 0,
    this.todayCheckIns = 0,
    this.todayCheckOuts = 0,
    this.activeBookings = 0,
    this.pendingPayments = 0,
    this.openTasks = 0,
    this.overdueTasks = 0,
    this.totalRevenue = 0,
    this.todayRevenue = 0,
  });
}

class DashboardState {
  final DashboardStats stats;
  final List<Booking> recentBookings;
  final List<TaskItem> urgentTasks;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.stats = const DashboardStats(),
    this.recentBookings = const [],
    this.urgentTasks = const [],
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    DashboardStats? stats,
    List<Booking>? recentBookings,
    List<TaskItem>? urgentTasks,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      stats: stats ?? this.stats,
      recentBookings: recentBookings ?? this.recentBookings,
      urgentTasks: urgentTasks ?? this.urgentTasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() => DashboardState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetchDashboard(String propertyId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _api.get('/properties/$propertyId/stats'),
        _api.get('/properties/$propertyId/bookings/stats'),
        _api.get('/properties/$propertyId/tasks/stats'),
        _api.get('/properties/$propertyId/payments/stats'),
        _api.get('/properties/$propertyId/bookings', queryParameters: {'limit': '5'}),
        _api.get('/properties/$propertyId/tasks', queryParameters: {'priority': 'urgent', 'limit': '5'}),
      ]);

      final propertyStats = results[0].data['data'];
      final bookingStats = results[1].data['data'];
      final taskStats = results[2].data['data'];
      final paymentStats = results[3].data['data'];
      final recentBookings = (results[4].data['data']['bookings'] as List)
          .map((b) => Booking.fromJson(b as Map<String, dynamic>))
          .toList();
      final urgentTasks = (results[5].data['data']['tasks'] as List)
          .map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        stats: DashboardStats(
          totalRooms: propertyStats['totalRooms'] ?? 0,
          availableRooms: propertyStats['availableRooms'] ?? 0,
          bookedRooms: propertyStats['bookedRooms'] ?? 0,
          todayCheckIns: bookingStats['todayCheckIns'] ?? 0,
          todayCheckOuts: bookingStats['todayCheckOuts'] ?? 0,
          activeBookings: bookingStats['activeBookings'] ?? 0,
          pendingPayments: bookingStats['pendingPayments'] ?? 0,
          openTasks: taskStats['openTasks'] ?? 0,
          overdueTasks: taskStats['overdueTasks'] ?? 0,
          totalRevenue: (paymentStats['totalRevenue'] ?? 0).toDouble(),
          todayRevenue: (paymentStats['todayRevenue'] ?? 0).toDouble(),
        ),
        recentBookings: recentBookings,
        urgentTasks: urgentTasks,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load dashboard');
    }
  }
}
