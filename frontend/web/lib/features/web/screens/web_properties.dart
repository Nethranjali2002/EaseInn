import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import '../widgets/web_form_dialog.dart';
import '../widgets/web_data_table.dart';

class WebPropertiesScreen extends ConsumerStatefulWidget {
  const WebPropertiesScreen({super.key});

  @override
  ConsumerState<WebPropertiesScreen> createState() =>
      _WebPropertiesScreenState();
}

class _WebPropertiesScreenState extends ConsumerState<WebPropertiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();

  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedDistrict = '';
  String _selectedProvince = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _districtController.addListener(() {
      setState(() => _selectedDistrict = _districtController.text);
    });
    _provinceController.addListener(() {
      setState(() => _selectedProvince = _provinceController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(propertyProvider.notifier).fetchProperties();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _districtController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _districtController.clear();
      _provinceController.clear();
      _selectedStatus = 'All';
      _selectedDistrict = '';
      _selectedProvince = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(propertyProvider);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.user?.isAdmin ?? false;
    final isManager = auth.user?.isManager ?? false;
    final canManage = isAdmin || isManager;

    // Filter properties locally
    final filteredProperties = state.properties.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            p.name.toLowerCase().contains(q) ||
            (p.address['city']?.toString() ?? '').toLowerCase().contains(q) ||
            (p.address['country']?.toString() ?? '').toLowerCase().contains(
              q,
            ) ||
            (p.address['street']?.toString() ?? '').toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedStatus != 'All') {
        final targetActive = _selectedStatus == 'Active';
        if (p.isActive != targetActive) return false;
      }
      if (_selectedDistrict.isNotEmpty) {
        final d = _selectedDistrict.toLowerCase();
        final match =
            (p.address['district']?.toString() ?? '').toLowerCase().contains(
              d,
            ) ||
            (p.address['state']?.toString() ?? '').toLowerCase().contains(d) ||
            (p.address['city']?.toString() ?? '').toLowerCase().contains(d);
        if (!match) return false;
      }
      if (_selectedProvince.isNotEmpty) {
        final pr = _selectedProvince.toLowerCase();
        final match =
            (p.address['province']?.toString() ?? '').toLowerCase().contains(
              pr,
            ) ||
            (p.address['zipCode']?.toString() ?? '').toLowerCase().contains(
              pr,
            ) ||
            (p.address['state']?.toString() ?? '').toLowerCase().contains(pr);
        if (!match) return false;
      }
      return true;
    }).toList();

    // Summary Cards computations
    final totalProperties = state.properties.length;
    final activeProperties = state.properties.where((p) => p.isActive).length;
    final totalRooms = state.properties.fold<int>(
      0,
      (sum, p) => sum + p.totalRooms,
    );
    final avgOccupancy = totalProperties == 0
        ? 0.0
        : state.properties.fold<double>(
                0.0,
                (sum, p) => sum + p.occupancyRate,
              ) /
              totalProperties;

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
                  'Properties',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (canManage)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Property'),
                    onPressed: () => _showPropertyDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards
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
                        'Total Properties',
                        '$totalProperties',
                        Icons.business,
                        const Color(0xFF2563EB),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Active Properties',
                        '$activeProperties',
                        Icons.check_circle_outline,
                        const Color(0xFF10B981),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Total Rooms',
                        '$totalRooms',
                        Icons.hotel,
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildSummaryCard(
                        'Occupancy Rate',
                        '${avgOccupancy.toStringAsFixed(1)}%',
                        Icons.analytics,
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
                                  hintText: 'Search Property Name, Location...',
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
                                initialValue: _selectedStatus,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'All',
                                    child: Text('All Statuses'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Active',
                                    child: Text('Active'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Inactive',
                                    child: Text('Inactive'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedStatus = v!),
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
                              child: TextField(
                                controller: _districtController,
                                decoration: const InputDecoration(
                                  hintText: 'Filter District',
                                  prefixIcon: Icon(Icons.map, size: 20),
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
                              child: TextField(
                                controller: _provinceController,
                                decoration: const InputDecoration(
                                  hintText: 'Filter Province',
                                  prefixIcon: Icon(
                                    Icons.location_on_outlined,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
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

            // Property Table
            state.isLoading && state.properties.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredProperties.isEmpty
                ? const Center(child: Text('No properties match filters.'))
                : WebDataTable(
                    showSearch: false,
                    searchHint: 'Filtered Properties',
                    columns: [
                      const DataColumn(label: Text('Property')),
                      const DataColumn(label: Text('Location')),
                      const DataColumn(label: Text('Rooms')),
                      const DataColumn(label: Text('Occupancy')),
                      const DataColumn(label: Text('Status')),
                      if (canManage) const DataColumn(label: Text('Actions')),
                    ],
                    rows: filteredProperties
                        .map((p) => _propertyRow(p, canManage))
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

  List<DataCell> _propertyRow(Property p, bool canManage) {
    final logoUrl = p.logo.isNotEmpty
        ? p.logo
        : (p.images.isNotEmpty ? p.images.first : '');
    final locationText = [
      p.address['city']?.toString() ?? '',
      p.address['district']?.toString() ?? p.address['state']?.toString() ?? '',
      p.address['country']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(', ');

    return [
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: logoUrl.isNotEmpty
                  ? Image.network(
                      resolveImageUrl(logoUrl),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey.shade200,
                        child: const Icon(
                          Icons.image,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  p.propertyType,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
      DataCell(Text(locationText)),
      DataCell(Text('${p.totalRooms}')),
      DataCell(Text('${p.occupancyRate.toStringAsFixed(1)}%')),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: p.isActive
                ? const Color(0xFF2E7D32).withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            p.isActive ? 'ACTIVE' : 'INACTIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: p.isActive ? const Color(0xFF2E7D32) : Colors.red,
            ),
          ),
        ),
      ),
      if (canManage)
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                tooltip: 'View',
                onPressed: () => _showPropertyDetail(context, p),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                onPressed: () => _showPropertyDialog(context, property: p),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red,
                ),
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(p),
              ),
            ],
          ),
        ),
    ];
  }

  void _showPropertyDetail(BuildContext context, Property p) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.apartment, size: 20, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              height: MediaQuery.of(context).size.height * 0.75,
              child: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: (p.isActive ? const Color(0xFF10B981) : Colors.red).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (p.isActive ? const Color(0xFF10B981) : Colors.red).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p.isActive ? const Color(0xFF10B981) : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            p.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(p.code.isNotEmpty ? p.code : '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(width: 8),
                        Text(p.propertyType, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        const Spacer(),
                        Text('Occupancy: ${p.occupancyRate.toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (p.coverImage.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(resolveImageUrl(p.coverImage), height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 16),
                  // Detail blocks
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _detailBlock('Property Details', Icons.home_work, const Color(0xFF6A1B9A), [
                        _detailRow('Type', p.propertyType),
                        _detailRow('Description', p.description.isNotEmpty ? p.description : '-'),
                        _detailRow('Address', '${p.address['street'] ?? ''} ${p.address['city'] ?? ''}'.trim().isNotEmpty ? '${p.address['street'] ?? ''}, ${p.address['city'] ?? ''}' : '-'),
                        _detailRow('District', p.address['district']?.toString() ?? p.address['state']?.toString() ?? '-'),
                        _detailRow('Province', p.address['province']?.toString() ?? '-'),
                      ]),
                      _detailBlock('Contact & Access', Icons.contact_phone, const Color(0xFF1565C0), [
                        _detailRow('Phone', p.contact['phone']?.toString() ?? '-'),
                        _detailRow('Email', p.contact['email']?.toString() ?? '-'),
                        _detailRow('Website', p.website.isNotEmpty ? p.website : '-'),
                        _detailRow('Check-In Time', p.checkInTime),
                        _detailRow('Check-Out Time', p.checkOutTime),
                      ]),
                      _detailBlock('Statistics', Icons.analytics, const Color(0xFF00695C), [
                        _detailRow('Total Rooms', '${p.totalRooms}'),
                        _detailRow('Available Rooms', '${p.availableRooms}'),
                        _detailRow('Occupied Rooms', '${p.totalRooms - p.availableRooms}'),
                        _detailHighlightRow('Occupancy Rate', '${p.occupancyRate.toStringAsFixed(1)}%', const Color(0xFF00695C)),
                      ]),
                      _detailBlock('Room Types', Icons.category, const Color(0xFFE65100), [
                        FutureBuilder<Response>(
                          future: ref.read(apiClientProvider).get('/properties/${p.id}/rooms'),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                            final roomList = (snapshot.data!.data['data']['rooms'] as List).map((r) => r['roomType']?.toString().toUpperCase() ?? '').toList();
                            final typeCounts = <String, int>{};
                            for (final type in roomList) { typeCounts[type] = (typeCounts[type] ?? 0) + 1; }
                            if (typeCounts.isEmpty) return const Text('No rooms added yet.', style: TextStyle(color: Colors.grey, fontSize: 12));
                            return Column(children: typeCounts.entries.map((e) => _detailRow(e.key, '${e.value} rooms')).toList());
                          },
                        ),
                      ]),
                      if (p.images.isNotEmpty)
                        _detailBlock('Gallery', Icons.photo_library, const Color(0xFF4527A0), [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: p.images.map((img) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(resolveImageUrl(img), width: 80, height: 80, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                              ),
                            )).toList(),
                          ),
                        ]),
                      _detailBlock('Recent Bookings', Icons.event_available, const Color(0xFF2E7D32), [
                        FutureBuilder<Response>(
                          future: ref.read(apiClientProvider).get('/properties/${p.id}/bookings'),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                            final bookings = snapshot.data!.data['data']['bookings'] as List;
                            if (bookings.isEmpty) return const Text('No bookings found.', style: TextStyle(color: Colors.grey, fontSize: 12));
                            return Column(children: bookings.take(4).map((b) {
                              final checkIn = b['checkInDate']?.toString().substring(0, 10) ?? '';
                              final status = b['status']?.toString().toUpperCase() ?? '';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(b['guestName'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                      Text('Check-in: $checkIn', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                    ]),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: status == 'CONFIRMED' ? Colors.green.shade50 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: status == 'CONFIRMED' ? Colors.green.shade700 : Colors.blue.shade700)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList());
                          },
                        ),
                      ]),
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBlock(String title, IconData icon, Color color, List<Widget> children) {
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

  Future<void> _showPropertyDialog(
    BuildContext context, {
    Property? property,
  }) async {
    final nameController = TextEditingController(text: property?.name ?? '');
    final typeController = TextEditingController(
      text: property?.propertyType ?? 'Resort',
    );
    final descController = TextEditingController(
      text: property?.description ?? '',
    );
    final addressController = TextEditingController(
      text:
          property?.address['street']?.toString() ??
          property?.address['address']?.toString() ??
          '',
    );
    final cityController = TextEditingController(
      text: property?.address['city']?.toString() ?? '',
    );
    final districtController = TextEditingController(
      text:
          property?.address['district']?.toString() ??
          property?.address['state']?.toString() ??
          '',
    );
    final provinceController = TextEditingController(
      text:
          property?.address['province']?.toString() ??
          property?.address['zipCode']?.toString() ??
          '',
    );
    final phoneController = TextEditingController(
      text: property?.contact['phone']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: property?.contact['email']?.toString() ?? '',
    );
    final websiteController = TextEditingController(
      text: property?.website ?? property?.contact['website']?.toString() ?? '',
    );
    final checkInController = TextEditingController(
      text: property?.checkInTime ?? '14:00',
    );
    final checkOutController = TextEditingController(
      text: property?.checkOutTime ?? '11:00',
    );

    String logo = property?.logo ?? '';
    String coverImage = property?.coverImage ?? '';
    List<String> images = List<String>.from(property?.images ?? []);
    bool isActive = property?.isActive ?? true;

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isUploadingLogo = false;
    bool isUploadingCover = false;
    bool isUploadingGallery = false;

    Future<void> uploadImage(StateSetter setDialogState, String type) async {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = type == 'gallery';
      input.click();
      input.onChange.listen((_) async {
        if (input.files == null || input.files!.isEmpty) return;
        final files = input.files!;
        
        setDialogState(() {
          if (type == 'logo') isUploadingLogo = true;
          if (type == 'cover') isUploadingCover = true;
          if (type == 'gallery') isUploadingGallery = true;
        });

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
            final response = await api.dio.post('/upload/single', data: formData);
            final rawUrl = response.data['data']['url'] as String;
            final fullUrl = resolveImageUrl(rawUrl);
            setDialogState(() {
              if (type == 'logo') logo = fullUrl;
              if (type == 'cover') coverImage = fullUrl;
              if (type == 'gallery') images.add(fullUrl);
            });
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
          setDialogState(() {
            if (type == 'logo') isUploadingLogo = false;
            if (type == 'cover') isUploadingCover = false;
            if (type == 'gallery') isUploadingGallery = false;
          });
        }
      });
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(property == null ? 'Add Property' : 'Edit Property'),
          content: SizedBox(
            width: 550,
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: Basic Information
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Property Name *',
                      controller: nameController,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: typeController.text,
                        decoration: const InputDecoration(
                          labelText: 'Property Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Resort',
                            child: Text('Resort'),
                          ),
                          DropdownMenuItem(
                            value: 'Hotel',
                            child: Text('Hotel'),
                          ),
                          DropdownMenuItem(
                            value: 'Villa',
                            child: Text('Villa'),
                          ),
                          DropdownMenuItem(
                            value: 'Cabana',
                            child: Text('Cabana'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => typeController.text = v);
                          }
                        },
                      ),
                    ),
                    WebFormField(
                      label: 'Description',
                      controller: descController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // SECTION 2: Location
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Street Address',
                      controller: addressController,
                    ),
                    WebFormField(
                      label: 'City *',
                      controller: cityController,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'City is required'
                          : null,
                    ),
                    WebFormField(
                      label: 'District',
                      controller: districtController,
                    ),
                    WebFormField(
                      label: 'Province',
                      controller: provinceController,
                    ),
                    const SizedBox(height: 16),

                    // SECTION 3: Contact Information
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Phone',
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final cleaned = v.trim().replaceAll(
                            RegExp(r'[\s\-\(\)\+]'),
                            '',
                          );
                          if (!RegExp(r'^\d{7,15}$').hasMatch(cleaned)) {
                            return 'Enter a valid phone number (7–15 digits)';
                          }
                        }
                        return null;
                      },
                    ),
                    WebFormField(
                      label: 'Email',
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Invalid email format';
                          }
                        }
                        return null;
                      },
                    ),
                    WebFormField(
                      label: 'Website',
                      controller: websiteController,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final trimmed = v.trim();
                          if (!trimmed.startsWith('http://') &&
                              !trimmed.startsWith('https://')) {
                            return 'Must start with http:// or https://';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // SECTION 4: Operations
                    const Text(
                      'Operations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    WebFormField(
                      label: 'Check-In Time',
                      controller: checkInController,
                    ),
                    WebFormField(
                      label: 'Check-Out Time',
                      controller: checkOutController,
                    ),
                    const SizedBox(height: 16),

                    // SECTION 5: Images
                    const Text(
                      'Images',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    // Logo Image
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Logo',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: isUploadingLogo
                              ? null
                              : () => uploadImage(setDialogState, 'logo'),
                          icon: isUploadingLogo
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
                            isUploadingLogo ? 'Uploading...' : 'Upload Logo',
                          ),
                        ),
                      ],
                    ),
                    if (logo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            resolveImageUrl(logo),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Cover Image
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cover Image',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: isUploadingCover
                              ? null
                              : () => uploadImage(setDialogState, 'cover'),
                          icon: isUploadingCover
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
                            isUploadingCover ? 'Uploading...' : 'Upload Cover',
                          ),
                        ),
                      ],
                    ),
                    if (coverImage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            resolveImageUrl(coverImage),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Gallery Images
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gallery Images',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: isUploadingGallery
                              ? null
                              : () => uploadImage(setDialogState, 'gallery'),
                          icon: isUploadingGallery
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
                            isUploadingGallery
                                ? 'Uploading...'
                                : 'Upload Image',
                          ),
                        ),
                      ],
                    ),
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  resolveImageUrl(images[i]),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setDialogState(() => images.removeAt(i)),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // SECTION 6: Status
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Text('Active Status'),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setDialogState(() => isActive = v),
                          activeThumbColor: const Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                  ],
                ),
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
                        'name': nameController.text.trim(),
                        'propertyType': typeController.text,
                        if (descController.text.trim().isNotEmpty)
                          'description': descController.text.trim(),
                        'address': {
                          if (addressController.text.trim().isNotEmpty)
                            'street': addressController.text.trim(),
                          'city': cityController.text.trim(),
                          if (districtController.text.trim().isNotEmpty)
                            'state': districtController.text.trim(),
                          if (provinceController.text.trim().isNotEmpty)
                            'zipCode': provinceController.text.trim(),
                        },
                        'contact': {
                          if (phoneController.text.trim().isNotEmpty)
                            'phone': phoneController.text.trim(),
                          if (emailController.text.trim().isNotEmpty)
                            'email': emailController.text.trim(),
                          if (websiteController.text.trim().isNotEmpty)
                            'website': websiteController.text.trim(),
                        },
                        if (checkInController.text.trim().isNotEmpty)
                          'checkInTime': checkInController.text.trim(),
                        if (checkOutController.text.trim().isNotEmpty)
                          'checkOutTime': checkOutController.text.trim(),
                        'logo': logo,
                        'coverImage': coverImage,
                        'images': images,
                        'isActive': isActive,
                      };
                      bool success = property != null
                          ? await ref
                                .read(propertyProvider.notifier)
                                .updateProperty(property.id, data)
                          : await ref
                                .read(propertyProvider.notifier)
                                .createProperty(data);
                      if (success) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        setDialogState(() => isSaving = false);
                        if (ctx.mounted) {
                          final errorMsg =
                              ref.read(propertyProvider).error ??
                              'Failed to save property';
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
                  : Text(property == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      ref.read(propertyProvider.notifier).fetchProperties();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            property == null ? 'Property created' : 'Property updated',
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  void _confirmDelete(Property property) {
    // Step 1 state
    bool step1Confirmed = false;
    // Step 2 state
    int currentStep = 1;
    final nameController = TextEditingController();
    bool nameMatches = false;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentStep == 1
                        ? 'Delete Property — Step 1 of 2'
                        : 'Delete Property — Step 2 of 2',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: currentStep == 1
                  // ── STEP 1: Warning + checkbox ──────────────────────────
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You are about to permanently delete:',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '"${property.name}"',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This will permanently remove the property and cannot be undone.',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => setDialogState(
                            () => step1Confirmed = !step1Confirmed,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: step1Confirmed,
                                activeColor: Colors.red,
                                onChanged: (val) => setDialogState(
                                  () => step1Confirmed = val ?? false,
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'I understand this action is permanent and cannot be reversed.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  // ── STEP 2: Type property name ───────────────────────────
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Final confirmation required.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                            children: [
                              const TextSpan(text: 'Type '),
                              TextSpan(
                                text: property.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: Colors.red,
                                ),
                              ),
                              const TextSpan(
                                text: ' below to confirm deletion:',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Type property name exactly...',
                            border: const OutlineInputBorder(),
                            errorText:
                                nameController.text.isNotEmpty && !nameMatches
                                ? 'Name does not match'
                                : null,
                            suffixIcon: nameMatches
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              nameMatches = val.trim() == property.name.trim();
                            });
                          },
                        ),
                      ],
                    ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () {
                          nameController.dispose();
                          Navigator.pop(ctx);
                        },
                  child: const Text('Cancel'),
                ),
                if (currentStep == 1)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: step1Confirmed
                          ? Colors.orange
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: step1Confirmed
                        ? () => setDialogState(() => currentStep = 2)
                        : null,
                    child: const Text('Next →'),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nameMatches && !isDeleting
                          ? Colors.red
                          : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: nameMatches && !isDeleting
                        ? () async {
                            setDialogState(() => isDeleting = true);
                            nameController.dispose();
                            Navigator.pop(ctx);
                            final success = await ref
                                .read(propertyProvider.notifier)
                                .deleteProperty(property.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '"${property.name}" has been deleted'
                                        : ref.read(propertyProvider).error ??
                                              'Delete failed',
                                  ),
                                  backgroundColor: success
                                      ? const Color(0xFF2E7D32)
                                      : Colors.red,
                                ),
                              );
                            }
                          }
                        : null,
                    child: isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Delete Permanently'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
