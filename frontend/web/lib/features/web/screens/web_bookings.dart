import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import '../widgets/web_data_table.dart';
import '../widgets/web_form_dialog.dart';
import 'web_payments.dart';

/// Main booking management screen for admin and manager roles.
class WebBookingsScreen extends ConsumerStatefulWidget {
  const WebBookingsScreen({super.key});

  @override
  ConsumerState<WebBookingsScreen> createState() => _WebBookingsScreenState();
}

class _WebBookingsScreenState extends ConsumerState<WebBookingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isCalendarView = false;
  DateTime _calendarMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads all required data: properties, bookings, and rooms for the first property.
  Future<void> _loadData() async {
    await ref.read(propertyProvider.notifier).fetchProperties();
    await ref.read(bookingProvider.notifier).fetchAllBookings();
    final properties = ref.read(propertyProvider).properties;
    if (properties.isNotEmpty) {
      await ref.read(roomProvider.notifier).fetchRooms(properties.first.id);
    }
  }

  /// Resets all filter selections to their default "All" values.
  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedPropertyId = 'All';
      _selectedRoomType = 'All';
      _selectedBookingStatus = 'All';
      _selectedPaymentStatus = 'All';
      _selectedDateRange = 'All';
      _selectedQuickFilter = 'None';
    });
  }

  String _searchQuery = '';
  String? _selectedPropertyId;
  String _selectedRoomType = 'All';
  String _selectedBookingStatus = 'All';
  String _selectedPaymentStatus = 'All';
  String _selectedDateRange = 'All';
  String _selectedQuickFilter = 'None';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final rooms = ref.watch(roomProvider).rooms;
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.isAdmin ?? false;
    final isManager = auth.user?.isManager ?? false;
    final canManage = isAdmin || isManager;

    // Calculate Summary Stats
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final totalBookingsCount = state.bookings.length;
    final todayCheckInsCount = state.bookings.where((b) {
      final ci = DateTime(b.checkIn.year, b.checkIn.month, b.checkIn.day);
      return ci == today;
    }).length;
    final todayCheckOutsCount = state.bookings.where((b) {
      final co = DateTime(b.checkOut.year, b.checkOut.month, b.checkOut.day);
      return co == today;
    }).length;
    final pendingPaymentsCount = state.bookings
        .where(
          (b) => b.paymentStatus == 'pending' || b.paymentStatus == 'partial',
        )
        .length;
    final occupiedRoomsCount = state.bookings
        .where((b) => b.bookingStatus == 'checked-in')
        .length;

    // Filter Bookings
    final filteredBookings = state.bookings.where((b) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            b.id.toLowerCase().contains(q) ||
            b.guestName.toLowerCase().contains(q) ||
            b.guestPhone.toLowerCase().contains(q) ||
            b.guestEmail.toLowerCase().contains(q) ||
            b.guestNIC.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedPropertyId != null && _selectedPropertyId != 'All') {
        if (b.propertyId != _selectedPropertyId) return false;
      }
      if (_selectedRoomType != 'All') {
        if (b.roomType.toLowerCase() != _selectedRoomType.toLowerCase())
          return false;
      }
      if (_selectedBookingStatus != 'All') {
        if (b.bookingStatus.replaceAll('-', ' ').toLowerCase() !=
            _selectedBookingStatus.replaceAll('-', ' ').toLowerCase())
          return false;
      }
      if (_selectedPaymentStatus != 'All') {
        if (b.paymentStatus.toLowerCase() !=
            _selectedPaymentStatus.toLowerCase())
          return false;
      }
      if (_selectedDateRange != 'All') {
        final checkInDay = DateTime(
          b.checkIn.year,
          b.checkIn.month,
          b.checkIn.day,
        );
        if (_selectedDateRange == 'Today' && checkInDay != today) return false;
        if (_selectedDateRange == 'Tomorrow' && checkInDay != tomorrow)
          return false;
        if (_selectedDateRange == 'This Week') {
          final diff = checkInDay.difference(today).inDays;
          if (diff < 0 || diff > 7) return false;
        }
        if (_selectedDateRange == 'This Month' &&
            (b.checkIn.year != today.year || b.checkIn.month != today.month))
          return false;
      }
      if (_selectedQuickFilter != 'None') {
        if (_selectedQuickFilter == 'Arrivals') {
          final checkInDay = DateTime(
            b.checkIn.year,
            b.checkIn.month,
            b.checkIn.day,
          );
          if (checkInDay != today) return false;
        }
        if (_selectedQuickFilter == 'Departures') {
          final checkOutDay = DateTime(
            b.checkOut.year,
            b.checkOut.month,
            b.checkOut.day,
          );
          if (checkOutDay != today) return false;
        }
        if (_selectedQuickFilter == 'Pending Payments') {
          if (b.paymentStatus != 'pending' && b.paymentStatus != 'partial')
            return false;
        }
        if (_selectedQuickFilter == 'Cancelled Bookings') {
          if (b.bookingStatus != 'cancelled') return false;
        }
        if (_selectedQuickFilter == 'In-House Guests') {
          if (b.bookingStatus != 'checked-in') return false;
        }
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Booking Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Booking'),
                      onPressed: () => _showBookingDialog(context, rooms),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: Icon(
                        _isCalendarView ? Icons.list : Icons.calendar_month,
                        size: 18,
                      ),
                      label: Text(
                        _isCalendarView ? 'List View' : 'Calendar View',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _isCalendarView
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF475569),
                        side: BorderSide(
                          color: _isCalendarView
                              ? const Color(0xFF2563EB)
                              : Colors.grey.shade300,
                        ),
                      ),
                      onPressed: () =>
                          setState(() => _isCalendarView = !_isCalendarView),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Operational statistics: Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1000;
                final cardWidth = isDesktop
                    ? (constraints.maxWidth - (12 * 4)) / 5
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Total Bookings',
                        '$totalBookingsCount',
                        Icons.bookmark_outline,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        "Today's Check-Ins",
                        '$todayCheckInsCount',
                        Icons.login,
                        Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        "Today's Check-Outs",
                        '$todayCheckOutsCount',
                        Icons.logout,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Pending Payments',
                        '$pendingPaymentsCount',
                        Icons.payment,
                        Colors.red,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Occupied Rooms',
                        '$occupiedRoomsCount',
                        Icons.hotel,
                        Colors.purple,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Filters Section Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth > 1000;
                        final double itemWidth = isDesktop
                            ? (constraints.maxWidth - (12 * 3)) / 4
                            : (constraints.maxWidth - 12) / 2;
                        final double searchWidth = isDesktop
                            ? itemWidth * 2 + 12
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: searchWidth,
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Search Booking ID, Guest, Phone, Email...',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedPropertyId ?? 'All',
                                items: [
                                  const DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Properties'),
                                  ),
                                  ...ref
                                      .read(propertyProvider)
                                      .properties
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p.id,
                                          child: Text(p.name),
                                        ),
                                      ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedPropertyId = v),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedRoomType,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Room Types'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Single',
                                    child: Text('Single'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Double',
                                    child: Text('Double'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Triple',
                                    child: Text('Triple'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Deluxe',
                                    child: Text('Deluxe'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Family',
                                    child: Text('Family'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Suite',
                                    child: Text('Suite'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Cabana',
                                    child: Text('Cabana'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Presidential',
                                    child: Text('Presidential'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedRoomType = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedBookingStatus,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Statuses'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'draft',
                                    child: Text('Draft'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pending-payment',
                                    child: Text('Pending Payment'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'confirmed',
                                    child: Text('Confirmed'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'checked-in',
                                    child: Text('Checked In'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'checked-out',
                                    child: Text('Checked Out'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'completed',
                                    child: Text('Completed'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cancelled',
                                    child: Text('Cancelled'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedBookingStatus = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedPaymentStatus,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Payments'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pending',
                                    child: Text('Pending'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'partial',
                                    child: Text('Partial'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'paid',
                                    child: Text('Paid'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'refunded',
                                    child: Text('Refunded'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedPaymentStatus = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDateRange,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Dates'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Today',
                                    child: Text('Today'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Tomorrow',
                                    child: Text('Tomorrow'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'This Week',
                                    child: Text('This Week'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'This Month',
                                    child: Text('This Month'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedDateRange = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedQuickFilter,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'None',
                                    child: Text('No Quick Filter'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Arrivals',
                                    child: Text("Today's Arrivals"),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Departures',
                                    child: Text("Today's Departures"),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Pending Payments',
                                    child: Text('Pending Payments'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Cancelled Bookings',
                                    child: Text('Cancelled Bookings'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'In-House Guests',
                                    child: Text('In-House Guests'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedQuickFilter = v!),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.filter_alt_off,
                                color: Colors.red,
                              ),
                              tooltip: 'Clear Filters',
                              onPressed: _clearFilters,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Recommended Table
            _isCalendarView
                ? _buildCalendarView(filteredBookings)
                : state.isLoading && state.bookings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : filteredBookings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No bookings match filters.'),
                    ),
                  )
                : WebDataTable(
                    showSearch: false,
                    searchHint: 'Filtered Bookings',
                    columns: const [
                      DataColumn(label: Text('Booking ID')),
                      DataColumn(label: Text('Guest')),
                      DataColumn(label: Text('Property')),
                      DataColumn(label: Text('Room')),
                      DataColumn(label: Text('Check-In')),
                      DataColumn(label: Text('Check-Out')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Payment')),
                      DataColumn(label: Text('Total')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredBookings
                        .map((b) => _bookingRow(b, isAdmin, canManage))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataCell> _bookingRow(Booking b, bool isAdmin, bool canManage) {
    return [
      DataCell(
        Text(
          b.code.isNotEmpty
              ? b.code
              : '#${b.id.substring(b.id.length > 8 ? b.id.length - 8 : 0)}',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      DataCell(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              b.guestName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              b.guestPhone,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
      DataCell(Text(b.propertyName)),
      DataCell(Text('${b.roomNumber} (${b.roomType.toUpperCase()})')),
      DataCell(Text(DateFormat('dd MMM yyyy').format(b.checkIn))),
      DataCell(Text(DateFormat('dd MMM yyyy').format(b.checkOut))),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(b.bookingStatus).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            b.bookingStatus.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _statusColor(b.bookingStatus),
            ),
          ),
        ),
      ),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _paymentColor(b.paymentStatus).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            b.paymentStatus.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _paymentColor(b.paymentStatus),
            ),
          ),
        ),
      ),
      DataCell(
        Text(
          isAdmin
              ? 'Rs. ${b.totalAmount.toStringAsFixed(0)}'
              : 'Rs. ${b.roomCharge.toStringAsFixed(0)}',
        ),
      ),
      DataCell(
        ElevatedButton(
          onPressed: () => _showBookingDetails(b, isAdmin, canManage),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('View'),
        ),
      ),
    ];
  }

  void _showBookingDetails(Booking b, bool isAdmin, bool canManage) {
    bool hasLoadedPayments = false;
    List<Payment> bookingPayments = [];
    bool isLoadingPayments = true;
    Booking currentBooking = b;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDetailsState) {
          if (!hasLoadedPayments) {
            hasLoadedPayments = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                final response = await ref
                    .read(apiClientProvider)
                    .get(
                      '/properties/${currentBooking.propertyId}/payments',
                      queryParameters: {'bookingId': currentBooking.id},
                    );
                final paymentsList =
                    (response.data['data']['payments'] as List?)
                        ?.map(
                          (p) => Payment.fromJson(p as Map<String, dynamic>),
                        )
                        .toList() ??
                    [];
                setDetailsState(() {
                  bookingPayments = paymentsList;
                  isLoadingPayments = false;
                });
              } catch (e) {
                setDetailsState(() {
                  isLoadingPayments = false;
                });
              }
            });
          }

          return AlertDialog(
            scrollable: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentBooking.code.isNotEmpty
                      ? 'Booking Details - ${currentBooking.code}'
                      : 'Booking Details',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 960,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(
                        currentBooking.bookingStatus,
                      ).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _statusColor(
                          currentBooking.bookingStatus,
                        ).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(currentBooking.bookingStatus),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentBooking.bookingStatus
                                .replaceAll('-', ' ')
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          currentBooking.code.isNotEmpty
                              ? currentBooking.code
                              : '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${currentBooking.guestName}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (canManage) ...[
                          _statusActionBtn(
                            'Edit',
                            Icons.edit,
                            Colors.indigo,
                            () async {
                              Navigator.pop(ctx);
                              if (currentBooking.propertyId.isNotEmpty) {
                                await ref
                                    .read(roomProvider.notifier)
                                    .fetchRooms(currentBooking.propertyId);
                              }
                              final rooms = ref.read(roomProvider).rooms;
                              await _showBookingDialog(
                                context,
                                rooms,
                                booking: currentBooking,
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          if (currentBooking.bookingStatus == 'confirmed')
                            _statusActionBtn(
                              'Check In',
                              Icons.login,
                              const Color(0xFF2E7D32),
                              () async {
                                final success = await ref
                                    .read(bookingProvider.notifier)
                                    .checkIn(currentBooking.id);
                                if (success) {
                                  try {
                                    final res = await ref
                                        .read(apiClientProvider)
                                        .get('/bookings/${currentBooking.id}');
                                    setDetailsState(() {
                                      currentBooking = Booking.fromJson(
                                        res.data['data']['booking'],
                                      );
                                    });
                                  } catch (_) {}
                                  _loadData();
                                }
                              },
                            ),
                          if (currentBooking.bookingStatus == 'checked-in')
                            _statusActionBtn(
                              'Check Out',
                              Icons.logout,
                              const Color(0xFF1565C0),
                              () async {
                                final success = await ref
                                    .read(bookingProvider.notifier)
                                    .checkOut(currentBooking.id);
                                if (success) {
                                  try {
                                    final res = await ref
                                        .read(apiClientProvider)
                                        .get('/bookings/${currentBooking.id}');
                                    setDetailsState(() {
                                      currentBooking = Booking.fromJson(
                                        res.data['data']['booking'],
                                      );
                                    });
                                  } catch (_) {}
                                  _loadData();
                                }
                              },
                            ),
                          if (currentBooking.bookingStatus != 'cancelled' &&
                              currentBooking.bookingStatus != 'checked-out' &&
                              currentBooking.bookingStatus != 'completed') ...[
                            const SizedBox(width: 6),
                            _statusActionBtn(
                              'Cancel',
                              Icons.cancel,
                              Colors.red,
                              () async {
                                Navigator.pop(ctx);
                                await _doCancel(currentBooking);
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Row (secondary actions)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.payment, size: 14),
                        label: const Text(
                          'Request Payment',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _generatePaymentLink(currentBooking),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          side: BorderSide(color: Colors.indigo.shade300),
                          foregroundColor: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print, size: 14),
                        label: const Text(
                          'Generate Invoice',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _printInvoice(currentBooking),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          side: BorderSide(color: Colors.blue.shade300),
                          foregroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Layout of 10 Sections
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      // Section 1
                      _detailBlock(
                        'Booking Information',
                        Icons.receipt_long,
                        const Color(0xFF1565C0),
                        [
                          _detailRow(
                            'Booking ID',
                            currentBooking.code.isNotEmpty
                                ? currentBooking.code
                                : currentBooking.id
                                      .substring(
                                        currentBooking.id.length > 8
                                            ? currentBooking.id.length - 8
                                            : 0,
                                      )
                                      .toUpperCase(),
                          ),
                          _detailRow(
                            'Booking Date',
                            DateFormat(
                              'dd MMM yyyy HH:mm',
                            ).format(currentBooking.bookingDate),
                          ),
                          _detailStatusRow(
                            'Status',
                            currentBooking.bookingStatus
                                .replaceAll('-', ' ')
                                .toUpperCase(),
                            _statusColor(currentBooking.bookingStatus),
                          ),
                          _detailRow(
                            'Created By',
                            currentBooking.createdByName,
                          ),
                          if (currentBooking.specialRequests.isNotEmpty)
                            _detailRow(
                              'Special Requests',
                              currentBooking.specialRequests,
                            ),
                        ],
                      ),
                      // Section 2
                      _detailBlock(
                        'Guest Information',
                        Icons.person,
                        const Color(0xFF2E7D32),
                        [
                          _detailRow('Guest Name', currentBooking.guestName),
                          _detailRow('Phone', currentBooking.guestPhone),
                          _detailRow('Email', currentBooking.guestEmail),
                          if (currentBooking.guestNIC.isNotEmpty)
                            _detailRow('NIC', currentBooking.guestNIC),
                          if (currentBooking.guestNationality.isNotEmpty)
                            _detailRow(
                              'Nationality',
                              currentBooking.guestNationality,
                            ),
                        ],
                      ),
                      // Section 3
                      _detailBlock(
                        'Property & Room',
                        Icons.home,
                        const Color(0xFF6A1B9A),
                        [
                          _detailRow('Property', currentBooking.propertyName),
                          _detailRow('Address', currentBooking.propertyAddress),
                          _detailRow(
                            'Room',
                            '${currentBooking.roomNumber} (${currentBooking.roomType.toUpperCase()})',
                          ),
                          _detailRow(
                            'Capacity',
                            '${currentBooking.roomCapacity} Guests',
                          ),
                          _detailRow(
                            'Price/Night',
                            'LKR ${currentBooking.roomPricePerNight.toStringAsFixed(0)}',
                          ),
                        ],
                      ),
                      // Section 4
                      _detailBlock(
                        'Stay Details',
                        Icons.calendar_month,
                        const Color(0xFFE65100),
                        [
                          _detailRow(
                            'Check-In',
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(currentBooking.checkIn),
                          ),
                          _detailRow(
                            'Check-Out',
                            DateFormat(
                              'dd MMM yyyy',
                            ).format(currentBooking.checkOut),
                          ),
                          _detailHighlightRow(
                            'Nights',
                            '${currentBooking.nights}',
                            const Color(0xFFE65100),
                          ),
                          _detailRow('Adults', '${currentBooking.adults}'),
                          _detailRow('Children', '${currentBooking.children}'),
                          _detailRow(
                            'Total Guests',
                            '${currentBooking.numberOfGuests}',
                          ),
                        ],
                      ),
                      // Section 5
                      _detailBlock(
                        'Pricing',
                        Icons.attach_money,
                        const Color(0xFF00695C),
                        [
                          _detailRow(
                            'Room Charge',
                            'LKR ${currentBooking.roomCharge.toStringAsFixed(0)}',
                          ),
                          _detailRow(
                            'Meal Plan',
                            currentBooking.mealPlan.isNotEmpty
                                ? currentBooking.mealPlan
                                : 'None',
                          ),
                          if (isAdmin && currentBooking.mealPlanTotal > 0)
                            _detailRow(
                              'Meal Plan Charge',
                              'LKR ${currentBooking.mealPlanTotal.toStringAsFixed(0)}',
                            ),
                          if (isAdmin && currentBooking.discount > 0)
                            _detailRow(
                              'Discount',
                              '- LKR ${currentBooking.discount.toStringAsFixed(0)}',
                            ),
                          if (isAdmin && currentBooking.tax > 0)
                            _detailRow(
                              'Taxes',
                              'LKR ${currentBooking.tax.toStringAsFixed(0)}',
                            ),
                          if (isAdmin) ...[
                            const Divider(height: 12),
                            _detailHighlightRow(
                              'Total',
                              'LKR ${currentBooking.totalAmount.toStringAsFixed(0)}',
                              const Color(0xFF00695C),
                            ),
                          ],
                        ],
                      ),
                      // Section 6
                      _detailBlock('Payment', Icons.payments, const Color(0xFF1565C0), [
                        _detailStatusRow(
                          'Payment Status',
                          currentBooking.paymentStatus.toUpperCase(),
                          _paymentColor(currentBooking.paymentStatus),
                        ),
                        if (isAdmin)
                          _detailRow(
                            'Paid Amount',
                            'LKR ${currentBooking.amountPaid.toStringAsFixed(0)}',
                          ),
                        if (isAdmin)
                          _detailHighlightRow(
                            'Outstanding',
                            'LKR ${(currentBooking.totalAmount - currentBooking.amountPaid).toStringAsFixed(0)}',
                            (currentBooking.totalAmount -
                                        currentBooking.amountPaid) >
                                    0
                                ? Colors.red
                                : const Color(0xFF2E7D32),
                          ),
                        _detailRow(
                          'Method',
                          currentBooking.paymentMethod.isNotEmpty
                              ? currentBooking.paymentMethod
                              : 'N/A',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 14,
                              color: Colors.blueGrey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Payment History',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (isLoadingPayments)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (bookingPayments.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Text(
                              'No payment records found.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...bookingPayments.map(
                            (p) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    (p.status == 'completed' ||
                                        p.status == 'paid')
                                    ? Colors.green.shade50
                                    : p.status == 'pending'
                                    ? Colors.orange.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      (p.status == 'completed' ||
                                          p.status == 'paid')
                                      ? Colors.green.shade200
                                      : p.status == 'pending'
                                      ? Colors.orange.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    (p.status == 'completed' ||
                                            p.status == 'paid')
                                        ? Icons.check_circle
                                        : p.status == 'pending'
                                        ? Icons.schedule
                                        : Icons.cancel,
                                    size: 16,
                                    color:
                                        (p.status == 'completed' ||
                                            p.status == 'paid')
                                        ? Colors.green.shade600
                                        : p.status == 'pending'
                                        ? Colors.orange.shade600
                                        : Colors.red.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LKR ${p.amount.toStringAsFixed(0)} (${p.type.toUpperCase()})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${p.code.isNotEmpty ? p.code : ''} • ${DateFormat('dd MMM yyyy').format(p.createdAt)} • ${p.method.toUpperCase()}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (p.status == 'completed' ||
                                              p.status == 'paid')
                                          ? Colors.green
                                          : p.status == 'pending'
                                          ? Colors.orange
                                          : Colors.red,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      p.status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (canManage &&
                            (currentBooking.totalAmount -
                                    currentBooking.amountPaid) >
                                0)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text(
                                'Record Payment',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: () => _showRecordPaymentDialog(
                                context,
                                currentBooking,
                                (currentBooking.totalAmount -
                                    currentBooking.amountPaid),
                                () async {
                                  try {
                                    final res = await ref
                                        .read(apiClientProvider)
                                        .get('/bookings/${currentBooking.id}');
                                    final updated = Booking.fromJson(
                                      res.data['data']['booking'],
                                    );
                                    hasLoadedPayments = false;
                                    setDetailsState(() {
                                      currentBooking = updated;
                                    });
                                    _loadData();
                                  } catch (e) {
                                    // handle error
                                  }
                                },
                              ),
                            ),
                          ),
                      ]),
                      // Section 7
                      _detailBlock(
                        'Documents',
                        Icons.folder_open,
                        Colors.blueGrey,
                        [
                          _detailActionRow('NIC Copy', 'View', () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Displaying NIC copy...'),
                              ),
                            );
                          }),
                          _detailActionRow('Passport', 'View', () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Displaying Passport copy...'),
                              ),
                            );
                          }),
                        ],
                      ),
                      // Section 8
                      _detailBlock(
                        'Notes',
                        Icons.notes,
                        const Color(0xFF795548),
                        [
                          _detailRow(
                            'Special Requests',
                            currentBooking.specialRequests.isNotEmpty
                                ? currentBooking.specialRequests
                                : 'None',
                          ),
                          _detailRow(
                            'Internal Notes',
                            currentBooking.notes.isNotEmpty
                                ? currentBooking.notes
                                : 'None',
                          ),
                          if (currentBooking.cancellationReason.isNotEmpty)
                            _detailRow(
                              'Cancellation Reason',
                              currentBooking.cancellationReason,
                            ),
                        ],
                      ),
                      // Section 9
                      _detailBlock(
                        'Timeline',
                        Icons.timeline,
                        const Color(0xFF4527A0),
                        [
                          _detailTimelineRow(
                            DateFormat(
                              'dd MMM',
                            ).format(currentBooking.bookingDate),
                            'Reservation Created',
                            Icons.add_circle,
                            const Color(0xFF2E7D32),
                          ),
                          if (currentBooking.paymentStatus != 'pending')
                            _detailTimelineRow(
                              DateFormat(
                                'dd MMM',
                              ).format(currentBooking.bookingDate),
                              'Payment Received',
                              Icons.payment,
                              const Color(0xFF1565C0),
                            ),
                          if (currentBooking.bookingStatus == 'checked-in')
                            _detailTimelineRow(
                              DateFormat(
                                'dd MMM',
                              ).format(currentBooking.checkIn),
                              'Guest Checked In',
                              Icons.login,
                              const Color(0xFF2E7D32),
                            ),
                          if (currentBooking.bookingStatus == 'checked-out' ||
                              currentBooking.bookingStatus == 'completed')
                            _detailTimelineRow(
                              DateFormat(
                                'dd MMM',
                              ).format(currentBooking.checkOut),
                              'Guest Checked Out',
                              Icons.logout,
                              Colors.blueGrey,
                            ),
                          if (currentBooking.bookingStatus == 'cancelled')
                            _detailTimelineRow(
                              DateFormat(
                                'dd MMM',
                              ).format(currentBooking.bookingDate),
                              'Booking Cancelled',
                              Icons.cancel,
                              Colors.red,
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRecordPaymentDialog(
    BuildContext context,
    Booking booking,
    double remainingBalance,
    VoidCallback onSuccess,
  ) async {
    final amountController = TextEditingController(
      text: remainingBalance.toStringAsFixed(0),
    );
    final formKey = GlobalKey<FormState>();
    String method = 'cash';
    String type = remainingBalance >= booking.totalAmount ? 'full' : 'partial';
    String status = 'completed';
    bool isSaving = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: Row(
              children: [
                const Icon(Icons.payment, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'Record Payment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking: ${booking.code}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: LKR ${booking.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Paid: LKR ${booking.amountPaid.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                          const Divider(height: 12),
                          Text(
                            'Outstanding: LKR ${remainingBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    WebFormField(
                      label: 'Amount (LKR)',
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = double.tryParse(v.trim());
                        if (val == null || val <= 0)
                          return 'Must be greater than 0';
                        if (val > remainingBalance + 0.01) {
                          return 'Cannot exceed LKR ${remainingBalance.toStringAsFixed(0)}';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                        DropdownMenuItem(
                          value: 'bank_transfer',
                          child: Text('Bank Transfer'),
                        ),
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('Online'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => method = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'full',
                          child: Text('Full Payment'),
                        ),
                        DropdownMenuItem(
                          value: 'partial',
                          child: Text('Partial Payment'),
                        ),
                        DropdownMenuItem(
                          value: 'advance',
                          child: Text('Advance'),
                        ),
                        DropdownMenuItem(
                          value: 'refund',
                          child: Text('Refund'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => type = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => status = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Payment Status',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 14),
                label: Text(isSaving ? 'Recording...' : 'Record Payment'),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });
                        try {
                          final success = await ref
                              .read(paymentProvider.notifier)
                              .createPayment(booking.propertyId, {
                                'booking': booking.id,
                                'amount': double.parse(amountController.text),
                                'method': method,
                                'type': type,
                                'status': status,
                              });
                          if (success) {
                            onSuccess();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Payment recorded successfully',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage =
                                  'Failed to record payment. It may already exist.';
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = e.toString().replaceAll(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailBlock(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return SizedBox(
      width: 420,
      child: Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailHighlightRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailTimelineRow(
    String date,
    String event,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            date,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailActionRow(
    String label,
    String actionLabel,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 13),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          elevation: 0,
        ),
      ),
    );
  }

  void _generatePaymentLink(Booking b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PayHere Payment Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Generated payment gateway link for guest:'),
            const SizedBox(height: 12),
            SelectableText(
              'https://sandbox.payhere.lk/pay/checkout?merchant_id=1211122&order_id=${b.id}&amount=${b.totalAmount - b.amountPaid}&currency=LKR',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _printInvoice(Booking b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Invoice #${b.id.substring(b.id.length - 8).toUpperCase()}',
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EASEINN PMS RECEIPT',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Divider(),
              Text('Guest: ${b.guestName}'),
              Text('Room: Room ${b.roomNumber} (${b.roomType.toUpperCase()})'),
              Text(
                'Dates: ${DateFormat('dd MMM yyyy').format(b.checkIn)} - ${DateFormat('dd MMM yyyy').format(b.checkOut)}',
              ),
              Text('Nights: ${b.nights}'),
              const Divider(),
              Text('Total Amount: LKR ${b.totalAmount.toStringAsFixed(0)}'),
              Text(
                'Paid Amount: LKR ${b.amountPaid.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.green),
              ),
              Text(
                'Balance Due: LKR ${(b.totalAmount - b.amountPaid).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const Divider(),
              const Center(
                child: Text(
                  'Thank you for choosing EaseInn!',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _doCancel(Booking booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isConfirmed = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Cancel Booking'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Are you sure you want to cancel the booking for ${booking.guestName}? This action cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Cancellation *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isConfirmed,
                        onChanged: (val) {
                          setDialogState(() {
                            isConfirmed = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I confirm I want to cancel this booking.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmed ? Colors.red : Colors.grey,
                  ),
                  onPressed: isConfirmed
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text('Cancel Booking'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final success = await ref
          .read(bookingProvider.notifier)
          .cancelBooking(booking.id, reasonController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Booking cancelled' : 'Failed to cancel'),
            backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
          ),
        );
      }
      _loadData();
    }
  }

  Future<void> _showBookingDialog(
    BuildContext context,
    List<Room> rooms, {
    Booking? booking,
  }) async {
    final formKey = GlobalKey<FormState>();
    final guestNameController = TextEditingController(
      text: booking?.guestName ?? '',
    );
    final guestEmailController = TextEditingController(
      text: booking?.guestEmail ?? '',
    );
    final guestPhoneController = TextEditingController(
      text: booking?.guestPhone ?? '',
    );
    final guestsCountController = TextEditingController(
      text: booking?.numberOfGuests.toString() ?? '1',
    );
    final adultsController = TextEditingController(
      text: booking?.adults.toString() ?? '1',
    );
    final childrenController = TextEditingController(
      text: booking?.children.toString() ?? '0',
    );
    final specialRequestsController = TextEditingController(
      text: booking?.specialRequests ?? '',
    );

    final properties = ref.read(propertyProvider).properties;
    String? selectedPropertyId =
        booking?.propertyId ??
        (properties.isNotEmpty ? properties.first.id : null);

    String? selectedRoomId;
    if (booking != null) {
      selectedRoomId = booking.roomId.isNotEmpty ? booking.roomId : null;
    }

    DateTime? checkIn = booking?.checkIn;
    DateTime? checkOut = booking?.checkOut;
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final displayId = booking != null
              ? (booking.id.length > 8
                    ? booking.id.substring(booking.id.length - 8).toUpperCase()
                    : booking.id.toUpperCase())
              : '';
          return AlertDialog(
            scrollable: true,
            title: Text(
              booking == null ? 'New Booking' : 'Edit Booking - #$displayId',
            ),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WebFormField(
                      label: 'Guest Name',
                      controller: guestNameController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    WebFormField(
                      label: 'Email',
                      controller: guestEmailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(v.trim()))
                          return 'Invalid email address';
                        return null;
                      },
                    ),
                    WebFormField(
                      label: 'Phone',
                      controller: guestPhoneController,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final phoneRegex = RegExp(r'^\+?[0-9\s\-]{8,15}$');
                        if (!phoneRegex.hasMatch(v.trim()))
                          return 'Invalid phone number';
                        return null;
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: WebFormField(
                            label: 'Adults',
                            controller: adultsController,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: WebFormField(
                            label: 'Children',
                            controller: childrenController,
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    WebFormField(
                      label: 'Total Guests (Validation)',
                      controller: guestsCountController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final count = int.tryParse(v);
                        if (count == null || count < 1) {
                          return 'Must be at least 1';
                        }
                        if (selectedRoomId != null) {
                          try {
                            final room = rooms.firstWhere(
                              (r) => r.id == selectedRoomId,
                            );
                            if (count > room.capacity) {
                              return 'Exceeds room capacity (${room.capacity})';
                            }
                          } catch (_) {}
                        }
                        return null;
                      },
                    ),
                    WebFormField(
                      label: 'Special Requests / Notes',
                      controller: specialRequestsController,
                      maxLines: 2,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPropertyId,
                        isExpanded: true,
                        items: properties
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          setDialogState(() => selectedPropertyId = v);
                          if (v != null) {
                            await ref.read(roomProvider.notifier).fetchRooms(v);
                            setDialogState(() {
                              selectedRoomId = null;
                            });
                          }
                        },
                        validator: (v) =>
                            v == null ? 'Select a property' : null,
                        decoration: const InputDecoration(
                          labelText: 'Property',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Builder(
                        builder: (ctx) {
                          final currentRooms = ref.watch(roomProvider).rooms;
                          final availableForSelection = currentRooms
                              .where(
                                (r) =>
                                    r.status == 'available' ||
                                    (booking != null && r.id == booking.roomId),
                              )
                              .toList();
                          return DropdownButtonFormField<String>(
                            initialValue: selectedRoomId,
                            isExpanded: true,
                            items: availableForSelection
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r.id,
                                    child: Text(
                                      '${r.roomNumber} - ${r.roomType} (LKR ${r.basePrice.toStringAsFixed(0)}/night)',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedRoomId = v),
                            validator: (v) =>
                                v == null ? 'Select a room' : null,
                            decoration: const InputDecoration(
                              labelText: 'Room',
                              border: OutlineInputBorder(),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: checkIn ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date != null) {
                            setDialogState(() => checkIn = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Check-in Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            checkIn != null
                                ? DateFormat('MMM dd, yyyy').format(checkIn!)
                                : 'Select date',
                            style: TextStyle(
                              color: checkIn != null
                                  ? null
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate:
                                checkOut ??
                                checkIn?.add(const Duration(days: 1)) ??
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: checkIn ?? DateTime(2020),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date != null) {
                            setDialogState(() => checkOut = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Check-out Date',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            checkOut != null
                                ? DateFormat('MMM dd, yyyy').format(checkOut!)
                                : 'Select date',
                            style: TextStyle(
                              color: checkOut != null
                                  ? null
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (checkIn == null || checkOut == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select check-in and check-out dates',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        if (checkOut!.isBefore(checkIn!)) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Check-out must be after check-in'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        if (selectedPropertyId == null ||
                            selectedRoomId == null) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select a property and room',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        final currentRooms = ref.read(roomProvider).rooms;
                        final selectedRoom = currentRooms.isNotEmpty
                            ? currentRooms
                                  .where((r) => r.id == selectedRoomId)
                                  .firstOrNull
                            : null;
                        if (selectedRoom == null) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Selected room not found. Please re-select.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        final bookingData = {
                          'property': selectedPropertyId,
                          'room': selectedRoomId,
                          'guest': {
                            'name': guestNameController.text.trim(),
                            'email': guestEmailController.text.trim(),
                            'phone': guestPhoneController.text.trim(),
                          },
                          'checkIn': checkIn!.toIso8601String(),
                          'checkOut': checkOut!.toIso8601String(),
                          'numberOfGuests': int.parse(
                            guestsCountController.text,
                          ),
                          'adults': int.parse(adultsController.text),
                          'children': int.parse(childrenController.text),
                          'specialRequests': specialRequestsController.text
                              .trim(),
                          'roomType': selectedRoom.roomType,
                        };
                        final success = booking == null
                            ? await ref
                                  .read(bookingProvider.notifier)
                                  .createBooking(bookingData)
                            : await ref
                                  .read(bookingProvider.notifier)
                                  .updateBooking(booking.id, bookingData);
                        if (!success && ctx.mounted) {
                          final error = ref.read(bookingProvider).error;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(error ?? 'Operation failed'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          setDialogState(() => isSaving = false);
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx, success);
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(booking == null ? 'Create' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            booking == null ? 'Booking created' : 'Booking updated',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadData();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF1565C0);
      case 'checked-in':
      case 'checked_in':
        return const Color(0xFF2E7D32);
      case 'checked-out':
      case 'checked_out':
        return Colors.grey;
      case 'cancelled':
        return const Color(0xFFC62828);
      default:
        return Colors.orange;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF2E7D32);
      case 'pending':
        return Colors.orange;
      case 'partial':
        return const Color(0xFFE65100);
      case 'refunded':
        return const Color(0xFF1565C0);
      default:
        return Colors.grey;
    }
  }

  Widget _buildCalendarView(List<Booking> bookings) {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = lastDay.day;
    final today = DateTime.now();

    List<Booking> getBookingsForDay(DateTime date) {
      final targetDate = DateTime(date.year, date.month, date.day);
      return bookings.where((b) {
        final start = DateTime(b.checkIn.year, b.checkIn.month, b.checkIn.day);
        final end = DateTime(b.checkOut.year, b.checkOut.month, b.checkOut.day);
        return !targetDate.isBefore(start) && !targetDate.isAfter(end);
      }).toList();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getMonthName(_calendarMonth.month)} ${_calendarMonth.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(
                        () => _calendarMonth = DateTime(
                          _calendarMonth.year,
                          _calendarMonth.month - 1,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _calendarMonth = DateTime.now()),
                      child: const Text('Today'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(
                        () => _calendarMonth = DateTime(
                          _calendarMonth.year,
                          _calendarMonth.month + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map(
                    (day) => Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.5,
              ),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (ctx, index) {
                if (index < startWeekday) return const SizedBox();
                final day = index - startWeekday + 1;
                final date = DateTime(
                  _calendarMonth.year,
                  _calendarMonth.month,
                  day,
                );
                final isToday =
                    date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final dayBookings = getBookingsForDay(date);

                return GestureDetector(
                  onTap: dayBookings.isNotEmpty
                      ? () => _showDayBookingsDialog(date, dayBookings)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF2563EB).withOpacity(0.08)
                          : dayBookings.isNotEmpty
                          ? const Color(0xFF475569).withOpacity(0.03)
                          : null,
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (dayBookings.isNotEmpty)
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              children: dayBookings
                                  .take(2)
                                  .map(
                                    (b) => Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                          b.bookingStatus,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        b.guestName,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(b.bookingStatus),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
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

  void _showDayBookingsDialog(DateTime date, List<Booking> bookings) {
    final isAdmin = ref.read(authProvider).user?.isAdmin ?? false;
    final isManager = ref.read(authProvider).user?.isManager ?? false;
    final canManage = isAdmin || isManager;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Bookings - ${DateFormat('dd MMM yyyy').format(date)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 500,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    b.guestName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Room ${b.roomNumber} (${b.roomType}) • ${b.bookingStatus.toUpperCase()}',
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showBookingDetails(b, isAdmin, canManage);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('View'),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
