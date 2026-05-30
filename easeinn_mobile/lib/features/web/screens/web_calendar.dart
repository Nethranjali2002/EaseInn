import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../auth/data/auth_provider.dart';
import '../../property/data/property_provider.dart';
import '../../booking/data/booking_provider.dart';

class WebCalendarScreen extends ConsumerStatefulWidget {
  const WebCalendarScreen({super.key});

  @override
  ConsumerState<WebCalendarScreen> createState() => _WebCalendarScreenState();
}

class _WebCalendarScreenState extends ConsumerState<WebCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = false;
  String? _selectedPropertyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final props = ref.read(propertyProvider).properties;
      if (props.isNotEmpty) {
        _selectedPropertyId = props.first.id;
        _loadCalendar();
      }
    });
  }

  Future<void> _loadCalendar() async {
    if (_selectedPropertyId == null) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final start = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final end = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      final res = await api.get(
        '/properties/$_selectedPropertyId/bookings/calendar?startDate=${start.toIso8601String()}&endDate=${end.toIso8601String()}',
      );
      final bookings = (res.data['data']['bookings'] as List).map((b) => b as Map<String, dynamic>).toList();
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(propertyProvider).properties;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Booking Calendar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (props.isNotEmpty)
                    DropdownButton<String>(
                      value: _selectedPropertyId,
                      hint: const Text('Select Property'),
                      items: props.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedPropertyId = v);
                        _loadCalendar();
                      },
                    ),
                  const SizedBox(width: 16),
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {
                    setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
                    _loadCalendar();
                  }),
                  Text(
                    '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {
                    setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
                    _loadCalendar();
                  }),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.today, size: 18),
                    label: const Text('Today'),
                    onPressed: () {
                      setState(() => _currentMonth = DateTime.now());
                      _loadCalendar();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLegend(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCalendarGrid(),
          ),
          const SizedBox(height: 16),
          _buildBookingSummary(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      children: [
        _LegendItem(color: const Color(0xFF1B5E20), label: 'Checked In'),
        _LegendItem(color: const Color(0xFF2196F3), label: 'Confirmed'),
        _LegendItem(color: const Color(0xFFFF9800), label: 'Checkout Today'),
        _LegendItem(color: const Color(0xFF9E9E9E), label: 'No Bookings'),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade200)),
              child: Text(day, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            ),
          )).toList(),
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.0),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startWeekday) return const SizedBox();
              final day = index - startWeekday + 1;
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
              final dayBookings = _getBookingsForDate(date);

              return GestureDetector(
                onTap: dayBookings.isNotEmpty ? () => _showDayBookings(date, dayBookings) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF1B5E20).withOpacity(0.15)
                        : dayBookings.isNotEmpty
                            ? _getBookingColor(dayBookings).withOpacity(0.08)
                            : null,
                    border: Border.all(color: isToday ? const Color(0xFF1B5E20) : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? const Color(0xFF1B5E20) : Colors.black87,
                        ),
                      ),
                      if (dayBookings.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        ...dayBookings.take(2).map((b) => Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: _getBookingColorForStatus(b['bookingStatus']),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        )),
                        if (dayBookings.length > 2)
                          Text('${dayBookings.length}', style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
                      ],
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

  Color _getBookingColor(List<Map<String, dynamic>> bookings) {
    if (bookings.any((b) => b['bookingStatus'] == 'checked-in')) return const Color(0xFF1B5E20);
    if (bookings.any((b) => b['bookingStatus'] == 'confirmed')) return const Color(0xFF2196F3);
    return const Color(0xFF9E9E9E);
  }

  Color _getBookingColorForStatus(String status) {
    switch (status) {
      case 'checked-in': return const Color(0xFF1B5E20);
      case 'confirmed': return const Color(0xFF2196F3);
      case 'checked-out': return const Color(0xFF9E9E9E);
      case 'cancelled': return const Color(0xFFE53935);
      default: return const Color(0xFFFF9800);
    }
  }

  List<Map<String, dynamic>> _getBookingsForDate(DateTime date) {
    return _bookings.where((b) {
      final checkIn = DateTime.parse(b['checkIn']);
      final checkOut = DateTime.parse(b['checkOut']);
      return !date.isBefore(DateTime(checkIn.year, checkIn.month, checkIn.day)) && !date.isAfter(DateTime(checkOut.year, checkOut.month, checkOut.day));
    }).toList();
  }

  void _showDayBookings(DateTime date, List<Map<String, dynamic>> bookings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bookings - ${date.day}/${date.month}/${date.year}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: bookings.map((b) {
              final guest = b['guest'] as Map<String, dynamic>?;
              final room = b['room'] as Map<String, dynamic>?;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getBookingColorForStatus(b['bookingStatus']).withOpacity(0.1),
                    child: Icon(Icons.person, color: _getBookingColorForStatus(b['bookingStatus']), size: 20),
                  ),
                  title: Text(guest?['name'] ?? 'Guest'),
                  subtitle: Text('Room ${room?['roomNumber'] ?? '-'} • ${b['bookingStatus']}'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/web/bookings');
                    },
                    child: const Text('View'),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildBookingSummary() {
    final checkedIn = _bookings.where((b) => b['bookingStatus'] == 'checked-in').length;
    final confirmed = _bookings.where((b) => b['bookingStatus'] == 'confirmed').length;

    return Row(
      children: [
        _SummaryChip(label: 'This Month', value: '${_bookings.length}', color: Colors.blue),
        const SizedBox(width: 12),
        _SummaryChip(label: 'Checked In', value: '$checkedIn', color: const Color(0xFF1B5E20)),
        const SizedBox(width: 12),
        _SummaryChip(label: 'Confirmed', value: '$confirmed', color: const Color(0xFF2196F3)),
        const Spacer(),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Booking'),
          onPressed: () => context.go('/web/bookings'),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month];
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      label: Text('$label: $value', style: const TextStyle(fontSize: 13)),
    );
  }
}
