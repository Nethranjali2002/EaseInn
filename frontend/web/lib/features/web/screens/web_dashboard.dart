import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import 'web_notifications.dart';

class WebDashboardScreen extends ConsumerStatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  ConsumerState<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends ConsumerState<WebDashboardScreen> {
  String? _selectedPropertyId; // null represents "All Properties"
  bool _isLoading = false;

  // Single Property Stats
  Map<String, dynamic>? _propertyStats;
  Map<String, dynamic>? _bookingStats;
  Map<String, dynamic>? _taskStats;
  Map<String, dynamic>? _paymentStats;
  List<dynamic> _revenueData = [];
  List<dynamic> _recentBookings = [];
  List<dynamic> _recentTasks = [];
  Map<String, dynamic>? _pricingData;
  Map<String, dynamic>? _forecastData;
  int _aggTomorrowCheckIns = 0;
  int _aggCompletedTasks = 0;

  // Aggregated / Consolidated Stats (when "All Properties" is selected)
  int _aggTotalProperties = 0;
  int _aggActiveProperties = 0;
  int _aggTotalRooms = 0;
  int _aggAvailableRooms = 0;
  int _aggBookedRooms = 0;
  int _aggMaintenanceRooms = 0;
  int _aggActiveBookings = 0;
  int _aggCheckInsToday = 0;
  int _aggCheckOutsToday = 0;
  double _aggTotalRevenue = 0;
  double _aggTodayRevenue = 0;
  int _aggOpenTasks = 0;
  int _aggInProgressTasks = 0;
  int _aggOverdueTasks = 0;
  double _aggRating = 0;
  int _aggTotalReviews = 0;

  final List<Map<String, dynamic>> _aggPropertyPerformanceList = [];
  List<dynamic> _aggRecentBookings = [];
  List<dynamic> _aggRecentTasks = [];
  List<Map<String, dynamic>> _monthlyRevenueData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final propNotifier = ref.read(propertyProvider.notifier);
      await propNotifier.fetchProperties();
      final props = ref.read(propertyProvider).properties;
      if (props.isNotEmpty) {
        final user = ref.read(authProvider).user;
        if (user?.role == 'admin') {
          _selectedPropertyId = null; // All Properties
        } else {
          _selectedPropertyId = props.first.id;
        }
        _loadAll();
      }
    });
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiClientProvider);
    final props = ref.read(propertyProvider).properties;

    try {
      if (_selectedPropertyId == null) {
        // --- ALL PROPERTIES: Single consolidated API call ---
        final res = await api.get('/dashboard/stats');
        final d = res.data['data'] as Map<String, dynamic>;

        _aggTotalProperties = d['properties'] ?? 0;
        _aggActiveProperties = props.where((p) => p.isActive != false).length;
        _aggTotalRooms = d['totalRooms'] ?? 0;
        _aggAvailableRooms = d['availableRooms'] ?? 0;
        _aggBookedRooms = d['bookedRooms'] ?? 0;
        _aggMaintenanceRooms = d['maintenanceRooms'] ?? 0;
        _aggActiveBookings = d['activeBookings'] ?? 0;
        _aggCheckInsToday = d['todayCheckIns'] ?? 0;
        _aggCheckOutsToday = d['todayCheckOuts'] ?? 0;
        _aggTotalRevenue = (d['totalRevenue'] ?? 0).toDouble();
        _aggTodayRevenue = (d['todayRevenue'] ?? 0).toDouble();
        _aggOpenTasks = d['openTasks'] ?? 0;
        _aggInProgressTasks = d['inProgressTasks'] ?? 0;
        _aggOverdueTasks = d['overdueTasks'] ?? 0;
        _aggTomorrowCheckIns = d['tomorrowCheckIns'] ?? 0;
        _aggCompletedTasks = d['completedTasks'] ?? 0;
        _aggRating = (d['avgRating'] ?? 0).toDouble();
        _aggTotalReviews = d['totalReviews'] ?? 0;

        // Monthly revenue for forecast
        final mr = d['monthlyRevenue'] as List? ?? [];
        _monthlyRevenueData = mr.map<Map<String, dynamic>>((m) => {
          '_id': '${m['_id']?['year']}-${m['_id']?['month']?.toString().padLeft(2, '0')}',
          'total': m['total'],
        }).toList();

        // Set booking stats for pie chart
        _bookingStats = {
          'confirmedBookings': d['confirmedBookings'] ?? 0,
          'checkedInBookings': d['checkedInBookings'] ?? 0,
          'checkedOutBookings': d['checkedOutBookings'] ?? 0,
          'cancelledBookings': d['cancelledBookings'] ?? 0,
          'activeBookings': d['activeBookings'] ?? 0,
          'todayCheckIns': d['todayCheckIns'] ?? 0,
          'todayCheckOuts': d['todayCheckOuts'] ?? 0,
        };

        final perf = d['propertyPerformance'] as List? ?? [];
        _aggPropertyPerformanceList.clear();
        for (final p in perf) {
          _aggPropertyPerformanceList.add({
            'id': p['id'],
            'name': p['name'],
            'rooms': p['rooms'],
            'occupancy': '${(p['occupancy'] ?? 0).toStringAsFixed(0)}%',
            'revenue': (p['revenue'] ?? 0).toDouble(),
            'openTasks': p['openTasks'] ?? 0,
          });
        }

        // Use recent bookings and tasks from backend
        _aggRecentBookings = [];
        _aggRecentTasks = [];

        // Fetch recent bookings/tasks across all properties
        for (final p in props) {
          try {
            final bkRes = await api.get('/properties/${p.id}/bookings?limit=3');
            final bd = bkRes.data['data'];
            final bks = bd is Map ? (bd['bookings'] as List?) ?? [] : [];
            for (final b in bks) {
              if (b is Map<String, dynamic>) {
                _aggRecentBookings.add({...b, 'property': {'name': p.name}});
              }
            }
          } catch (_) {}
        }
        _aggRecentBookings.sort((a, b) {
          final aDate = a['createdAt'] ?? '';
          final bDate = b['createdAt'] ?? '';
          return bDate.compareTo(aDate);
        });
      } else {
        // --- SINGLE PROPERTY VIEW: Fire all calls independently ---
        Map<String, dynamic>? ps, bs, ts, payS;
        List<dynamic> revD = [], bkList = [], tkList = [];
        Map<String, dynamic>? prD, fcD;

        final results = await Future.wait([
          api.get('/properties/$_selectedPropertyId/stats').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/bookings/stats').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/tasks/stats').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/payments/stats').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/analytics/revenue').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/bookings?limit=5').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/tasks?limit=5').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/analytics/pricing').catchError((_) => null),
          api.get('/properties/$_selectedPropertyId/analytics/forecast').catchError((_) => null),
        ]);

        if (results[0] != null) ps = results[0]!.data['data'] as Map<String, dynamic>?;
        if (results[1] != null) bs = results[1]!.data['data'] as Map<String, dynamic>?;
        if (results[2] != null) ts = results[2]!.data['data'] as Map<String, dynamic>?;
        if (results[3] != null) payS = results[3]!.data['data'] as Map<String, dynamic>?;
        if (results[4] != null) revD = (results[4]!.data['data'] as List?) ?? [];
        if (results[5] != null) {
          final bd = results[5]!.data['data'];
          bkList = bd is Map ? (bd['bookings'] as List?) ?? [] : [];
        }
        if (results[6] != null) {
          final td = results[6]!.data['data'];
          tkList = td is Map ? (td['tasks'] as List?) ?? [] : [];
        }
        if (results[7] != null) prD = results[7]!.data['data'] as Map<String, dynamic>?;
        if (results[8] != null) fcD = results[8]!.data['data'] as Map<String, dynamic>?;

        _propertyStats = ps;
        _bookingStats = bs;
        _taskStats = ts;
        _paymentStats = payS;
        _revenueData = revD;
        _recentBookings = bkList.whereType<Map<String, dynamic>>().toList();
        _recentTasks = tkList.whereType<Map<String, dynamic>>().toList();
        _pricingData = prD;
        _forecastData = fcD;
      }

      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(propertyProvider).properties;
    final user = ref.watch(authProvider).user;
    final notifState = ref.watch(notificationProvider);
    final currentNotifications = notifState.notifications.take(5).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Operations Center',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    'What is happening in EaseInn right now?',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  if (props.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPropertyId,
                          hint: const Text('All Properties'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Properties'),
                            ),
                            ...props.map(
                              (p) => DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedPropertyId = v);
                            _loadAll();
                          },
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Analytics',
                    onPressed: _loadAll,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEVEL 1: QUICK KPI SECTION
                        _buildKPISection(user?.role ?? ''),
                        const SizedBox(height: 20),

                        // LEVEL 2: PROPERTY OVERVIEW (For multi-property)
                        if (_selectedPropertyId == null) ...[
                          _buildPropertyOverviewSection(),
                          const SizedBox(height: 20),
                        ],

                        // LEVEL 3: OPERATIONAL ACTIVITIES
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildRoomOccupancyWidget()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildBookingOverviewWidget()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTaskOverviewWidget()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildRoomOccupancyWidget(),
                              const SizedBox(height: 16),
                              _buildBookingOverviewWidget(),
                              const SizedBox(height: 16),
                              _buildTaskOverviewWidget(),
                            ],
                          ),
                        const SizedBox(height: 20),

                        // LEVEL 4: RECENT ACTIVITY & METRIC LOGS
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildRecentBookingsWidget(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _buildRecentTasksWidget(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _buildNotificationsWidget(
                                  currentNotifications,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildRecentBookingsWidget(),
                              const SizedBox(height: 16),
                              _buildRecentTasksWidget(),
                              const SizedBox(height: 16),
                              _buildNotificationsWidget(currentNotifications),
                            ],
                          ),
                        const SizedBox(height: 20),

                        // LEVEL 5: ANALYTICS & REVENUE TRENDS
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildRevenueTrendWidget()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildCalendarSummaryWidget()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildRevenueTrendWidget(),
                              const SizedBox(height: 16),
                              _buildCalendarSummaryWidget(),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // LEVEL 6: AI INTELLIGENCE LAYER
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF0EA5E9)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.psychology, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text('AI Powered', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Intelligent Revenue Optimizer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildAIPricingSuggestionsWidget(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _buildAIDemandForecastWidget(),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildAIPricingSuggestionsWidget(),
                              const SizedBox(height: 16),
                              _buildAIDemandForecastWidget(),
                            ],
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- 1. QUICK KPI SECTION ---
  Widget _buildKPISection(String role) {
    final propCountVal = _selectedPropertyId == null
        ? '$_aggTotalProperties Properties'
        : '1 Property';
    final propSub = _selectedPropertyId == null
        ? '$_aggActiveProperties active resorts'
        : 'Active';

    final totalRooms = _selectedPropertyId == null
        ? _aggTotalRooms
        : (int.tryParse(_propertyStats?['totalRooms']?.toString() ?? '') ?? 0);
    final availRooms = _selectedPropertyId == null
        ? _aggAvailableRooms
        : (int.tryParse(_propertyStats?['availableRooms']?.toString() ?? '') ??
              0);
    final bookedRooms = _selectedPropertyId == null
        ? _aggBookedRooms
        : (int.tryParse(_propertyStats?['bookedRooms']?.toString() ?? '') ?? 0);
    final maintRooms = _selectedPropertyId == null
        ? _aggMaintenanceRooms
        : (int.tryParse(
                _propertyStats?['maintenanceRooms']?.toString() ?? '',
              ) ??
              0);

    final activeBook = _selectedPropertyId == null
        ? _aggActiveBookings
        : (int.tryParse(_bookingStats?['activeBookings']?.toString() ?? '') ??
              0);
    final checkIns = _selectedPropertyId == null
        ? _aggCheckInsToday
        : (int.tryParse(_bookingStats?['todayCheckIns']?.toString() ?? '') ??
              0);
    final checkOuts = _selectedPropertyId == null
        ? _aggCheckOutsToday
        : (int.tryParse(_bookingStats?['todayCheckOuts']?.toString() ?? '') ??
              0);

    final totalRev = _selectedPropertyId == null
        ? _aggTotalRevenue
        : (double.tryParse(_paymentStats?['totalRevenue']?.toString() ?? '') ??
              0.0);
    final todayRev = _selectedPropertyId == null
        ? _aggTodayRevenue
        : (double.tryParse(_paymentStats?['todayRevenue']?.toString() ?? '') ??
              0.0);

    final openTasks = _selectedPropertyId == null
        ? _aggOpenTasks
        : (int.tryParse(_taskStats?['openTasks']?.toString() ?? '') ?? 0);
    final inProgress = _selectedPropertyId == null
        ? _aggInProgressTasks
        : (int.tryParse(_taskStats?['inProgressTasks']?.toString() ?? '') ?? 0);
    final overdue = _selectedPropertyId == null
        ? _aggOverdueTasks
        : (int.tryParse(_taskStats?['overdueTasks']?.toString() ?? '') ?? 0);

    final rating = _selectedPropertyId == null ? _aggRating : _aggRating;
    final totalReviews = _selectedPropertyId == null ? _aggTotalReviews : _aggTotalReviews;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 6;
        if (constraints.maxWidth <= 750) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth <= 1200) {
          crossAxisCount = 3;
        }

        final double itemWidth =
            (constraints.maxWidth - (12 * (crossAxisCount - 1))) /
            crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildKPIItem(
                "Properties",
                propCountVal,
                propSub,
                Icons.business,
                Colors.blue,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKPIItem(
                "Total Rooms",
                "$totalRooms Rooms",
                "${availRooms.toInt()} Avail, ${bookedRooms.toInt()} Booked, ${maintRooms.toInt()} Maint",
                Icons.king_bed,
                Colors.teal,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKPIItem(
                "Active Bookings",
                "$activeBook Bookings",
                "$checkIns check-ins, $checkOuts check-outs",
                Icons.book_online,
                Colors.orange,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKPIItem(
                "Revenue",
                "LKR ${NumberFormat('#,###').format(totalRev)}",
                "Today: LKR ${NumberFormat('#,###').format(todayRev)}",
                Icons.payments,
                Colors.green,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKPIItem(
                "Open Tasks",
                "$openTasks Tasks",
                "$inProgress progress, $overdue overdue",
                Icons.task_alt,
                Colors.purple,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildKPIItem(
                "Guest Rating",
                "$rating ★",
                "$totalReviews reviews",
                Icons.star,
                Colors.amber,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKPIItem(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. PROPERTY OVERVIEW PERFORMANCE SECTION ---
  Widget _buildPropertyOverviewSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Property Performance Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _aggPropertyPerformanceList.length,
              itemBuilder: (ctx, i) {
                final item = _aggPropertyPerformanceList[i];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(Icons.business_outlined, color: Colors.blue),
                  ),
                  title: Text(
                    item['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Rooms: ${item['rooms']} • Occupancy: ${item['occupancy']}',
                  ),
                  trailing: Text(
                    'LKR ${NumberFormat('#,###').format(item['revenue'] ?? 0)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedPropertyId = item['id'];
                    });
                    _loadAll();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. ROOM OCCUPANCY WIDGET ---
  Widget _buildRoomOccupancyWidget() {
    final available = _selectedPropertyId == null
        ? _aggAvailableRooms.toDouble()
        : (double.tryParse(
                _propertyStats?['availableRooms']?.toString() ?? '',
              ) ??
              0.0);
    final booked = _selectedPropertyId == null
        ? _aggBookedRooms.toDouble()
        : (double.tryParse(_propertyStats?['bookedRooms']?.toString() ?? '') ??
              0.0);
    final maintenance = _selectedPropertyId == null
        ? _aggMaintenanceRooms.toDouble()
        : (double.tryParse(
                _propertyStats?['maintenanceRooms']?.toString() ?? '',
              ) ??
              0.0);
    final total = available + booked + maintenance;
    final rate = total > 0 ? (booked / total * 100) : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Room Occupancy status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    PieChartSectionData(
                      value: available > 0 ? available : 1,
                      color: Colors.green,
                      title: '${available.toInt()}',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: booked > 0 ? booked : 0,
                      color: Colors.blue,
                      title: '${booked.toInt()}',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: maintenance > 0 ? maintenance : 0,
                      color: Colors.orange,
                      title: '${maintenance.toInt()}',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LegendDot(Colors.green, 'Available: ${available.toInt()}'),
                _LegendDot(Colors.blue, 'Booked: ${booked.toInt()}'),
                _LegendDot(Colors.orange, 'Maint: ${maintenance.toInt()}'),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Occupancy: ${rate.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. BOOKING OVERVIEW WIDGET ---
  Widget _buildBookingOverviewWidget() {
    final confirmed = _selectedPropertyId == null
        ? (_bookingStats != null ? (_bookingStats!['confirmedBookings'] ?? 0) : 0)
        : (_bookingStats != null ? (_bookingStats!['confirmedBookings'] ?? 0) : _recentBookings.where((b) => b is Map && b['bookingStatus'] == 'confirmed').length);
    final checkedIn = _selectedPropertyId == null
        ? (_bookingStats != null ? (_bookingStats!['checkedInBookings'] ?? 0) : 0)
        : (_bookingStats != null ? (_bookingStats!['checkedInBookings'] ?? 0) : _recentBookings.where((b) => b is Map && b['bookingStatus'] == 'checked-in').length);
    final checkedOut = _selectedPropertyId == null
        ? (_bookingStats != null ? (_bookingStats!['checkedOutBookings'] ?? 0) : 0)
        : (_bookingStats != null ? (_bookingStats!['checkedOutBookings'] ?? 0) : _recentBookings.where((b) => b is Map && b['bookingStatus'] == 'checked-out').length);
    final cancelled = _selectedPropertyId == null
        ? (_bookingStats != null ? (_bookingStats!['cancelledBookings'] ?? 0) : 0)
        : (_bookingStats != null ? (_bookingStats!['cancelledBookings'] ?? 0) : _recentBookings.where((b) => b is Map && b['bookingStatus'] == 'cancelled').length);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking Lifecycle split',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    PieChartSectionData(
                      value: confirmed.toDouble(),
                      color: Colors.blue,
                      title: '$confirmed',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: checkedIn.toDouble(),
                      color: Colors.green,
                      title: '$checkedIn',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: checkedOut.toDouble(),
                      color: Colors.grey,
                      title: '$checkedOut',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: cancelled.toDouble(),
                      color: Colors.red,
                      title: '$cancelled',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _LegendDot(Colors.blue, 'Conf: $confirmed'),
                _LegendDot(Colors.green, 'In: $checkedIn'),
                _LegendDot(Colors.grey, 'Out: $checkedOut'),
                _LegendDot(Colors.red, 'Cancel: $cancelled'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 5. TASK OVERVIEW WIDGET ---
  Widget _buildTaskOverviewWidget() {
    final open = _selectedPropertyId == null
        ? _aggOpenTasks.toDouble()
        : (double.tryParse(_taskStats?['openTasks']?.toString() ?? '') ?? 0.0);
    final inProgress = _selectedPropertyId == null
        ? _aggInProgressTasks.toDouble()
        : (double.tryParse(_taskStats?['inProgressTasks']?.toString() ?? '') ??
              0.0);
    final overdue = _selectedPropertyId == null
        ? _aggOverdueTasks.toDouble()
        : (double.tryParse(_taskStats?['overdueTasks']?.toString() ?? '') ??
              0.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Open Operational Tasks',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    PieChartSectionData(
                      value: open > 0 ? open : 1,
                      color: Colors.orange,
                      title: '${open.toInt()}',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: inProgress > 0 ? inProgress : 0,
                      color: Colors.blue,
                      title: '${inProgress.toInt()}',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    PieChartSectionData(
                      value: overdue > 0 ? overdue : 0,
                      color: Colors.red,
                      title: '${overdue.toInt()}',
                      radius: 35,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _LegendDot(Colors.orange, 'Open: ${open.toInt()}'),
                _LegendDot(Colors.blue, 'Progress: ${inProgress.toInt()}'),
                _LegendDot(Colors.red, 'Overdue: ${overdue.toInt()}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. RECENT BOOKINGS WIDGET ---
  Widget _buildRecentBookingsWidget() {
    final list = _selectedPropertyId == null
        ? _aggRecentBookings
        : _recentBookings;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Bookings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/web/bookings'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No bookings available.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.take(5).length,
                itemBuilder: (ctx, i) {
                  final b = list[i];
                  if (b == null || b is! Map) return const SizedBox();
                  final guest = b['guest']?['name'] ?? '-';
                  final room = b['room']?['roomNumber'] ?? '-';
                  final status = b['bookingStatus'] ?? 'confirmed';
                  final color = status == 'checked-in'
                      ? Colors.green
                      : status == 'confirmed'
                      ? Colors.blue
                      : Colors.grey;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(Icons.person, color: color, size: 16),
                    ),
                    title: Text(
                      guest,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text('Room $room${b['property'] is Map ? ' • ${b['property']['name'] ?? ''}' : ''}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- 7. RECENT TASKS WIDGET ---
  Widget _buildRecentTasksWidget() {
    final list = _selectedPropertyId == null ? _aggRecentTasks : _recentTasks;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Staff Tasks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/web/tasks'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No tasks recorded.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.take(5).length,
                itemBuilder: (ctx, i) {
                  final t = list[i];
                  if (t == null || t is! Map) return const SizedBox();
                  final title = t['title'] ?? '-';
                  final staff = t['assignedTo']?['name'] ?? 'Unassigned';
                  final status = t['status'] ?? 'open';
                  final color = status == 'completed'
                      ? Colors.green
                      : status == 'in-progress'
                      ? Colors.blue
                      : Colors.orange;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(
                        Icons.cleaning_services,
                        color: color,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Staff: $staff'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- 8. RECENT NOTIFICATIONS WIDGET ---
  Widget _buildNotificationsWidget(List<NotificationItem> list) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Alerts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/web/notifications'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No new alerts.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final n = list[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: iconForType(n.type),
                    title: Text(
                      n.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      n.message,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      timeAgo(n.createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // --- 9. REVENUE TREND WIDGET ---
  Widget _buildRevenueTrendWidget() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Trend Analysis',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: _revenueData.isEmpty
                  ? const Center(
                      child: Text('No historical revenue trend available.'),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY:
                            _revenueData
                                .map(
                                  (r) =>
                                      double.tryParse(
                                        r['total']?.toString() ?? '',
                                      ) ??
                                      0.0,
                                )
                                .fold<double>(0, (a, b) => a > b ? a : b) *
                            1.2,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, m) {
                                final idx = v.toInt();
                                if (idx < _revenueData.length) {
                                  final label = _revenueData[idx]['_id'] ?? '';
                                  return Text(
                                    label.length > 7
                                        ? label.substring(5)
                                        : label,
                                    style: const TextStyle(fontSize: 9),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _revenueData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY:
                                    double.tryParse(
                                      entry.value['total']?.toString() ?? '',
                                    ) ??
                                    0.0,
                                color: const Color(0xFF2E7D32),
                                width: 18,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 10. CALENDAR SUMMARY WIDGET ---
  Widget _buildCalendarSummaryWidget() {
    final checkIns = _selectedPropertyId == null
        ? _aggCheckInsToday
        : (int.tryParse(_bookingStats?['todayCheckIns']?.toString() ?? '') ??
              0);
    final checkOuts = _selectedPropertyId == null
        ? _aggCheckOutsToday
        : (int.tryParse(_bookingStats?['todayCheckOuts']?.toString() ?? '') ??
              0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Operational Planner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/web/calendar'),
                  child: const Text('Full Calendar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _calendarStatRow(
              'Arrivals / Check-ins Today',
              '$checkIns Guests',
              Colors.green,
            ),
            const Divider(height: 20),
            _calendarStatRow(
              'Departures / Check-outs Today',
              '$checkOuts Departures',
              Colors.blueGrey,
            ),
            const Divider(height: 20),
            _calendarStatRow(
              'Upcoming Check-ins Tomorrow',
              '${_selectedPropertyId == null ? _aggTomorrowCheckIns : (checkIns > 0 ? checkIns : 0)} Reservations',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarStatRow(String label, String val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightTile(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }

  // --- 11. AI PRICING SUGGESTIONS ---
  Widget _buildAIPricingSuggestionsWidget() {
    if (_selectedPropertyId == null) {
      final totalRooms = _aggTotalRooms;
      final occupancyRate = totalRooms > 0 ? (_aggActiveBookings / totalRooms * 100).round() : 0;
      final avgRevenuePerRoom = totalRooms > 0 ? (_aggTotalRevenue / totalRooms).round() : 0;
      final taskCompletionRate = (_aggOpenTasks + _aggInProgressTasks + _aggCompletedTasks) > 0
          ? (_aggCompletedTasks / (_aggOpenTasks + _aggInProgressTasks + _aggCompletedTasks) * 100).round()
          : 0;
      final demandLevel = occupancyRate > 70 ? 'High' : occupancyRate > 40 ? 'Medium' : 'Low';
      final demandColor = demandLevel == 'High' ? Colors.green : demandLevel == 'Medium' ? Colors.orange : Colors.red;
      final peakSeason = DateTime.now().month >= 11 || DateTime.now().month <= 1 || (DateTime.now().month >= 6 && DateTime.now().month <= 8);
      final weekend = DateTime.now().weekday >= 5;
      final confidence = (0.55 + (occupancyRate / 200.0)).clamp(0.55, 0.92);
      final suggestedIncrease = demandLevel == 'High' ? 20 : demandLevel == 'Medium' ? 8 : -10;

      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('AI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Revenue Intelligence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                  const Spacer(),
                  Text('${(confidence * 100).round()}% confidence', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 16),
              _buildAIMetricRow(Icons.trending_up, 'Occupancy Rate', '$occupancyRate%',
                  occupancyRate > 70 ? Colors.green : occupancyRate > 40 ? Colors.orange : Colors.red,
                  occupancyRate / 100.0),
              const SizedBox(height: 10),
              _buildAIMetricRow(Icons.payments, 'Revenue / Room', 'LKR ${NumberFormat('#,###').format(avgRevenuePerRoom)}',
                  demandColor, confidence),
              const SizedBox(height: 10),
              _buildAIMetricRow(Icons.task_alt, 'Task Completion', '$taskCompletionRate%',
                  taskCompletionRate > 70 ? Colors.green : Colors.orange,
                  taskCompletionRate / 100.0),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildAIBadge(peakSeason ? '📅 Peak Season' : '📅 Off-Peak', peakSeason ? Colors.green : Colors.grey),
                  const SizedBox(width: 8),
                  _buildAIBadge(weekend ? '🌟 Weekend' : '📋 Weekday', weekend ? Colors.orange : Colors.blueGrey),
                  const SizedBox(width: 8),
                  _buildAIBadge('📊 ${demandLevel} Demand', demandColor),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6366F1).withOpacity(0.08), const Color(0xFF8B5CF6).withOpacity(0.04)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Color(0xFF6366F1), size: 16),
                        SizedBox(width: 6),
                        Text('AI Recommendation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestedIncrease > 0
                          ? '$demandLevel demand across $totalRooms rooms. Recommend raising base rates by $suggestedIncrease% to maximize RevPAR. Focus upselling on premium room types.'
                          : 'Occupancy is below target. Consider promotional rates (${suggestedIncrease.abs()}% discount), package deals, or targeted marketing to drive bookings.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final suggestions = (_pricingData?['suggestions'] as List?) ?? [];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Dynamic pricing suggestions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            if (suggestions.isEmpty)
              const Center(child: Text('No pricing suggestions generated yet.'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestions.take(3).length,
                itemBuilder: (ctx, i) {
                  final s = suggestions[i];
                  return Card(
                    color: const Color(0xFFF8FAFC),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Room ${s['roomNumber'] ?? '-'} (${s['roomType'] ?? '-'})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                s['basedOn'] ?? '',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Current: LKR ${NumberFormat('#,###').format(s['currentPrice'])}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                'Suggested: LKR ${NumberFormat('#,###').format(s['suggestedPrice'])}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIDemandForecastWidget() {
    // Monthly revenue data for chart
    final monthlyData = _selectedPropertyId == null ? _monthlyRevenueData : _revenueData.map<Map<String, dynamic>>((r) => r as Map<String, dynamic>).toList();
    final avgMonthly = monthlyData.isNotEmpty
        ? monthlyData.map((m) => ((m['total'] ?? 0) as num).toDouble()).reduce((a, b) => a + b) / monthlyData.length
        : 0.0;
    final next3Rev = avgMonthly * 3;
    final occupancyRate = _aggTotalRooms > 0 ? (_aggActiveBookings / _aggTotalRooms * 100).round() : 0;

    // Per-property forecast from backend
    final forecast = (_forecastData?['forecast'] as List?) ?? [];
    final historical = (_forecastData?['historical'] as List?) ?? [];
    final trend = _forecastData?['trend'] ?? '0%';
    final trendUp = trend.toString().startsWith('-') == false && trend != '0%';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_outlined, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('FORECAST', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Demand Forecast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                const Spacer(),
                if (_selectedPropertyId != null && trend != '0%')
                  Row(
                    children: [
                      Icon(trendUp ? Icons.trending_up : Icons.trending_down,
                          size: 14, color: trendUp ? Colors.green : Colors.red),
                      const SizedBox(width: 2),
                      Text(trend, style: TextStyle(fontSize: 11, color: trendUp ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Revenue spark chart
            if (monthlyData.isNotEmpty) ...[
              SizedBox(
                height: 60,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: monthlyData.map((r) => ((r['total'] ?? 0) as num).toDouble()).fold<double>(0, (a, b) => a > b ? a : b) * 1.3,
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: monthlyData.asMap().entries.map((e) => BarChartGroupData(
                      x: e.key,
                      barRods: [BarChartRodData(
                        toY: ((e.value['total'] ?? 0) as num).toDouble(),
                        color: const Color(0xFF0EA5E9),
                        width: 10,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      )],
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildAIMetricRow(Icons.show_chart, 'Avg Monthly Revenue', 'LKR ${NumberFormat('#,###').format(avgMonthly)}',
                trendUp ? Colors.green : Colors.orange, 0.7),
            const SizedBox(height: 8),
            _buildAIMetricRow(Icons.rocket_launch, 'Next 3 Months Projected', 'LKR ${NumberFormat('#,###').format(next3Rev)}',
                Colors.blue, 0.65),
            const SizedBox(height: 8),
            _buildAIMetricRow(Icons.hotel, 'Current Occupancy', '$occupancyRate%',
                occupancyRate > 60 ? Colors.green : Colors.orange, occupancyRate / 100.0),
            if (forecast.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text('Month-wise Predictions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              ...forecast.take(3).map((f) {
                final conf = ((f['confidence'] ?? 0.5) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(f['month'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      Text('${f['predictedBookings']} bookings', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text('LKR ${NumberFormat('#,###').format(f['predictedRevenue'])}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(width: 6),
                      Text('($conf%)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights, color: Color(0xFF0EA5E9), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedPropertyId != null
                          ? (trendUp ? 'Positive booking trend (+$trend). Revenue momentum is building — maintain current strategy and consider upsell packages.' : 'Bookings are flat or declining. Run targeted promotions and review pricing to recapture demand.')
                          : (avgMonthly > 0 ? 'Portfolio revenue averaging LKR ${NumberFormat('#,###').format(avgMonthly)}/month. Consider cross-property packages to drive multi-night bookings.' : 'Add revenue data by processing payments to unlock AI forecasting insights.'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIMetricRow(IconData icon, String label, String value, Color color, double progress) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
