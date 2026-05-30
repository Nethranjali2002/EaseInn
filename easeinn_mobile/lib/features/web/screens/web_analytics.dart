import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/data/auth_provider.dart';
import '../../property/data/property_provider.dart';

class WebAnalyticsScreen extends ConsumerStatefulWidget {
  const WebAnalyticsScreen({super.key});

  @override
  ConsumerState<WebAnalyticsScreen> createState() => _WebAnalyticsScreenState();
}

class _WebAnalyticsScreenState extends ConsumerState<WebAnalyticsScreen> {
  String? _selectedPropertyId;
  bool _isLoading = false;
  String _selectedTab = 'overview';

  Map<String, dynamic>? _occupancy;
  List<dynamic> _revenueData = [];
  List<dynamic> _taskPerformance = [];
  List<dynamic> _roomPerformance = [];
  Map<String, dynamic>? _pricingData;
  Map<String, dynamic>? _forecastData;
  Map<String, dynamic>? _consolidated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
      _loadConsolidated();
    });
  }

  Future<void> _loadAll() async {
    if (_selectedPropertyId == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get('/properties/$_selectedPropertyId/analytics/occupancy'),
        api.get('/properties/$_selectedPropertyId/analytics/revenue'),
        api.get('/properties/$_selectedPropertyId/analytics/tasks'),
        api.get('/properties/$_selectedPropertyId/analytics/rooms'),
        api.get('/properties/$_selectedPropertyId/analytics/pricing'),
        api.get('/properties/$_selectedPropertyId/analytics/forecast'),
      ]);
      setState(() {
        _occupancy = results[0].data['data'];
        _revenueData = (results[1].data['data'] as List?) ?? [];
        _taskPerformance = (results[2].data['data'] as List?) ?? [];
        _roomPerformance = (results[3].data['data'] as List?) ?? [];
        _pricingData = results[4].data['data'];
        _forecastData = results[5].data['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConsolidated() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/analytics/consolidated');
      setState(() => _consolidated = res.data['data']);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(propertyProvider).properties;
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.isAdmin ?? false;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Analytics & AI Insights', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (props.isNotEmpty)
                    DropdownButton<String>(
                      value: _selectedPropertyId,
                      items: props.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) { setState(() => _selectedPropertyId = v); _loadAll(); },
                    ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll, tooltip: 'Refresh'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTabBar(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Tab('Overview', Icons.dashboard, _selectedTab == 'overview', () => setState(() => _selectedTab = 'overview')),
          _Tab('Revenue', Icons.attach_money, _selectedTab == 'revenue', () => setState(() => _selectedTab = 'revenue')),
          _Tab('Occupancy', Icons.hotel, _selectedTab == 'occupancy', () => setState(() => _selectedTab = 'occupancy')),
          _Tab('Tasks', Icons.task_alt, _selectedTab == 'tasks', () => setState(() => _selectedTab = 'tasks')),
          _Tab('Rooms', Icons.king_bed, _selectedTab == 'rooms', () => setState(() => _selectedTab = 'rooms')),
          _Tab('AI Pricing', Icons.psychology, _selectedTab == 'pricing', () => setState(() => _selectedTab = 'pricing')),
          _Tab('AI Forecast', Icons.trending_up, _selectedTab == 'forecast', () => setState(() => _selectedTab = 'forecast')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 'overview': return _buildOverview();
      case 'revenue': return _buildRevenue();
      case 'occupancy': return _buildOccupancy();
      case 'tasks': return _buildTaskPerformance();
      case 'rooms': return _buildRoomPerformance();
      case 'pricing': return _buildPricing();
      case 'forecast': return _buildForecast();
      default: return const SizedBox();
    }
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_consolidated != null) ...[
            const Text('Cross-Property Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6,
              children: [
                _OverviewCard('Properties', '${_consolidated!['totalProperties'] ?? 0}', Icons.business, Colors.blue),
                _OverviewCard('Total Rooms', '${_consolidated!['totalRooms'] ?? 0}', Icons.hotel, Colors.green),
                _OverviewCard('Total Bookings', '${_consolidated!['totalBookings'] ?? 0}', Icons.book_online, Colors.orange),
                _OverviewCard('Revenue', 'LKR ${((_consolidated!['totalRevenue'] ?? 0) as num).toStringAsFixed(0)}', Icons.attach_money, Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Revenue by Property', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_consolidated!['propertyPerformance'] as List? ?? []).map((p) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${p['name']?[0] ?? '?'}')),
                title: Text(p['name'] ?? ''),
                subtitle: Text(p['city'] ?? ''),
                trailing: Text('LKR ${((p['revenue'] ?? 0) as num).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )),
          ],
          if (_occupancy != null) ...[
            const SizedBox(height: 16),
            const Text('Occupancy Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _OccupancyChart(occupancy: _occupancy!),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Revenue Over Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          child: _revenueData.isEmpty
              ? const Center(child: Text('No revenue data'))
              : Card(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('Transactions'), numeric: true),
                      ],
                      rows: _revenueData.map((r) => DataRow(cells: [
                        DataCell(Text(r['_id'] ?? '')),
                        DataCell(Text('LKR ${r['total'] ?? 0}')),
                        DataCell(Text('${r['count'] ?? 0}')),
                      ])).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOccupancy() {
    if (_occupancy == null) return const Center(child: Text('No occupancy data'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Occupancy Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _OccupancyChart(occupancy: _occupancy!),
      ],
    );
  }

  Widget _buildTaskPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Task Performance by Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          child: _taskPerformance.isEmpty
              ? const Center(child: Text('No task data'))
              : ListView.builder(
                  itemCount: _taskPerformance.length,
                  itemBuilder: (ctx, i) {
                    final t = _taskPerformance[i];
                    final total = (t['total'] ?? 0) as int;
                    final completed = (t['completed'] ?? 0) as int;
                    final overdue = (t['overdue'] ?? 0) as int;
                    final rate = total > 0 ? (completed / total * 100) : 0.0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Staff: ${t['_id'] ?? 'Unassigned'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: rate / 100,
                              backgroundColor: Colors.grey.shade200,
                              color: rate > 80 ? Colors.green : rate > 50 ? Colors.orange : Colors.red,
                              minHeight: 8,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Completed: $completed / $total', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                Text('${rate.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: rate > 80 ? Colors.green : Colors.orange)),
                                if (overdue > 0) Text('Overdue: $overdue', style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomPerformance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Room Type Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Expanded(
          child: _roomPerformance.isEmpty
              ? const Center(child: Text('No room data'))
              : ListView.builder(
                  itemCount: _roomPerformance.length,
                  itemBuilder: (ctx, i) {
                    final r = _roomPerformance[i];
                    final revenue = (r['revenue'] ?? 0) as num;
                    final bookings = (r['bookings'] ?? 0) as int;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: Text('${r['_id']?[0]?.toUpperCase() ?? '?'}', style: const TextStyle(color: Colors.blue)),
                        ),
                        title: Text('${r['_id'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('$bookings bookings • Avg ${(r['avgGuests'] ?? 0).toStringAsFixed(1)} guests'),
                        trailing: Text('LKR ${revenue.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPricing() {
    if (_pricingData == null) return const Center(child: Text('No pricing data'));
    final suggestions = (_pricingData!['suggestions'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            const Text('AI Demand-Based Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF1B5E20).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Confidence: ${((_pricingData!['suggestions'] as List?)?.isNotEmpty == true ? (((suggestions[0])['confidence'] ?? 0) * 100).toStringAsFixed(0) : '0')}%',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Based on: ${_pricingData!['suggestions']?.isNotEmpty == true ? (suggestions[0]['basedOn'] ?? '') : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Expanded(
          child: suggestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.psychology_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No pricing suggestions available',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please ensure this property has active rooms to generate AI pricing suggestions.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (ctx, i) {
                    final s = suggestions[i];
              final factors = s['factors'] ?? {};
              final demand = factors['demand'] ?? 'low';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('${s['roomNumber'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text('${s['roomType'] ?? '-'}', style: TextStyle(color: Colors.grey.shade600)),
                          const Spacer(),
                          _DemandChip(demand),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _PriceTag('Current', s['currentPrice'] ?? 0, Colors.grey),
                          const SizedBox(width: 8),
                          _PriceTag('Suggested', s['suggestedPrice'] ?? 0, const Color(0xFF1B5E20)),
                          const SizedBox(width: 8),
                          _PriceTag('Low Season', s['lowSeasonPrice'] ?? 0, Colors.blue),
                          const SizedBox(width: 8),
                          _PriceTag('High Demand', s['highDemandPrice'] ?? 0, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _FactorChip('Weekend', factors['weekend'] == true),
                          const SizedBox(width: 4),
                          _FactorChip('Peak Season', factors['peakSeason'] == true),
                          const SizedBox(width: 4),
                          _FactorChip('Occupancy: ${factors['occupancyRate'] ?? 0}%', true),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    if (_forecastData == null) return const Center(child: Text('No forecast data'));
    final forecast = (_forecastData!['forecast'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, color: Color(0xFF1B5E20)),
            const SizedBox(width: 8),
            const Text('AI Demand Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Based on: ${_forecastData!['averageMonthly'] ?? 0} avg bookings/month • Trend: ${_forecastData!['trend'] ?? '0%'}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 16),
        Expanded(
          child: forecast.isEmpty
              ? const Center(child: Text('No forecast data yet'))
              : ListView.builder(
                  itemCount: forecast.length,
                  itemBuilder: (ctx, i) {
                    final f = forecast[i];
                    final confidence = ((f['confidence'] ?? 0) as double) * 100;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_month, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(f['month'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: confidence > 70 ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${confidence.toStringAsFixed(0)}% confidence',
                                      style: TextStyle(fontSize: 12, color: confidence > 70 ? Colors.green : Colors.orange)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _ForecastStat('Predicted Bookings', '${f['predictedBookings'] ?? 0}'),
                                const SizedBox(width: 16),
                                _ForecastStat('Predicted Revenue', 'LKR ${f['predictedRevenue'] ?? 0}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (double.tryParse(f['predictedBookings']?.toString() ?? '') ?? 0.0) / 30,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFF1B5E20),
                              minHeight: 6,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(this.label, this.icon, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        avatar: Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade700),
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.grey.shade700)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF1B5E20),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? const Color(0xFF1B5E20) : Colors.grey.shade300),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _OverviewCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _OccupancyChart extends StatelessWidget {
  final Map<String, dynamic> occupancy;
  const _OccupancyChart({required this.occupancy});

  @override
  Widget build(BuildContext context) {
    final rate = double.tryParse(occupancy['occupancyRate']?.toString() ?? '') ?? 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 120, height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120, height: 120,
                        child: CircularProgressIndicator(
                          value: rate / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          color: rate > 70 ? Colors.green : rate > 40 ? Colors.orange : Colors.red,
                        ),
                      ),
                      Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OccupancyStat('Total Room Nights', '${occupancy['totalRoomNights'] ?? 0}'),
                      _OccupancyStat('Occupied Nights', '${occupancy['occupiedNights'] ?? 0}'),
                      _OccupancyStat('Total Rooms', '${occupancy['totalRooms'] ?? 0}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OccupancyStat extends StatelessWidget {
  final String label;
  final String value;
  const _OccupancyStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text('Demand: $demand', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final dynamic price;
  final Color color;
  const _PriceTag(this.label, this.price, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text('LKR $price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
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
        color: active ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: active ? Colors.blue : Colors.grey)),
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
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
