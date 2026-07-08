import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import '../widgets/web_data_table.dart';
import '../widgets/web_form_dialog.dart';

/// Main room management screen for admin and manager roles.
class WebRoomsScreen extends ConsumerStatefulWidget {
  const WebRoomsScreen({super.key});

  @override
  ConsumerState<WebRoomsScreen> createState() => _WebRoomsScreenState();
}

class _WebRoomsScreenState extends ConsumerState<WebRoomsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  String _searchQuery = '';
  String? _selectedPropertyId = 'All';
  String _selectedRoomType = 'All';
  String _selectedRoomStatus = 'All';
  double? _minPrice; // Price range filter lower bound
  double? _maxPrice; // Price range filter upper bound

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _minPriceController.addListener(() {
      final val = double.tryParse(_minPriceController.text);
      setState(() => _minPrice = val);
    });
    _maxPriceController.addListener(() {
      final val = double.tryParse(_maxPriceController.text);
      setState(() => _maxPrice = val);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  /// Initial data load: fetch properties, then rooms for the selected property.
  Future<void> _loadData() async {
    await ref.read(propertyProvider.notifier).fetchProperties();
    final properties = ref.read(propertyProvider).properties;
    if (properties.isNotEmpty) {
      final pid = _selectedPropertyId ?? 'All';
      _selectedPropertyId ??= 'All';
      await _fetchRoomsForProperty(pid);
    }
  }

  /// Fetches rooms for a specific property or all properties if pid == 'All'.
  /// Updates the roomProvider state with loading indicator and results.
  Future<void> _fetchRoomsForProperty(String pid) async {
    final properties = ref.read(propertyProvider).properties;
    if (pid == 'All') {
      // Show loading state immediately while fetching from multiple properties
      ref.read(roomProvider.notifier).state = RoomState(
        isLoading: true,
        rooms: [],
      );
      try {
        final List<Room> allRooms = [];
        for (final p in properties) {
          final response = await ref
              .read(apiClientProvider)
              .get('/properties/${p.id}/rooms');
          final data = response.data['data'];
          final rooms = (data['rooms'] as List)
              .map((r) => Room.fromJson(r as Map<String, dynamic>))
              .toList();
          allRooms.addAll(rooms);
        }
        ref.read(roomProvider.notifier).state = RoomState(
          rooms: allRooms,
          isLoading: false,
          total: allRooms.length,
        );
      } catch (e) {
        ref.read(roomProvider.notifier).state = RoomState(
          isLoading: false,
          error: e.toString(),
        );
      }
    } else {
      await ref.read(roomProvider.notifier).fetchRooms(pid);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _selectedRoomType = 'All';
      _selectedRoomStatus = 'All';
      _minPrice = null;
      _maxPrice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomProvider);
    final properties = ref.watch(propertyProvider).properties;

    // Filter Rooms
    final filteredRooms = state.rooms.where((r) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            r.roomNumber.toLowerCase().contains(q) ||
            r.roomType.toLowerCase().contains(q) ||
            r.name.toLowerCase().contains(q) ||
            r.amenities.any((a) => a.toLowerCase().contains(q));
        if (!match) return false;
      }
      if (_selectedRoomType != 'All') {
        if (r.roomType.toLowerCase() != _selectedRoomType.toLowerCase())
          return false;
      }
      if (_selectedRoomStatus != 'All') {
        if (r.status.toLowerCase() != _selectedRoomStatus.toLowerCase())
          return false;
      }
      if (_minPrice != null) {
        if (r.basePrice < _minPrice!) return false;
      }
      if (_maxPrice != null) {
        if (r.basePrice > _maxPrice!) return false;
      }
      return true;
    }).toList();

    // Summary count calculations
    final totalRooms = state.rooms.length;
    final availableRooms = state.rooms
        .where((r) => r.status.toLowerCase() == 'available')
        .length;
    final occupiedRooms = state.rooms
        .where((r) => r.status.toLowerCase() == 'occupied')
        .length;
    final maintenanceRooms = state.rooms
        .where((r) => r.status.toLowerCase() == 'maintenance')
        .length;

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
                  'Room Management',
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
                      label: const Text('Add Room'),
                      onPressed: () => _showRoomDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Bulk Add'),
                      onPressed: () => _showBulkAddDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1000;
                final cardWidth = isDesktop
                    ? (constraints.maxWidth - (16 * 3)) / 4
                    : (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Total Rooms',
                        '$totalRooms',
                        Icons.meeting_room,
                        const Color(0xFF2563EB),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Available',
                        '$availableRooms',
                        Icons.check_circle_outline,
                        const Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Occupied',
                        '$occupiedRooms',
                        Icons.hotel,
                        const Color(0xFF3B82F6),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Maintenance',
                        '$maintenanceRooms',
                        Icons.build,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                );
              },
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
                                  hintText: 'Search Room Number, Name...',
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
                                  ...properties.map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedPropertyId = v);
                                    _fetchRoomsForProperty(v);
                                  }
                                },
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
                                    value: 'deluxe',
                                    child: Text('Deluxe'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'family',
                                    child: Text('Family'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'suite',
                                    child: Text('Suite'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cabana',
                                    child: Text('Cabana'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'single',
                                    child: Text('Single'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'double',
                                    child: Text('Double'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'presidential',
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
                                initialValue: _selectedRoomStatus,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Statuses'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'available',
                                    child: Text('Available'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'occupied',
                                    child: Text('Occupied'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'booked',
                                    child: Text('Booked'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'maintenance',
                                    child: Text('Maintenance'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedRoomStatus = v!),
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

            // Rooms List Table
            state.isLoading && state.rooms.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredRooms.isEmpty
                ? const Center(child: Text('No rooms match filters.'))
                : WebDataTable(
                    showSearch: false,
                    searchHint: 'Filtered Rooms',
                    columns: const [
                      DataColumn(label: Text('Room #')),
                      DataColumn(label: Text('Property')),
                      DataColumn(label: Text('Room Type')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Current Booking')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredRooms
                        .map((r) => _roomRow(r, properties))
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

  List<DataCell> _roomRow(Room r, List<Property> properties) {
    final propertyName = properties
        .firstWhere(
          (p) => p.id == r.propertyId,
          orElse: () => Property(id: '', name: 'Unknown Property'),
        )
        .name;

    return [
      DataCell(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              r.roomNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (r.name.isNotEmpty)
              Text(
                r.name,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
      DataCell(Text(propertyName)),
      DataCell(Text(r.roomType.toUpperCase())),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _roomStatusColor(r.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            r.status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _roomStatusColor(r.status),
            ),
          ),
        ),
      ),
      DataCell(
        r.currentBookingId != null && r.currentBookingId!.isNotEmpty
            ? InkWell(
                onTap: () =>
                    context.go('/web/bookings?search=${r.currentBookingId}'),
                child: Text(
                  r.currentBooking,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            : Text(r.currentBooking),
      ),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              tooltip: 'View',
              onPressed: () => _showRoomDetail(context, r, propertyName),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => _showRoomDialog(context, room: r),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red,
              ),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(r),
            ),
          ],
        ),
      ),
    ];
  }

  void _showRoomDetail(BuildContext context, Room r, String propertyName) {
    int selectedImageIndex = 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.king_bed, size: 20, color: Color(0xFF1565C0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Room ${r.roomNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  propertyName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 960,
              height: MediaQuery.of(context).size.height * 0.75,
              child: SingleChildScrollView(
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
                        color: _roomStatusColor(r.status).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _roomStatusColor(r.status).withOpacity(0.2),
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
                              color: _roomStatusColor(r.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              r.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            r.roomNumber,
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
                            '${r.roomType.toUpperCase()} • Floor ${r.floor}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'LKR ${r.basePrice.toStringAsFixed(0)} / night',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00695C),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (r.images.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          resolveImageUrl(r.images[selectedImageIndex]),
                          height: 350,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            height: 350,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (r.images.length > 1)
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: r.images.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final isSelected = index == selectedImageIndex;
                              return GestureDetector(
                                onTap: () => setDialogState(
                                  () => selectedImageIndex = index,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF1565C0)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      resolveImageUrl(r.images[index]),
                                      width: 120,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          Container(
                                            width: 120,
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _detailBlock(
                          'Room Information',
                          Icons.room,
                          const Color(0xFF1565C0),
                          [
                            _detailRow('Property', propertyName),
                            _detailRow('Room Number', r.roomNumber),
                            _detailRow(
                              'Room Name',
                              r.name.isNotEmpty ? r.name : '-',
                            ),
                            _detailRow('Room Type', r.roomType.toUpperCase()),
                            _detailRow('Floor', '${r.floor}'),
                            _detailHighlightRow(
                              'Base Price',
                              'LKR ${r.basePrice.toStringAsFixed(0)} / night',
                              const Color(0xFF00695C),
                            ),
                          ],
                        ),
                        _detailBlock(
                          'Capacity',
                          Icons.people,
                          const Color(0xFF6A1B9A),
                          [
                            _detailRow('Max Guests', '${r.capacity}'),
                            _detailRow('Max Adults', '${r.capacity}'),
                            _detailRow('Max Children', '1'),
                          ],
                        ),
                        _detailBlock(
                          'Amenities',
                          Icons.chair,
                          const Color(0xFFE65100),
                          [
                            if (r.amenities.isEmpty)
                              const Text(
                                'No amenities listed.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: r.amenities
                                    .map(
                                      (a) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          a,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                        _detailBlock(
                          'Current Status',
                          Icons.info_outline,
                          const Color(0xFF2E7D32),
                          [
                            if (r.currentBookingId != null &&
                                r.currentBookingId!.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _detailRow('Booking ID', r.currentBooking),
                                  _detailRow('Status', 'Occupied'),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.launch, size: 14),
                                      label: const Text(
                                        'View Booking',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        context.go(
                                          '/web/bookings?search=${r.currentBookingId}',
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Available - No active booking',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        _detailBlock(
                          'Maintenance',
                          Icons.build,
                          const Color(0xFF795548),
                          [
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'All checks passed. No issues.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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

  Future<void> _showRoomDialog(BuildContext context, {Room? room}) async {
    final properties = ref.read(propertyProvider).properties;
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No properties available. Create a property first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String selectedPropertyId =
        room?.propertyId ?? (properties.isNotEmpty ? properties.first.id : '');
    final roomNumberController = TextEditingController(
      text: room?.roomNumber ?? '',
    );
    final nameController = TextEditingController(text: room?.name ?? '');
    final capacityController = TextEditingController(
      text: room?.capacity.toString() ?? '3',
    );
    final adultsController = TextEditingController(
      text: room?.capacity.toString() ?? '2',
    );
    final childrenController = TextEditingController(
      text: room != null ? '0' : '1',
    );

    void updateCapacity() {
      final adults = int.tryParse(adultsController.text) ?? 0;
      final children = int.tryParse(childrenController.text) ?? 0;
      capacityController.text = (adults + children).toString();
    }

    adultsController.addListener(updateCapacity);
    childrenController.addListener(updateCapacity);
    final priceController = TextEditingController(
      text: room?.basePrice.toString() ?? '0',
    );
    final floorController = TextEditingController(
      text: room?.floor.toString() ?? '0',
    );
    final descController = TextEditingController(text: room?.name ?? '');
    String roomType = room?.roomType ?? 'deluxe';
    String status = room?.status ?? 'available';

    // List of amenities
    final amenitiesList = [
      'WiFi',
      'AC',
      'TV',
      'Mini Bar',
      'Balcony',
      'Sea View',
    ];
    final selectedAmenities = List<String>.from(room?.amenities ?? []);

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isUploading = false;
    List<String> images = List<String>.from(room?.images ?? []);

    Future<void> pickAndUploadImage(StateSetter setDialogState) async {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = true;
      input.click();
      input.onChange.listen((_) async {
        if (input.files == null || input.files!.isEmpty) return;
        final files = input.files!;

        setDialogState(() => isUploading = true);
        try {
          final api = ref.read(apiClientProvider);
          for (final file in files) {
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoad.first;
            final result = reader.result;
            final Uint8List bytes;
            if (result is Uint8List) {
              bytes = result;
            } else if (result is ByteBuffer) {
              bytes = result.asUint8List();
            } else {
              bytes = (result as dynamic).asUint8List() as Uint8List;
            }

            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(bytes, filename: file.name),
            });
            final response = await api.dio.post(
              '/upload/single',
              data: formData,
            );
            final rawUrl = response.data['data']['url'] as String;
            final fullUrl = resolveImageUrl(rawUrl);
            setDialogState(() => images.add(fullUrl));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          setDialogState(() => isUploading = false);
        }
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: Text(room == null ? 'Add Room' : 'Edit Room'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PROPERTY ASSIGNMENT (FIRST FIELD - Mandatory)
                    const Text(
                      'Property Assignment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPropertyId.isEmpty
                          ? null
                          : selectedPropertyId,
                      items: properties
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: room != null
                          ? null
                          : (v) {
                              if (v != null) {
                                setDialogState(() => selectedPropertyId = v);
                              }
                            },
                      decoration: const InputDecoration(
                        labelText: 'Property *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // BASIC ROOM INFORMATION
                    const Text(
                      'Basic Room Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Room Number *',
                      controller: roomNumberController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    WebFormField(
                      label: 'Room Name',
                      controller: nameController,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: roomType,
                        items: const [
                          DropdownMenuItem(
                            value: 'deluxe',
                            child: Text('Deluxe'),
                          ),
                          DropdownMenuItem(
                            value: 'family',
                            child: Text('Family'),
                          ),
                          DropdownMenuItem(
                            value: 'suite',
                            child: Text('Suite'),
                          ),
                          DropdownMenuItem(
                            value: 'cabana',
                            child: Text('Cabana'),
                          ),
                          DropdownMenuItem(
                            value: 'single',
                            child: Text('Single'),
                          ),
                          DropdownMenuItem(
                            value: 'double',
                            child: Text('Double'),
                          ),
                          DropdownMenuItem(
                            value: 'presidential',
                            child: Text('Presidential'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => roomType = v);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Room Type *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),

                    // CAPACITY
                    const Text(
                      'Capacity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Maximum Guests *',
                      controller: capacityController,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    WebFormField(
                      label: 'Maximum Adults',
                      controller: adultsController,
                      keyboardType: TextInputType.number,
                    ),
                    WebFormField(
                      label: 'Maximum Children',
                      controller: childrenController,
                      keyboardType: TextInputType.number,
                    ),

                    // PRICING & FLOOR
                    const Text(
                      'Pricing & Floor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Base Price Per Night *',
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    WebFormField(
                      label: 'Floor',
                      controller: floorController,
                      keyboardType: TextInputType.number,
                    ),

                    // AMENITIES
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    Wrap(
                      children: amenitiesList.map((a) {
                        final isSelected = selectedAmenities.contains(a);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (bool? checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    selectedAmenities.add(a);
                                  } else {
                                    selectedAmenities.remove(a);
                                  }
                                });
                              },
                            ),
                            Text(a),
                            const SizedBox(width: 12),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // DESCRIPTION & IMAGES
                    const Text(
                      'Description & Images',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Room Description',
                      controller: descController,
                      maxLines: 2,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gallery Images',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: isUploading
                              ? null
                              : () => pickAndUploadImage(setDialogState),
                          icon: isUploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            isUploading ? 'Uploading...' : 'Upload Image',
                          ),
                        ),
                      ],
                    ),
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  resolveImageUrl(images[i]),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setDialogState(() => images.removeAt(i)),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // STATUS
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'available',
                          child: Text('Available'),
                        ),
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Text('Maintenance'),
                        ),
                        DropdownMenuItem(
                          value: 'out-of-service',
                          child: Text('Out Of Service'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => status = v);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Room Status',
                        border: OutlineInputBorder(),
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
                        setDialogState(() => isSaving = true);
                        final data = {
                          'roomNumber': roomNumberController.text.trim(),
                          'roomType': roomType,
                          'name': nameController.text.trim(),
                          'capacity':
                              int.tryParse(capacityController.text.trim()) ?? 2,
                          'basePrice': double.parse(
                            priceController.text.trim(),
                          ),
                          'floor':
                              int.tryParse(floorController.text.trim()) ?? 0,
                          'description': descController.text.trim(),
                          'amenities': selectedAmenities,
                          'images': images,
                          'status': status,
                        };
                        bool success;
                        if (room != null) {
                          success = await ref
                              .read(roomProvider.notifier)
                              .updateRoom(room.id, data);
                        } else {
                          success = await ref
                              .read(roomProvider.notifier)
                              .createRoom(selectedPropertyId, data);
                        }
                        if (success) {
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } else {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            final errorMsg =
                                ref.read(roomProvider).error ??
                                'Failed to save room';
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(room == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(room == null ? 'Room created' : 'Room updated'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadData();
    }
  }

  Future<void> _showBulkAddDialog(BuildContext context) async {
    final properties = ref.read(propertyProvider).properties;
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No properties available. Create a property first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? selectedPropertyId = properties.first.id;
    final countController = TextEditingController(text: '5');
    final priceController = TextEditingController(text: '5000');
    final capacityController = TextEditingController(text: '3');
    final adultsController = TextEditingController(text: '2');
    final childrenController = TextEditingController(text: '1');
    final floorController = TextEditingController(text: '');
    final descController = TextEditingController();
    String roomType = 'deluxe';
    String status = 'available';

    void updateCapacity() {
      final adults = int.tryParse(adultsController.text) ?? 0;
      final children = int.tryParse(childrenController.text) ?? 0;
      capacityController.text = (adults + children).toString();
    }

    adultsController.addListener(updateCapacity);
    childrenController.addListener(updateCapacity);

    // List of amenities
    final amenitiesList = [
      'WiFi',
      'AC',
      'TV',
      'Mini Bar',
      'Balcony',
      'Sea View',
      'Coffee Maker',
      'Safe',
      'Hair Dryer',
      'Iron',
      'Washing Machine',
    ];
    final selectedAmenities = <String>{};

    // Images for gallery
    List<String> images = [];
    bool isUploading = false;
    bool isLoading = false;

    Future<void> pickAndUploadImage(StateSetter setDialogState) async {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = true;
      input.click();
      input.onChange.listen((_) async {
        if (input.files == null || input.files!.isEmpty) return;
        final files = input.files!;

        setDialogState(() => isUploading = true);
        try {
          final api = ref.read(apiClientProvider);
          for (final file in files) {
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoad.first;
            final result = reader.result;
            final Uint8List bytes;
            if (result is Uint8List) {
              bytes = result;
            } else if (result is ByteBuffer) {
              bytes = result.asUint8List();
            } else {
              bytes = (result as dynamic).asUint8List() as Uint8List;
            }

            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(bytes, filename: file.name),
            });
            final response = await api.dio.post(
              '/upload/single',
              data: formData,
            );
            final rawUrl = response.data['data']['url'] as String;
            final fullUrl = resolveImageUrl(rawUrl);
            setDialogState(() => images.add(fullUrl));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          setDialogState(() => isUploading = false);
        }
      });
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Bulk Add Rooms'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PROPERTY ASSIGNMENT
                      const Text(
                        'Property',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      DropdownButtonFormField<String>(
                        value: selectedPropertyId,
                        items: properties
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedPropertyId = v),
                        decoration: const InputDecoration(
                          labelText: 'Property *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // BASIC ROOM INFORMATION
                      const Text(
                        'Basic Room Information (applies to all rooms)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      DropdownButtonFormField<String>(
                        value: roomType,
                        items: const [
                          DropdownMenuItem(
                            value: 'deluxe',
                            child: Text('Deluxe'),
                          ),
                          DropdownMenuItem(
                            value: 'family',
                            child: Text('Family'),
                          ),
                          DropdownMenuItem(
                            value: 'suite',
                            child: Text('Suite'),
                          ),
                          DropdownMenuItem(
                            value: 'cabana',
                            child: Text('Cabana'),
                          ),
                          DropdownMenuItem(
                            value: 'single',
                            child: Text('Single'),
                          ),
                          DropdownMenuItem(
                            value: 'double',
                            child: Text('Double'),
                          ),
                          DropdownMenuItem(
                            value: 'presidential',
                            child: Text('Presidential'),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => roomType = v ?? 'deluxe'),
                        decoration: const InputDecoration(
                          labelText: 'Room Type *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // CAPACITY
                      const Text(
                        'Capacity',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: WebFormField(
                              label: 'Max Guests *',
                              controller: capacityController,
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: WebFormField(
                              label: 'Max Adults',
                              controller: adultsController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      WebFormField(
                        label: 'Max Children',
                        controller: childrenController,
                        keyboardType: TextInputType.number,
                      ),

                      // PRICING & FLOOR
                      const Text(
                        'Pricing & Floor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: WebFormField(
                              label: 'Base Price Per Night *',
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: WebFormField(
                              label: 'Floor (leave empty to auto-calculate)',
                              controller: floorController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // AMENITIES
                      const Text(
                        'Amenities',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Divider(),
                      Wrap(
                        children: amenitiesList.map((a) {
                          final isSelected = selectedAmenities.contains(a);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (bool? checked) {
                                  setDialogState(() {
                                    if (checked == true)
                                      selectedAmenities.add(a);
                                    else
                                      selectedAmenities.remove(a);
                                  });
                                },
                              ),
                              Text(a),
                              const SizedBox(width: 12),
                            ],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // DESCRIPTION
                      WebFormField(
                        label: 'Room Description',
                        controller: descController,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // GALLERY IMAGES
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gallery Images (applied to all rooms)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextButton.icon(
                            onPressed: isUploading
                                ? null
                                : () => pickAndUploadImage(setDialogState),
                            icon: isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 18,
                                  ),
                            label: Text(
                              isUploading ? 'Uploading...' : 'Upload Image',
                            ),
                          ),
                        ],
                      ),
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    images[i],
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setDialogState(() => images.removeAt(i)),
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // BULK COUNT
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFF1B5E20),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'All rooms will have identical settings. Room numbers auto-generated (R001, R002...), codes (RM-0001, RM-0002...).',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      WebFormField(
                        label: 'Number of Rooms to Create *',
                        controller: countController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          final c = int.tryParse(v);
                          if (c == null || c < 1 || c > 100)
                            return 'Enter 1-100';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.playlist_add, size: 18),
                  label: Text(isLoading ? 'Creating...' : 'Create Rooms'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final count = int.tryParse(countController.text) ?? 0;
                          if (count < 1 || count > 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid count (1-100)'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isLoading = true);
                          try {
                            final api = ref.read(apiClientProvider);
                            await api.dio.post(
                              '/properties/$selectedPropertyId/rooms/bulk',
                              data: {
                                'roomType': roomType,
                                'basePrice':
                                    double.tryParse(
                                      priceController.text.trim(),
                                    ) ??
                                    0.0,
                                'capacity':
                                    int.tryParse(
                                      capacityController.text.trim(),
                                    ) ??
                                    2,
                                'adults':
                                    int.tryParse(
                                      adultsController.text.trim(),
                                    ) ??
                                    2,
                                'children':
                                    int.tryParse(
                                      childrenController.text.trim(),
                                    ) ??
                                    0,
                                'floor': floorController.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(floorController.text.trim()),
                                'amenities': selectedAmenities.toList(),
                                'images': images,
                                'description': descController.text.trim(),
                                'count': count,
                              },
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            ref
                                .read(roomProvider.notifier)
                                .fetchRooms(selectedPropertyId!);
                            _loadData();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$count rooms created successfully',
                                  ),
                                  backgroundColor: const Color(0xFF2E7D32),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(Room room) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isConfirmed = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Room'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete room ${room.roomNumber}? This action cannot be undone.',
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
                          'I confirm I want to permanently delete this room.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmed ? Colors.red : Colors.grey,
                  ),
                  onPressed: isConfirmed
                      ? () async {
                          Navigator.pop(ctx);
                          final success = await ref
                              .read(roomProvider.notifier)
                              .deleteRoom(room.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Room deleted'
                                      : ref.read(roomProvider).error ??
                                            'Failed',
                                ),
                                backgroundColor: success
                                    ? const Color(0xFF2E7D32)
                                    : Colors.red,
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _roomStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF2E7D32);
      case 'booked':
        return const Color(0xFF0288D1);
      case 'occupied':
        return const Color(0xFF1565C0);
      case 'maintenance':
        return const Color(0xFFE65100);
      case 'cleaning':
        return const Color(0xFF6A1B9A);
      case 'out-of-service':
      case 'blocked':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
}
