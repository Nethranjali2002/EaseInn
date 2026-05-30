import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/api/api_client.dart';
import '../../auth/data/auth_provider.dart';
import '../../property/data/property_provider.dart';

class WebDashboardScreen extends ConsumerStatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  ConsumerState<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends ConsumerState<WebDashboardScreen> {
  String? _selectedPropertyId;
  bool _isLoading = false;

  Map<String, dynamic>? _propertyStats;
  Map<String, dynamic>? _bookingStats;
  Map<String, dynamic>? _taskStats;
  Map<String, dynamic>? _paymentStats;
  Map<String, dynamic>? _occupancy;
  List<dynamic> _revenueData = [];
  List<dynamic> _roomPerformance = [];
  List<dynamic> _recentBookings = [];
  List<dynamic> _recentTasks = [];

  // New Analytics variables integrated directly to Dashboard
  Map<String, dynamic>? _consolidated;
  Map<String, dynamic>? _pricingData;
  Map<String, dynamic>? _forecastData;
  List<dynamic> _taskPerformance = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final propNotifier = ref.read(propertyProvider.notifier);
      await propNotifier.fetchProperties();
      final props = ref.read(propertyProvider).properties;
      if (props.isNotEmpty) {
        _selectedPropertyId = props.first.id;
        final api = ref.read(apiClientProvider);
        for (final p in props) {
          try {
            final res = await api.get('/properties/${p.id}/stats');
            final totalRooms = res.data['data']['totalRooms'] ?? 0;
            if (totalRooms > 0) {
              _selectedPropertyId = p.id;
              break;
            }
          } catch (_) {}
        }
        _loadAll();
      }
    });
  }

  Future<void> _loadAll() async {
    if (_selectedPropertyId == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final user = ref.read(authProvider).user;

      final results = await Future.wait([
        api.get('/properties/$_selectedPropertyId/stats'),
        api.get('/properties/$_selectedPropertyId/bookings/stats'),
        api.get('/properties/$_selectedPropertyId/tasks/stats'),
        api.get('/properties/$_selectedPropertyId/payments/stats'),
        api.get('/properties/$_selectedPropertyId/analytics/occupancy'),
        api.get('/properties/$_selectedPropertyId/analytics/revenue'),
        api.get('/properties/$_selectedPropertyId/analytics/rooms'),
        api.get('/properties/$_selectedPropertyId/bookings?limit=5'),
        api.get('/properties/$_selectedPropertyId/tasks?limit=5'),
        api.get('/properties/$_selectedPropertyId/analytics/pricing'),
        api.get('/properties/$_selectedPropertyId/analytics/forecast'),
        api.get('/properties/$_selectedPropertyId/analytics/tasks'),
      ]);

      Map<String, dynamic>? consolidatedData;
      if (user?.role == 'admin') {
        try {
          final res = await api.get('/analytics/consolidated');
          consolidatedData = res.data['data'];
        } catch (_) {}
      }

      setState(() {
        _propertyStats = results[0].data['data'];
        _bookingStats = results[1].data['data'];
        _taskStats = results[2].data['data'];
        _paymentStats = results[3].data['data'];
        _occupancy = results[4].data['data'];
        _revenueData = (results[5].data['data'] as List?) ?? [];
        _roomPerformance = (results[6].data['data'] as List?) ?? [];
        _recentBookings = (results[7].data['data']['bookings'] as List?) ?? [];
        _recentTasks = (results[8].data['data']['tasks'] as List?) ?? [];
        _pricingData = results[9].data['data'];
        _forecastData = results[10].data['data'];
        _taskPerformance = (results[11].data['data'] as List?) ?? [];
        _consolidated = consolidatedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(propertyProvider).properties;
    final auth = ref.watch(authProvider);
    final user = auth.user;

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;
    final isTablet = screenWidth > 750 && screenWidth <= 1100;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, ${user?.name ?? ''}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Here\'s your property overview', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Row(
                children: [
                  if (props.isNotEmpty)
                    DropdownButton<String>(
                      value: _selectedPropertyId,
                      items: props.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) { setState(() => _selectedPropertyId = v); _loadAll(); },
                    ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
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
                        if (user?.role == 'admin' && _consolidated != null) ...[
                          _buildConsolidatedOverview(screenWidth),
                          const SizedBox(height: 20),
                        ],
                        _buildStatCards(screenWidth, user?.role ?? ''),
                        const SizedBox(height: 20),
                        
                        // First chart row (Revenue & Occupancy)
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildRevenueChart()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildOccupancyChart()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildRevenueChart(),
                              const SizedBox(height: 16),
                              _buildOccupancyChart(),
                            ],
                          ),
                        const SizedBox(height: 20),

                        // Second chart row (Room type, Tasks, Booking status)
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildRoomTypeChart()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildTaskChart()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildBookingStatusChart()),
                            ],
                          )
                        else if (isTablet)
                          Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildRoomTypeChart()),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTaskChart()),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildBookingStatusChart(),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildRoomTypeChart(),
                              const SizedBox(height: 16),
                              _buildTaskChart(),
                              const SizedBox(height: 16),
                              _buildBookingStatusChart(),
                            ],
                          ),
                        const SizedBox(height: 20),

                        // Recent bookings & tasks
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildRecentBookings()),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: _buildRecentTasks()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildRecentBookings(),
                              const SizedBox(height: 16),
                              _buildRecentTasks(),
                            ],
                          ),
                        const SizedBox(height: 24),
                        
                        // New Section: AI Insights & Advanced Analytics (Admin Only)
                        if (user?.role == 'admin') ...[
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'AI Analytics & Insights',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildPricingCard()),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: _buildForecastCard()),
                              ],
                            )
                          else
                            Column(
                              children: [
                                _buildPricingCard(),
                                const SizedBox(height: 16),
                                _buildForecastCard(),
                              ],
                            ),
                          const SizedBox(height: 20),
                        ],
                        
                        // Section: Operations Performance (Admin & Manager)
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          'Operations Performance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildTaskPerformanceCard()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildRoomPerformanceCard()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildTaskPerformanceCard(),
                              const SizedBox(height: 16),
                              _buildRoomPerformanceCard(),
                            ],
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsolidatedOverview(double width) {
    if (_consolidated == null) return const SizedBox();
    final performance = (_consolidated!['propertyPerformance'] as List? ?? []);
    final colsCount = width > 1200 ? 4 : width > 800 ? 2 : 1;
    final aspect = width > 1200 ? 2.2 : width > 800 ? 2.5 : 3.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cross-Property Consolidated Stats',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: colsCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: aspect,
          children: [
            _OverviewCard('Total Properties', '${_consolidated!['totalProperties'] ?? 0}', Icons.business, Colors.blue),
            _OverviewCard('Total Rooms', '${_consolidated!['totalRooms'] ?? 0}', Icons.hotel, Colors.green),
            _OverviewCard('Total Bookings', '${_consolidated!['totalBookings'] ?? 0}', Icons.book_online, Colors.orange),
            _OverviewCard('Total Revenue', 'LKR ${((_consolidated!['totalRevenue'] ?? 0) as num).toStringAsFixed(0)}', Icons.attach_money, Colors.purple),
          ],
        ),
        const SizedBox(height: 16),
        Text('Revenue by Property', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: performance.length,
          itemBuilder: (ctx, i) {
            final p = performance[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                  child: Text(
                    p['name'] != null && (p['name'] as String).isNotEmpty ? (p['name'] as String)[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(p['city'] ?? ''),
                trailing: Text(
                  'LKR ${((p['revenue'] ?? 0) as num).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCards(double width, String role) {
    final colsCount = width > 1200 ? 4 : width > 800 ? 2 : 1;
    final aspect = width > 1200 ? 2.0 : width > 800 ? 2.5 : 3.0;
    final isAdmin = role == 'admin';

    return GridView.count(
      crossAxisCount: colsCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: aspect,
      children: [
        _StatCard('Total Rooms', '${_propertyStats?['totalRooms'] ?? 0}', Icons.hotel, Colors.blue, '${_propertyStats?['availableRooms'] ?? 0} available'),
        _StatCard('Active Bookings', '${_bookingStats?['activeBookings'] ?? 0}', Icons.book_online, Colors.orange, '${_bookingStats?['todayCheckIns'] ?? 0} check-ins today'),
        _StatCard('Open Tasks', '${_taskStats?['openTasks'] ?? 0}', Icons.task_alt, Colors.purple, '${_taskStats?['overdueTasks'] ?? 0} overdue'),
        if (isAdmin)
          _StatCard('Revenue', 'LKR ${((_paymentStats?['totalRevenue'] ?? 0) as num).toStringAsFixed(0)}', Icons.attach_money, Colors.green, 'Today: LKR ${((_paymentStats?['todayRevenue'] ?? 0) as num).toStringAsFixed(0)}'),
        if (!isAdmin)
          _StatCard('Check-ins Today', '${_bookingStats?['todayCheckIns'] ?? 0}', Icons.login, Colors.teal, '${_bookingStats?['todayCheckOuts'] ?? 0} check-outs today'),
      ],
    );
  }

  Widget _buildRevenueChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Revenue Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _revenueData.isEmpty
                  ? const Center(child: Text('No revenue data'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _revenueData.map((r) => double.tryParse(r['total']?.toString() ?? '') ?? 0.0).fold<double>(0, (a, b) => a > b ? a : b) * 1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                'LKR ${rod.toY.toStringAsFixed(0)}',
                                const TextStyle(color: Colors.white, fontSize: 12),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < _revenueData.length) {
                                  final label = _revenueData[idx]['_id'] ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(label.length > 7 ? label.substring(5) : label, style: const TextStyle(fontSize: 10)),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                if (value >= 1000) return Text('${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10));
                                return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: (_revenueData.map((r) => double.tryParse(r['total']?.toString() ?? '') ?? 0.0).fold<double>(0, (a, b) => a > b ? a : b) / 4).clamp(1, double.infinity),
                        ),
                        barGroups: _revenueData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: double.tryParse(entry.value['total']?.toString() ?? '') ?? 0.0,
                                color: const Color(0xFF4CAF50),
                                width: 20,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

  Widget _buildOccupancyChart() {
    final rate = double.tryParse(_occupancy?['occupancyRate']?.toString() ?? '') ?? 0.0;
    final available = double.tryParse(_propertyStats?['availableRooms']?.toString() ?? '') ?? 0.0;
    final booked = double.tryParse(_propertyStats?['bookedRooms']?.toString() ?? '') ?? 0.0;
    final maintenance = double.tryParse(_propertyStats?['maintenanceRooms']?.toString() ?? '') ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Occupancy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    if (available > 0)
                      PieChartSectionData(
                        value: available,
                        color: const Color(0xFF4CAF50),
                        title: '${available.toInt()}',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    if (booked > 0)
                      PieChartSectionData(
                        value: booked,
                        color: const Color(0xFF2196F3),
                        title: '${booked.toInt()}',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    if (maintenance > 0)
                      PieChartSectionData(
                        value: maintenance,
                        color: const Color(0xFFFF9800),
                        title: '${maintenance.toInt()}',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(Colors.green, 'Available'),
                _LegendItem(Colors.blue, 'Booked'),
                _LegendItem(Colors.orange, 'Maintenance'),
              ],
            ),
            const SizedBox(height: 8),
            Center(child: Text('Occupancy: ${rate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTypeChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Type Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: _roomPerformance.isEmpty
                  ? const Center(child: Text('No data'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _roomPerformance.map((r) => double.tryParse(r['revenue']?.toString() ?? '') ?? 0.0).fold<double>(0, (a, b) => a > b ? a : b) * 1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem('LKR ${rod.toY.toStringAsFixed(0)}', const TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, m) {
                                final idx = v.toInt();
                                if (idx < _roomPerformance.length) {
                                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_roomPerformance[idx]['_id']}', style: const TextStyle(fontSize: 10)));
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _roomPerformance.asMap().entries.map((entry) {
                          final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red, Colors.teal];
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: double.tryParse(entry.value['revenue']?.toString() ?? '') ?? 0.0,
                                color: colors[entry.key % colors.length],
                                width: 24,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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

  Widget _buildTaskChart() {
    final open = double.tryParse(_taskStats?['openTasks']?.toString() ?? '') ?? 0.0;
    final inProgress = double.tryParse(_taskStats?['inProgressTasks']?.toString() ?? '') ?? 0.0;
    final completed = double.tryParse(_taskStats?['completedTasks']?.toString() ?? '') ?? 0.0;
    final overdue = double.tryParse(_taskStats?['overdueTasks']?.toString() ?? '') ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Task Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    if (open > 0) PieChartSectionData(value: open, color: Colors.orange, title: '${open.toInt()}', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (inProgress > 0) PieChartSectionData(value: inProgress, color: Colors.blue, title: '${inProgress.toInt()}', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (completed > 0) PieChartSectionData(value: completed, color: Colors.green, title: '${completed.toInt()}', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (overdue > 0) PieChartSectionData(value: overdue, color: Colors.red, title: '${overdue.toInt()}', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendItem(Colors.orange, 'Open'),
                _LegendItem(Colors.blue, 'In Progress'),
                _LegendItem(Colors.green, 'Completed'),
                _LegendItem(Colors.red, 'Overdue'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingStatusChart() {
    final confirmed = _recentBookings.where((b) => b['bookingStatus'] == 'confirmed').length;
    final checkedIn = _recentBookings.where((b) => b['bookingStatus'] == 'checked-in').length;
    final checkedOut = _recentBookings.where((b) => b['bookingStatus'] == 'checked-out').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bookings Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 35,
                  sections: [
                    if (confirmed > 0) PieChartSectionData(value: confirmed.toDouble(), color: const Color(0xFF2196F3), title: '$confirmed', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (checkedIn > 0) PieChartSectionData(value: checkedIn.toDouble(), color: const Color(0xFF4CAF50), title: '$checkedIn', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (checkedOut > 0) PieChartSectionData(value: checkedOut.toDouble(), color: Colors.grey, title: '$checkedOut', radius: 45, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendItem(Colors.blue, 'Confirmed'),
                _LegendItem(Colors.green, 'Checked In'),
                _LegendItem(Colors.grey, 'Checked Out'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBookings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Bookings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => context.go('/web/bookings'), child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentBookings.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No bookings')))
            else
              ..._recentBookings.map((b) {
                final guest = b['guest'];
                final room = b['room'];
                final status = b['bookingStatus'] ?? '';
                final color = status == 'checked-in' ? Colors.green : status == 'confirmed' ? Colors.blue : Colors.grey;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(Icons.person, color: color, size: 18),
                  ),
                  title: Text(guest?['name'] ?? '-', style: const TextStyle(fontSize: 14)),
                  subtitle: Text('Room ${room?['roomNumber'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status, style: TextStyle(fontSize: 11, color: color)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTasks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => context.go('/web/tasks'), child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 8),
            if (_recentTasks.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No tasks')))
            else
              ..._recentTasks.map((t) {
                final status = t['status'] ?? '';
                final color = status == 'completed' ? Colors.green : status == 'in-progress' ? Colors.blue : Colors.orange;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(Icons.task_alt, color: color, size: 18),
                  ),
                  title: Text(t['title'] ?? '-', style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${t['type'] ?? '-'} • ${t['room']?['roomNumber'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status, style: TextStyle(fontSize: 11, color: color)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // Integrated Analytics views
  Widget _buildPricingCard() {
    if (_pricingData == null) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No pricing suggestions data'))));
    final suggestions = (_pricingData!['suggestions'] as List?) ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                const Text('AI Demand-Based Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (suggestions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1B5E20).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Confidence: ${(((suggestions[0]['confidence'] ?? 0) as num) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (suggestions.isNotEmpty)
              Text('Based on: ${suggestions[0]['basedOn'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            if (suggestions.isEmpty)
              SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No pricing suggestions available', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestions.take(3).length,
                itemBuilder: (ctx, i) {
                  final s = suggestions[i];
                  final factors = s['factors'] ?? {};
                  final demand = factors['demand'] ?? 'low';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text('${s['roomNumber'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Text('${s['roomType'] ?? '-'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              const Spacer(),
                              _DemandChip(demand),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _PriceTag('Current', s['currentPrice'] ?? 0, Colors.grey),
                              _PriceTag('Suggested', s['suggestedPrice'] ?? 0, const Color(0xFF1B5E20)),
                              _PriceTag('Low Season', s['lowSeasonPrice'] ?? 0, Colors.blue),
                              _PriceTag('High Demand', s['highDemandPrice'] ?? 0, Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FactorChip('Weekend', factors['weekend'] == true),
                                const SizedBox(width: 4),
                                _FactorChip('Peak Season', factors['peakSeason'] == true),
                                const SizedBox(width: 4),
                                _FactorChip('Occupancy: ${factors['occupancyRate'] ?? 0}%', true),
                              ],
                            ),
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

  Widget _buildForecastCard() {
    if (_forecastData == null) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No forecast data available'))));
    final forecast = (_forecastData!['forecast'] as List?) ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                const Text('AI Demand Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Based on: ${_forecastData!['averageMonthly'] ?? 0} avg bookings/month • Trend: ${_forecastData!['trend'] ?? '0%'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            if (forecast.isEmpty)
              const SizedBox(
                height: 180,
                child: Center(child: Text('No forecast data yet', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: forecast.take(3).length,
                itemBuilder: (ctx, i) {
                  final f = forecast[i];
                  final confidence = ((f['confidence'] ?? 0) as num).toDouble() * 100;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_month, color: Colors.grey.shade600, size: 18),
                              const SizedBox(width: 8),
                              Text(f['month'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: confidence > 70 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${confidence.toStringAsFixed(0)}% conf',
                                  style: TextStyle(fontSize: 10, color: confidence > 70 ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _ForecastStat('Predicted Bookings', '${f['predictedBookings'] ?? 0}'),
                              const SizedBox(width: 24),
                              _ForecastStat('Predicted Revenue', 'LKR ${f['predictedRevenue'] ?? 0}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (double.tryParse(f['predictedBookings']?.toString() ?? '') ?? 0.0) / 30,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFF1B5E20),
                            minHeight: 4,
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

  Widget _buildTaskPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Staff Task Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_taskPerformance.isEmpty)
              const SizedBox(
                height: 180,
                child: Center(child: Text('No task performance records', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _taskPerformance.take(4).length,
                itemBuilder: (ctx, i) {
                  final t = _taskPerformance[i];
                  final total = (t['total'] ?? 0) as int;
                  final completed = (t['completed'] ?? 0) as int;
                  final overdue = (t['overdue'] ?? 0) as int;
                  final rate = total > 0 ? (completed / total * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Staff: ${t['_id'] ?? 'Unassigned'}',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                            Text(
                              '${rate.toStringAsFixed(0)}%',
                              style: TextStyle(fontWeight: FontWeight.bold, color: rate > 80 ? Colors.green : Colors.orange, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: rate / 100,
                          backgroundColor: Colors.grey.shade200,
                          color: rate > 80 ? Colors.green : rate > 50 ? Colors.orange : Colors.red,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Completed: $completed / $total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            if (overdue > 0) Text('Overdue: $overdue', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomPerformanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room Type Performance List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_roomPerformance.isEmpty)
              const SizedBox(
                height: 180,
                child: Center(child: Text('No room type performance records', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _roomPerformance.take(4).length,
                itemBuilder: (ctx, i) {
                  final r = _roomPerformance[i];
                  final revenue = (r['revenue'] ?? 0) as num;
                  final bookings = (r['bookings'] ?? 0) as int;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: Text(
                        r['_id'] != null && (r['_id'] as String).isNotEmpty ? (r['_id'] as String)[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${r['_id'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    subtitle: Text('$bookings bookings • Avg ${(r['avgGuests'] ?? 0).toStringAsFixed(1)} guests', style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      'LKR ${revenue.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  const _StatCard(this.title, this.value, this.icon, this.color, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _OverviewCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemandChip extends StatelessWidget {
  final String demand;
  const _DemandChip(this.demand);

  @override
  Widget build(BuildContext context) {
    final color = demand == 'high' ? Colors.red : demand == 'medium' ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(demand.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final num price;
  final Color color;
  const _PriceTag(this.label, this.price, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text('LKR ${price.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _FactorChip extends StatelessWidget {
  final String label;
  final bool active;
  const _FactorChip(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.grey.shade100 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? Colors.grey.shade300 : Colors.grey.shade200),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.grey.shade700 : Colors.grey.shade400)),
    );
  }
}

class _ForecastStat extends StatelessWidget {
  final String label;
  final String value;
  const _ForecastStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
