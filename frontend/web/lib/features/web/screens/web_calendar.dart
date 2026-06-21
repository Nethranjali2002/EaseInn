import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

class WebCalendarScreen extends ConsumerStatefulWidget {
  const WebCalendarScreen({super.key});

  @override
  ConsumerState<WebCalendarScreen> createState() => _WebCalendarScreenState();
}

class _WebCalendarScreenState extends ConsumerState<WebCalendarScreen> {
  DateTime _currentDate = DateTime.now();
  String _selectedView = 'Month'; // Month, Week, Day, List, Occupancy
  String _selectedPropertyId = 'All';
  String _selectedEventType =
      'All'; // All, Bookings, Tasks, Maintenance, Cleaning
  String _selectedStatus = 'All';
  bool _isStaff = false;

  List<Map<String, dynamic>> _rawBookings = [];
  List<Map<String, dynamic>> _rawTasks = [];
  List<Map<String, dynamic>> _rawRooms = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      _isStaff = user?.role == 'staff';
      _loadCalendarData();
    });
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      if (_isStaff) {
        // Staff: Only load their assigned tasks
        final res = await api.get('/tasks/my?limit=100');
        final data = res.data['data'];
        final tasks = data is Map ? (data['tasks'] as List?) ?? [] : [];
        setState(() {
          _rawTasks = tasks.map((t) => Map<String, dynamic>.from(t)).toList();
          _rawBookings = [];
          _rawRooms = [];
          _isLoading = false;
        });
        return;
      }

      // Admin/Manager: Load all data
      await ref.read(propertyProvider.notifier).fetchProperties();
      final properties = ref.read(propertyProvider).properties;

      List<Map<String, dynamic>> tempBookings = [];
      List<Map<String, dynamic>> tempTasks = [];
      List<Map<String, dynamic>> tempRooms = [];

      final targetProperties = _selectedPropertyId == 'All'
          ? properties.map((p) => p.id).toList()
          : [_selectedPropertyId];

      for (final propId in targetProperties) {
        // Fetch Bookings
        try {
          final res = await api.get('/properties/$propId/bookings');
          final list = res.data['data']['bookings'] as List?;
          if (list != null) {
            tempBookings.addAll(list.map((b) => Map<String, dynamic>.from(b)));
          }
        } catch (_) {}

        // Fetch Tasks
        try {
          final res = await api.get('/properties/$propId/tasks');
          final list = res.data['data']['tasks'] as List?;
          if (list != null) {
            tempTasks.addAll(list.map((t) => Map<String, dynamic>.from(t)));
          }
        } catch (_) {}

        // Fetch Rooms
        try {
          final res = await api.get('/properties/$propId/rooms');
          final list = res.data['data']['rooms'] as List?;
          if (list != null) {
            tempRooms.addAll(list.map((r) => Map<String, dynamic>.from(r)));
          }
        } catch (_) {}
      }

      setState(() {
        _rawBookings = tempBookings;
        _rawTasks = tempTasks;
        _rawRooms = tempRooms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<_CalendarEvent> _getEvents() {
    List<_CalendarEvent> events = [];

    // 1. Map Bookings to Events
    for (final b in _rawBookings) {
      final checkInDate = DateTime.tryParse(b['checkIn'] ?? '');
      final checkOutDate = DateTime.tryParse(b['checkOut'] ?? '');
      final status = (b['bookingStatus'] ?? 'confirmed')
          .toString()
          .toLowerCase();

      Color bookingColor = Colors.blue;
      if (status == 'checked-in') {
        bookingColor = Colors.green;
      } else if (status == 'checked-out' || status == 'completed') {
        bookingColor = Colors.grey;
      } else if (status == 'cancelled') {
        bookingColor = Colors.red;
      } else if (status == 'pending-payment') {
        bookingColor = Colors.orange;
      }

      // Check-In Event
      if (checkInDate != null) {
        events.add(
          _CalendarEvent(
            id: '${b['_id'] ?? b['id']}_in',
            title: 'Check-In: ${b['guest']?['name'] ?? 'Guest'}',
            type: 'Check-In',
            date: checkInDate,
            color: bookingColor,
            data: b,
          ),
        );
      }

      // Check-Out Event
      if (checkOutDate != null) {
        events.add(
          _CalendarEvent(
            id: '${b['_id'] ?? b['id']}_out',
            title: 'Check-Out: ${b['guest']?['name'] ?? 'Guest'}',
            type: 'Check-Out',
            date: checkOutDate,
            color: Colors.grey.shade600,
            data: b,
          ),
        );
      }

      // Span/Reservation Event
      if (checkInDate != null && checkOutDate != null) {
        events.add(
          _CalendarEvent(
            id: '${b['_id'] ?? b['id']}_res',
            title:
                'Reservation: ${b['guest']?['name'] ?? 'Guest'} (Room ${b['room']?['roomNumber'] ?? 'N/A'})',
            type: 'Reservation',
            date: checkInDate,
            endDate: checkOutDate,
            color: bookingColor,
            data: b,
          ),
        );
      }
    }

    // 2. Map Tasks to Events
    for (final t in _rawTasks) {
      final dueDate = DateTime.tryParse(t['dueDate'] ?? t['createdAt'] ?? '');
      if (dueDate == null) continue;

      final title = (t['title'] ?? '').toString().toLowerCase();
      String type = 'Task';
      Color taskColor = Colors.purple;

      if (title.contains('clean') || title.contains('laundry')) {
        type = 'Cleaning';
        taskColor = Colors.teal;
      } else if (title.contains('repair') ||
          title.contains('maintenance') ||
          title.contains('plumbing')) {
        type = 'Maintenance';
        taskColor = Colors.deepOrange;
      }

      events.add(
        _CalendarEvent(
          id: t['_id'] ?? t['id'] ?? '',
          title:
              '${t['title']} (Room ${t['room'] is Map ? t['room']['roomNumber'] : t['room'] ?? 'N/A'})',
          type: type,
          date: dueDate,
          color: taskColor,
          data: t,
        ),
      );
    }

    // Filter by Event Type & Status
    return events.where((e) {
      if (_selectedEventType != 'All') {
        if (_selectedEventType == 'Bookings' &&
            !['Check-In', 'Check-Out', 'Reservation'].contains(e.type)) {
          return false;
        }
        if (_selectedEventType == 'Tasks' && !['Task'].contains(e.type)) {
          return false;
        }
        if (_selectedEventType == 'Maintenance' && e.type != 'Maintenance') {
          return false;
        }
        if (_selectedEventType == 'Cleaning' && e.type != 'Cleaning') {
          return false;
        }
      }

      if (_selectedStatus != 'All') {
        final status = (e.data['bookingStatus'] ?? e.data['status'] ?? '')
            .toString()
            .toLowerCase();
        if (status != _selectedStatus.toLowerCase()) return false;
      }

      return true;
    }).toList();
  }

  Map<String, int> _calculateDashboardStats() {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    int checkIns = 0;
    int checkOuts = 0;
    int pendingArrivals = 0;

    Set<String> occupiedRoomIds = {};

    for (final b in _rawBookings) {
      final status = (b['bookingStatus'] ?? '').toString().toLowerCase();
      if (status == 'cancelled') continue;

      final checkInStr = b['checkIn'] != null
          ? b['checkIn'].toString().substring(0, 10)
          : '';
      final checkOutStr = b['checkOut'] != null
          ? b['checkOut'].toString().substring(0, 10)
          : '';

      if (checkInStr == todayStr) {
        checkIns++;
        if (status != 'checked-in') {
          pendingArrivals++;
        }
      }

      if (checkOutStr == todayStr) {
        checkOuts++;
      }

      // Check if room is occupied today
      if (b['checkIn'] != null && b['checkOut'] != null) {
        final checkIn = DateTime.parse(b['checkIn']);
        final checkOut = DateTime.parse(b['checkOut']);
        if (!today.isBefore(
              DateTime(checkIn.year, checkIn.month, checkIn.day),
            ) &&
            !today.isAfter(
              DateTime(checkOut.year, checkOut.month, checkOut.day),
            )) {
          final rId = b['room'] is Map
              ? (b['room']['_id'] ?? b['room']['id'])
              : b['room'];
          if (rId != null) occupiedRoomIds.add(rId.toString());
        }
      }
    }

    final totalRooms = _rawRooms.length;
    final occupiedRoomsCount = occupiedRoomIds.length;
    final availableRoomsCount = totalRooms > occupiedRoomsCount
        ? totalRooms - occupiedRoomsCount
        : totalRooms == 0
        ? 0
        : 0;

    return {
      'checkIns': checkIns,
      'checkOuts': checkOuts,
      'occupiedRooms': occupiedRoomsCount,
      'availableRooms': availableRoomsCount,
      'pendingArrivals': pendingArrivals,
    };
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertyProvider).properties;
    final stats = _calculateDashboardStats();
    final events = _getEvents();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isStaff ? 'My Task Calendar' : 'Operational Planning Center',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  // View Selection buttons
                  _viewSegmentButton('Month'),
                  _viewSegmentButton('Week'),
                  _viewSegmentButton('Day'),
                  _viewSegmentButton('List'),
                  if (!_isStaff) _viewSegmentButton('Occupancy'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Staff: Simple date navigation
          if (_isStaff)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          if (_selectedView == 'Month') {
                            _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
                          } else if (_selectedView == 'Week') {
                            _currentDate = _currentDate.subtract(const Duration(days: 7));
                          } else {
                            _currentDate = _currentDate.subtract(const Duration(days: 1));
                          }
                        });
                      },
                    ),
                    Text(
                      _getFormattedDateTitle(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          if (_selectedView == 'Month') {
                            _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
                          } else if (_selectedView == 'Week') {
                            _currentDate = _currentDate.add(const Duration(days: 7));
                          } else {
                            _currentDate = _currentDate.add(const Duration(days: 1));
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => _currentDate = DateTime.now()),
                      child: const Text('Today'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isStaff) const SizedBox(height: 16),

          // Dashboard Summary Cards (Admin/Manager only)
          if (!_isStaff) ...[
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    "Today's Check-Ins",
                    '${stats['checkIns']}',
                    Icons.login,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    "Today's Check-Outs",
                    '${stats['checkOuts']}',
                    Icons.logout,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Occupied Rooms',
                    '${stats['occupiedRooms']}',
                    Icons.hotel,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Available Rooms',
                    '${stats['availableRooms']}',
                    Icons.meeting_room,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Pending Arrivals',
                    '${stats['pendingArrivals']}',
                    Icons.hourglass_top,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filters Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Property Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedPropertyId,
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text('All Properties'),
                          ),
                          ...properties.map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedPropertyId = v!);
                          _loadCalendarData();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Property',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Event Type Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedEventType,
                        items: const [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('All Events'),
                          ),
                          DropdownMenuItem(
                            value: 'Bookings',
                            child: Text('Bookings'),
                          ),
                          DropdownMenuItem(value: 'Tasks', child: Text('Tasks')),
                          DropdownMenuItem(
                            value: 'Maintenance',
                            child: Text('Maintenance'),
                          ),
                          DropdownMenuItem(
                            value: 'Cleaning',
                            child: Text('Cleaning'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedEventType = v!),
                        decoration: const InputDecoration(
                          labelText: 'Event Type',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Status Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        items: const [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('All Statuses'),
                          ),
                          DropdownMenuItem(
                            value: 'Confirmed',
                            child: Text('Confirmed'),
                          ),
                          DropdownMenuItem(
                            value: 'Checked-In',
                            child: Text('Checked In'),
                          ),
                          DropdownMenuItem(
                            value: 'Completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(
                            value: 'Pending-Payment',
                            child: Text('Pending Payment'),
                          ),
                          DropdownMenuItem(
                            value: 'Cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _selectedStatus = v!),
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date Navigation Controls
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          if (_selectedView == 'Month' ||
                              _selectedView == 'Occupancy') {
                            _currentDate = DateTime(
                              _currentDate.year,
                              _currentDate.month - 1,
                              1,
                            );
                          } else if (_selectedView == 'Week') {
                            _currentDate = _currentDate.subtract(
                              const Duration(days: 7),
                            );
                          } else {
                            _currentDate = _currentDate.subtract(
                              const Duration(days: 1),
                            );
                          }
                        });
                      },
                    ),
                    Text(
                      _getFormattedDateTitle(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          if (_selectedView == 'Month' ||
                              _selectedView == 'Occupancy') {
                            _currentDate = DateTime(
                              _currentDate.year,
                              _currentDate.month + 1,
                              1,
                            );
                          } else if (_selectedView == 'Week') {
                            _currentDate = _currentDate.add(
                              const Duration(days: 7),
                            );
                          } else {
                            _currentDate = _currentDate.add(
                              const Duration(days: 1),
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),

                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _currentDate = DateTime.now()),
                      child: const Text('Today'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Color Legend
          _buildColorLegend(),
          const SizedBox(height: 16),

          // Core Calendar Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildCalendarView(events),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _viewSegmentButton(String viewName) {
    final isSelected = _selectedView == viewName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(viewName),
        selected: isSelected,
        selectedColor: Colors.blue.withOpacity(0.15),
        onSelected: (selected) {
          if (selected) setState(() => _selectedView = viewName);
        },
      ),
    );
  }

  String _getFormattedDateTitle() {
    if (_selectedView == 'Month' || _selectedView == 'Occupancy') {
      return DateFormat('MMMM yyyy').format(_currentDate);
    } else if (_selectedView == 'Week') {
      final start = _currentDate.subtract(
        Duration(days: _currentDate.weekday - 1),
      );
      final end = start.add(const Duration(days: 6));
      return '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
    } else {
      return DateFormat('dd MMMM yyyy').format(_currentDate);
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 18,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorLegend() {
    return Wrap(
      spacing: 16,
      children: [
        _legendDot(Colors.blue, 'Booking / Reservation'),
        _legendDot(Colors.green, 'Checked-In'),
        _legendDot(Colors.grey, 'Checked-Out / Completed'),
        _legendDot(Colors.orange, 'Pending Payment'),
        _legendDot(Colors.deepOrange, 'Maintenance Task'),
        _legendDot(Colors.teal, 'Cleaning / Housekeeping'),
        _legendDot(Colors.red, 'Cancelled'),
      ],
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  Widget _buildCalendarView(List<_CalendarEvent> events) {
    switch (_selectedView) {
      case 'Month':
        return _buildMonthView(events);
      case 'Week':
        return _buildWeekView(events);
      case 'Day':
        return _buildDayView(events);
      case 'List':
        return _buildListView(events);
      case 'Occupancy':
        return _buildOccupancyGrid();
      default:
        return _buildMonthView(events);
    }
  }

  // --- MONTH VIEW ---
  Widget _buildMonthView(List<_CalendarEvent> events) {
    final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
    final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map(
                (day) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox();
              final day = index - startWeekday + 1;
              final date = DateTime(_currentDate.year, _currentDate.month, day);
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;

              final dayEvents = events.where((e) {
                if (e.endDate != null) {
                  return !date.isBefore(
                        DateTime(e.date.year, e.date.month, e.date.day),
                      ) &&
                      !date.isAfter(
                        DateTime(
                          e.endDate!.year,
                          e.endDate!.month,
                          e.endDate!.day,
                        ),
                      );
                }
                return e.date.year == date.year &&
                    e.date.month == date.month &&
                    e.date.day == date.day;
              }).toList();

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade100),
                  color: isToday ? Colors.blue.withOpacity(0.05) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: isToday
                            ? Colors.blue
                            : Colors.transparent,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isToday ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: dayEvents.take(3).map((e) {
                          return GestureDetector(
                            onTap: () => _showEventDetailsDrawer(e),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: e.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: e.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      e.title,
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: e.color.darker(),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- WEEK VIEW ---
  Widget _buildWeekView(List<_CalendarEvent> events) {
    final startOfWeek = _currentDate.subtract(
      Duration(days: _currentDate.weekday - 1),
    );
    return Row(
      children: List.generate(7, (index) {
        final date = startOfWeek.add(Duration(days: index));
        final isToday =
            DateFormat('yyyy-MM-dd').format(date) ==
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        final dayEvents = events.where((e) {
          if (e.endDate != null) {
            return !date.isBefore(
                  DateTime(e.date.year, e.date.month, e.date.day),
                ) &&
                !date.isAfter(
                  DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day),
                );
          }
          return e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day;
        }).toList();

        return Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
              color: isToday ? Colors.blue.withOpacity(0.02) : null,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.center,
                  color: isToday
                      ? Colors.blue.withOpacity(0.08)
                      : Colors.grey.shade50,
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEE').format(date),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM').format(date),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday ? Colors.blue : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(6),
                    children: dayEvents
                        .map((e) => _buildWeekEventCard(e))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWeekEventCard(_CalendarEvent e) {
    return GestureDetector(
      onTap: () => _showEventDetailsDrawer(e),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: e.color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
        ),
        color: e.color.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: e.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      e.type.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                e.title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DAY VIEW ---
  Widget _buildDayView(List<_CalendarEvent> events) {
    final dayEvents = events.where((e) {
      if (e.endDate != null) {
        return !_currentDate.isBefore(
              DateTime(e.date.year, e.date.month, e.date.day),
            ) &&
            !_currentDate.isAfter(
              DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day),
            );
      }
      return e.date.year == _currentDate.year &&
          e.date.month == _currentDate.month &&
          e.date.day == _currentDate.day;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Daily Operations - ${dayEvents.length} events scheduled',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? const Center(
                  child: Text('No operational tasks or bookings today.'),
                )
              : ListView.separated(
                  itemCount: dayEvents.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = dayEvents[index];
                    return ListTile(
                      onTap: () => _showEventDetailsDrawer(e),
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: e.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        e.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Event Type: ${e.type}'),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- LIST VIEW ---
  Widget _buildListView(List<_CalendarEvent> events) {
    return ListView(
      children: [
        DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Event Type')),
            DataColumn(label: Text('Room')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: events.take(50).map((e) {
            final dateStr = DateFormat('dd MMM yyyy').format(e.date);
            final roomNo = e.data['room'] is Map
                ? e.data['room']['roomNumber'] ?? 'N/A'
                : e.data['room'] ?? 'N/A';
            final status =
                e.data['bookingStatus'] ?? e.data['status'] ?? 'Active';

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    dateStr,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: e.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.type,
                      style: TextStyle(
                        fontSize: 10,
                        color: e.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(Text('Room $roomNo')),
                DataCell(Text(e.title)),
                DataCell(Text(status.toString().toUpperCase())),
                DataCell(
                  TextButton(
                    onPressed: () => _showEventDetailsDrawer(e),
                    child: const Text('Details'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- ROOM OCCUPANCY GRID ---
  Widget _buildOccupancyGrid() {
    if (_rawRooms.isEmpty) {
      return const Center(
        child: Text('No rooms found for occupancy tracking.'),
      );
    }

    final daysInMonth = DateTime(
      _currentDate.year,
      _currentDate.month + 1,
      0,
    ).day;

    return Column(
      children: [
        // Occupancy Grid Header
        Row(
          children: [
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Rooms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: daysInMonth,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    return Container(
                      width: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Text(
                        '$day',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const Divider(),

        // Occupancy Grid Body (Rows)
        Expanded(
          child: ListView.builder(
            itemCount: _rawRooms.length,
            itemBuilder: (context, rowIndex) {
              final r = _rawRooms[rowIndex];
              final roomNumber = r['roomNumber'] ?? 'N/A';
              final roomId = r['_id'] ?? r['id'];

              return Row(
                children: [
                  Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Room $roomNumber',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: daysInMonth,
                        itemBuilder: (context, colIndex) {
                          final day = colIndex + 1;
                          final date = DateTime(
                            _currentDate.year,
                            _currentDate.month,
                            day,
                          );

                          // Find booking for this room on this date
                          final booking = _findBookingForRoomAndDate(
                            roomId,
                            date,
                          );

                          Color cellColor = Colors.transparent;
                          String tooltip = 'Room $roomNumber: Free';
                          if (booking != null) {
                            final status = (booking['bookingStatus'] ?? '')
                                .toString()
                                .toLowerCase();
                            cellColor = status == 'checked-in'
                                ? Colors.green.withOpacity(0.6)
                                : Colors.blue.withOpacity(0.6);
                            tooltip =
                                'Booked by: ${booking['guest']?['name'] ?? "Guest"}';
                          }

                          return Tooltip(
                            message: tooltip,
                            child: Container(
                              width: 32,
                              decoration: BoxDecoration(
                                color: cellColor,
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: booking != null
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, dynamic>? _findBookingForRoomAndDate(
    dynamic roomId,
    DateTime date,
  ) {
    if (roomId == null) return null;
    for (final b in _rawBookings) {
      if (b['bookingStatus'] == 'cancelled') continue;
      final bRoomId = b['room'] is Map
          ? (b['room']['_id'] ?? b['room']['id'])
          : b['room'];
      if (bRoomId?.toString() == roomId.toString()) {
        final checkIn = DateTime.parse(b['checkIn']);
        final checkOut = DateTime.parse(b['checkOut']);
        if (!date.isBefore(
              DateTime(checkIn.year, checkIn.month, checkIn.day),
            ) &&
            !date.isAfter(
              DateTime(checkOut.year, checkOut.month, checkOut.day),
            )) {
          return b;
        }
      }
    }
    return null;
  }

  // --- DETAILS DRAWER MODAL ---
  void _showEventDetailsDrawer(_CalendarEvent e) {
    final originalData = e.data;
    final isBooking = ['Check-In', 'Check-Out', 'Reservation'].contains(e.type);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.type.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: e.color,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                e.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 24),

              if (isBooking) ...[
                _drawerRow(
                  'Booking ID',
                  originalData['_id'] ?? originalData['id'] ?? 'N/A',
                ),
                _drawerRow(
                  'Guest Name',
                  originalData['guest']?['name'] ?? 'N/A',
                ),
                _drawerRow(
                  'Guest Email',
                  originalData['guest']?['email'] ?? 'N/A',
                ),
                _drawerRow(
                  'Stay Period',
                  '${DateFormat('dd MMM').format(DateTime.parse(originalData['checkIn']))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(originalData['checkOut']))}',
                ),
                _drawerRow(
                  'Payment Status',
                  (originalData['paymentStatus'] ?? 'Pending')
                      .toString()
                      .toUpperCase(),
                ),
                _drawerRow(
                  'Current Status',
                  (originalData['bookingStatus'] ?? 'Confirmed')
                      .toString()
                      .toUpperCase(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/web/bookings');
                      },
                      child: const Text('View Booking Detail'),
                    ),
                  ],
                ),
              ] else ...[
                _drawerRow('Task Title', originalData['title'] ?? 'N/A'),
                _drawerRow(
                  'Description',
                  originalData['description'] ?? 'No description provided.',
                ),
                _drawerRow(
                  'Assigned Staff',
                  originalData['assignedTo'] is Map
                      ? originalData['assignedTo']['name'] ?? 'Unassigned'
                      : 'Unassigned',
                ),
                _drawerRow(
                  'Due Date',
                  DateFormat('dd MMM yyyy, hh:mm a').format(
                    DateTime.parse(
                      originalData['dueDate'] ?? originalData['createdAt'],
                    ),
                  ),
                ),
                _drawerRow(
                  'Task Status',
                  (originalData['status'] ?? 'Pending')
                      .toString()
                      .toUpperCase(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/web/tasks');
                      },
                      child: const Text('View Task Management'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _drawerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CalendarEvent {
  final String id;
  final String title;
  final String type;
  final DateTime date;
  final DateTime? endDate;
  final Color color;
  final Map<String, dynamic> data;

  _CalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.endDate,
    required this.color,
    required this.data,
  });
}

extension ColorExtension on Color {
  Color darker() {
    return Color.fromARGB(
      alpha,
      (red * 0.7).round(),
      (green * 0.7).round(),
      (blue * 0.7).round(),
    );
  }
}
