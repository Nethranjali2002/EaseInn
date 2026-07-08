import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import '../widgets/web_data_table.dart';

class WebFeedbackScreen extends ConsumerStatefulWidget {
  const WebFeedbackScreen({super.key});

  @override
  ConsumerState<WebFeedbackScreen> createState() => _WebFeedbackScreenState();
}

class _WebFeedbackScreenState extends ConsumerState<WebFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Tabs: "All Feedback" and "Statistics"
  final TextEditingController _searchController = TextEditingController();

  // Raw data fetched from API
  List<Map<String, dynamic>> _feedback = [];
  List<Map<String, dynamic>> _bookings = [];
  List<User> _staffList = [];
  // Aggregated rating statistics computed client-side from feedback data
  Map<String, dynamic> _aggregatedStats = {
    'total': 0,
    'avg': 0.0,
    'five': 0,
    'four': 0,
    'three': 0,
    'two': 0,
    'one': 0,
    'positive': 0,
    'negative': 0,
    'pending': 0,
  };

  bool _isLoading = false;
  // Filter state
  String _selectedPropertyId = 'All';
  String _selectedRating = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Loads all feedback data, bookings, and staff list across all properties.
  /// Computes aggregated statistics (average rating, distribution, response rate).
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);

      // 1. Ensure properties are loaded
      await ref.read(propertyProvider.notifier).fetchProperties();
      final properties = ref.read(propertyProvider).properties;

      // 2. Fetch feedback across properties
      List<Map<String, dynamic>> tempFeedback = [];
      List<Map<String, dynamic>> tempBookings = [];

      for (final p in properties) {
        // Load feedback
        try {
          final res = await api.get('/properties/${p.id}/feedback');
          final list = res.data['data']['feedback'] as List?;
          if (list != null) {
            for (final f in list) {
              final item = Map<String, dynamic>.from(f);
              item['propertyName'] = p.name;
              tempFeedback.add(item);
            }
          }
        } catch (_) {}

        // Load bookings (to find pending reviews)
        try {
          final res = await api.get('/properties/${p.id}/bookings');
          final list = res.data['data']['bookings'] as List?;
          if (list != null) {
            tempBookings.addAll(list.map((b) => Map<String, dynamic>.from(b)));
          }
        } catch (_) {}
      }

      // 3. Fetch staff members
      try {
        final res = await api.get('/admin/users');
        final users = (res.data['data']['users'] as List?)
            ?.map((u) => User.fromJson(u as Map<String, dynamic>))
            .toList();
        if (users != null) {
          _staffList = users
              .where(
                (u) => [
                  'staff',
                  'receptionist',
                  'housekeeping',
                  'maintenance',
                ].contains(u.role.toLowerCase()),
              )
              .toList();
        }
      } catch (_) {}

      setState(() {
        _feedback = tempFeedback;
        _bookings = tempBookings;
        _calculateStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    if (_feedback.isEmpty) {
      _aggregatedStats = {
        'total': 0,
        'avg': 0.0,
        'five': 0,
        'four': 0,
        'three': 0,
        'two': 0,
        'one': 0,
        'positive': 0,
        'negative': 0,
        'pending': 0,
      };
      return;
    }

    double sum = 0;
    int five = 0, four = 0, three = 0, two = 0, one = 0;
    int positive = 0, negative = 0;

    for (final f in _feedback) {
      final rating = (f['rating'] ?? 0) as num;
      sum += rating;
      if (rating == 5) five++;
      if (rating == 4) four++;
      if (rating == 3) three++;
      if (rating == 2) two++;
      if (rating == 1) one++;

      if (rating >= 4) {
        positive++;
      } else if (rating <= 2) {
        negative++;
      }
    }

    // Pending Reviews: Checked-Out Bookings with no submitted feedback
    final submittedBookingIds = _feedback.map((f) {
      final b = f['booking'];
      if (b is Map) return b['_id'] ?? b['id'];
      return b;
    }).toSet();

    final pendingReviewsCount = _bookings.where((b) {
      final isCheckedOut =
          b['status']?.toString().toLowerCase() == 'checked_out';
      final hasNoFeedback =
          !submittedBookingIds.contains(b['_id']) &&
          !submittedBookingIds.contains(b['id']);
      return isCheckedOut && hasNoFeedback;
    }).length;

    _aggregatedStats = {
      'total': _feedback.length,
      'avg': sum / _feedback.length,
      'five': five,
      'four': four,
      'three': three,
      'two': two,
      'one': one,
      'positive': positive,
      'negative': negative,
      'pending': pendingReviewsCount,
    };
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedPropertyId = 'All';
      _selectedRating = 'All';
      _selectedStatus = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertyProvider).properties;

    // Apply filtering
    final filteredFeedback = _feedback.where((f) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final guest = (f['guestName'] ?? '').toString().toLowerCase();
        final comment = (f['comment'] ?? '').toString().toLowerCase();
        final title = (f['title'] ?? '').toString().toLowerCase();
        final revId = f['_id'] != null
            ? 'rev-${f['_id'].substring(f['_id'].length - 4)}'.toLowerCase()
            : '';

        final match =
            guest.contains(q) ||
            comment.contains(q) ||
            title.contains(q) ||
            revId.contains(q);
        if (!match) return false;
      }

      // 2. Property Filter
      if (_selectedPropertyId != 'All') {
        final propId = f['property'] is Map
            ? (f['property']['_id'] ?? f['property']['id'])
            : f['property'];
        if (propId != _selectedPropertyId) return false;
      }

      // 3. Rating Filter
      if (_selectedRating != 'All') {
        final r = int.tryParse(_selectedRating);
        if (r != null && (f['rating'] as num).toInt() != r) return false;
      }

      // 4. Status Filter
      if (_selectedStatus != 'All') {
        final stat = (f['status'] ?? 'New').toString().toLowerCase();
        if (stat != _selectedStatus.toLowerCase()) return false;
      }

      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Feedback & Ratings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Reviews'),
                  Tab(text: 'Satisfaction Analytics'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Reviews List & Manager actions
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
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
                                  'Total Reviews',
                                  '${_aggregatedStats['total']}',
                                  Icons.rate_review_outlined,
                                  Colors.blue,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Average Rating',
                                  '${(_aggregatedStats['avg'] as double).toStringAsFixed(1)} ★',
                                  Icons.star_border,
                                  Colors.amber,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Positive Reviews',
                                  '${_aggregatedStats['positive']}',
                                  Icons.thumb_up_alt_outlined,
                                  Colors.green,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Negative Reviews',
                                  '${_aggregatedStats['negative']}',
                                  Icons.thumb_down_alt_outlined,
                                  Colors.red,
                                ),
                              ),
                              SizedBox(
                                width: cardWidth,
                                child: _buildSummaryCard(
                                  'Pending Reviews',
                                  '${_aggregatedStats['pending']}',
                                  Icons.hourglass_empty,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Filter Section
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
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: searchWidth,
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'Search by Guest, Review ID, Comments...',
                                            prefixIcon: Icon(
                                              Icons.search,
                                              size: 20,
                                            ),
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
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
                                          onChanged: (v) => setState(
                                            () => _selectedPropertyId = v!,
                                          ),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
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
                                          initialValue: _selectedRating,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'All',
                                              child: Text('All Ratings'),
                                            ),
                                            DropdownMenuItem(
                                              value: '5',
                                              child: Text('5 Stars'),
                                            ),
                                            DropdownMenuItem(
                                              value: '4',
                                              child: Text('4 Stars'),
                                            ),
                                            DropdownMenuItem(
                                              value: '3',
                                              child: Text('3 Stars'),
                                            ),
                                            DropdownMenuItem(
                                              value: '2',
                                              child: Text('2 Stars'),
                                            ),
                                            DropdownMenuItem(
                                              value: '1',
                                              child: Text('1 Star'),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _selectedRating = v!,
                                          ),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
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
                                          initialValue: _selectedStatus,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'All',
                                              child: Text('All Statuses'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'New',
                                              child: Text('New'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Reviewed',
                                              child: Text('Reviewed'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Resolved',
                                              child: Text('Resolved'),
                                            ),
                                          ],
                                          onChanged: (v) => setState(
                                            () => _selectedStatus = v!,
                                          ),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
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

                      // Listing Table
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filteredFeedback.isEmpty
                          ? const Center(child: Text('No reviews found.'))
                          : WebDataTable(
                              showSearch: false,
                              searchHint: 'Filtered Reviews',
                              columns: const [
                                DataColumn(label: Text('Review ID')),
                                DataColumn(label: Text('Guest')),
                                DataColumn(label: Text('Property')),
                                DataColumn(label: Text('Booking')),
                                DataColumn(label: Text('Rating')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filteredFeedback
                                  .map((f) => _feedbackRow(f, properties))
                                  .toList(),
                            ),
                    ],
                  ),
                ),

                // Tab 2: Satisfaction Analytics Reports
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Property Rating Analysis & Category Performance
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Property Rating Analysis',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Property')),
                                        DataColumn(
                                          label: Text('Average Rating'),
                                        ),
                                        DataColumn(
                                          label: Text('Total Reviews'),
                                        ),
                                      ],
                                      rows: properties.map((p) {
                                        final pFeedback = _feedback.where((f) {
                                          final propId = f['property'] is Map
                                              ? (f['property']['_id'] ??
                                                    f['property']['id'])
                                              : f['property'];
                                          return propId == p.id;
                                        }).toList();
                                        double sum = 0;
                                        for (final f in pFeedback) {
                                          sum += (f['rating'] ?? 0) as num;
                                        }
                                        final avg = pFeedback.isNotEmpty
                                            ? sum / pFeedback.length
                                            : 0.0;
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                p.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(avg.toStringAsFixed(1)),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                '${pFeedback.length} reviews',
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Category Performance Analysis',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          _buildCategoryProgress(
                                            'Room Quality',
                                            _calculateCategoryAvg('comfort'),
                                          ),
                                          _buildCategoryProgress(
                                            'Cleanliness',
                                            _calculateCategoryAvg(
                                              'cleanliness',
                                            ),
                                          ),
                                          _buildCategoryProgress(
                                            'Staff Service',
                                            _calculateCategoryAvg('service'),
                                          ),
                                          _buildCategoryProgress(
                                            'Facilities',
                                            _calculateCategoryAvg('location'),
                                          ),
                                          _buildCategoryProgress(
                                            'Value For Money',
                                            _calculateCategoryAvg('value'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Right Column: Rating Distribution & Monthly trends
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Rating Distribution',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          _buildDistributionBar(
                                            '5 Star',
                                            _aggregatedStats['five'],
                                            _aggregatedStats['total'],
                                            Colors.green,
                                          ),
                                          _buildDistributionBar(
                                            '4 Star',
                                            _aggregatedStats['four'],
                                            _aggregatedStats['total'],
                                            Colors.teal,
                                          ),
                                          _buildDistributionBar(
                                            '3 Star',
                                            _aggregatedStats['three'],
                                            _aggregatedStats['total'],
                                            Colors.amber,
                                          ),
                                          _buildDistributionBar(
                                            '2 Star',
                                            _aggregatedStats['two'],
                                            _aggregatedStats['total'],
                                            Colors.orange,
                                          ),
                                          _buildDistributionBar(
                                            '1 Star',
                                            _aggregatedStats['one'],
                                            _aggregatedStats['total'],
                                            Colors.red,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Staff Performance Evaluation',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Staff Member')),
                                        DataColumn(label: Text('Role')),
                                        DataColumn(
                                          label: Text('Average Rating'),
                                        ),
                                      ],
                                      rows: _staffList.map((st) {
                                        // Mock evaluations based on their user ID hash to represent a dynamic PMS review link
                                        final code = st.id.codeUnits.fold(
                                          0,
                                          (prev, element) => prev + element,
                                        );
                                        final rating = 4.0 + (code % 10) / 10.0;
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                st.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(st.role.toUpperCase()),
                                            ),
                                            DataCell(
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    rating.toStringAsFixed(1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
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

  double _calculateCategoryAvg(String categoryKey) {
    if (_feedback.isEmpty) return 0.0;
    double sum = 0;
    int count = 0;
    for (final f in _feedback) {
      final cats = f['categories'];
      if (cats is Map && cats[categoryKey] != null) {
        sum += (cats[categoryKey] as num).toDouble();
        count++;
      }
    }
    return count > 0 ? sum / count : 0.0;
  }

  Widget _buildCategoryProgress(String categoryName, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              categoryName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 6,
            child: LinearProgressIndicator(
              value: rating / 5.0,
              color: Colors.blue,
              backgroundColor: Colors.grey.shade100,
              minHeight: 8,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${rating.toStringAsFixed(1)} ★',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(
    String label,
    dynamic count,
    dynamic total,
    Color color,
  ) {
    final c = (count as num).toInt();
    final t = (total as num).toInt();
    final pct = t > 0 ? c / t : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: pct,
              color: color,
              backgroundColor: Colors.grey.shade100,
              minHeight: 8,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$c reviews (${(pct * 100).toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  List<DataCell> _feedbackRow(
    Map<String, dynamic> f,
    List<Property> properties,
  ) {
    final id = f['_id'] ?? f['id'] ?? '';
    final displayId = id.isNotEmpty
        ? 'REV-${id.substring(id.length - 4).toUpperCase()}'
        : 'REV-N/A';
    final guest = f['guestName'] ?? 'Guest';
    final propName = f['propertyName'] ?? 'Resort';
    final booking = f['booking'];
    final bookingId = booking is Map
        ? (booking['_id'] ?? booking['id'] ?? '')
        : (booking ?? '');
    final displayBooking = bookingId.isNotEmpty
        ? 'BK-${bookingId.substring(bookingId.length - 4).toUpperCase()}'
        : 'BK-N/A';

    final rating = (f['rating'] ?? 0) as num;
    final status = f['status'] ?? 'New';
    final dateStr = f['createdAt'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(f['createdAt']))
        : 'N/A';

    return [
      DataCell(
        Text(displayId, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      DataCell(Text(guest)),
      DataCell(Text(propName)),
      DataCell(Text(displayBooking)),
      DataCell(
        Row(
          children: List.generate(
            5,
            (index) => Icon(
              index < rating.toInt() ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 16,
            ),
          ),
        ),
      ),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toString().toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _statusColor(status),
            ),
          ),
        ),
      ),
      DataCell(Text(dateStr)),
      DataCell(
        ElevatedButton(
          onPressed: () => _showFeedbackDetails(context, f),
          child: const Text('View'),
        ),
      ),
    ];
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'reviewed':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _showFeedbackDetails(
    BuildContext context,
    Map<String, dynamic> f,
  ) async {
    final id = f['_id'] ?? f['id'] ?? '';
    final displayId = id.isNotEmpty
        ? 'REV-${id.substring(id.length - 4).toUpperCase()}'
        : 'REV-N/A';
    final booking = f['booking'];
    final bookingId = booking is Map
        ? (booking['_id'] ?? booking['id'] ?? '')
        : (booking ?? '');
    final displayBooking = bookingId.isNotEmpty
        ? 'BK-${bookingId.substring(bookingId.length - 4).toUpperCase()}'
        : 'BK-N/A';

    final textController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDetailsState) {
          final status = f['status'] ?? 'New';
          final hasResponse =
              f['response'] != null &&
              (f['response']['text'] as String?)?.isNotEmpty == true;
          final cats = f['categories'] as Map?;

          final double comfort = (cats?['comfort'] ?? 0.0) as double;
          final double cleanliness = (cats?['cleanliness'] ?? 0.0) as double;
          final double service = (cats?['service'] ?? 0.0) as double;
          final double location = (cats?['location'] ?? 0.0) as double;
          final double value = (cats?['value'] ?? 0.0) as double;

          final recommendation = f['recommendation'] ?? 'Yes';

          return AlertDialog(
            scrollable: true,
            title: Row(
              children: [
                const Icon(
                  Icons.rate_review,
                  size: 20,
                  color: Color(0xFFE65100),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review Details',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Text(
                  displayId,
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
              width: 760,
              child: Column(
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
                      color:
                          (status == 'resolved'
                                  ? const Color(0xFF2E7D32)
                                  : status == 'pending'
                                  ? Colors.orange
                                  : const Color(0xFF1565C0))
                              .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            (status == 'resolved'
                                    ? const Color(0xFF2E7D32)
                                    : status == 'pending'
                                    ? Colors.orange
                                    : const Color(0xFF1565C0))
                                .withOpacity(0.2),
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
                            color: status == 'resolved'
                                ? const Color(0xFF2E7D32)
                                : status == 'pending'
                                ? Colors.orange
                                : const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(f['rating'] ?? 0)} ★',
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
                          f['guestName'] ?? 'Guest',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          f['propertyName'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Guest & Property Information
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _detailBlock('Guest Information', [
                          _detailRow('Guest Name', f['guestName'] ?? 'Guest'),
                          _detailRow('Booking ID', displayBooking),
                          _detailRow('Email Address', f['guestEmail'] ?? 'N/A'),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _detailBlock('Property Information', [
                          _detailRow(
                            'Property Name',
                            f['propertyName'] ?? 'Resort',
                          ),
                          _detailRow('Stay Status', 'Completed'),
                          _detailRow(
                            'Review Date',
                            f['createdAt'] != null
                                ? DateFormat(
                                    'dd MMM yyyy',
                                  ).format(DateTime.parse(f['createdAt']))
                                : 'N/A',
                          ),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rating breakdown & Recommendation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _detailBlock('Rating Breakdown', [
                          _detailRow(
                            'Overall Rating',
                            '${(f['rating'] ?? 0)} ★',
                          ),
                          _detailRow('Room Quality', '$comfort ★'),
                          _detailRow('Cleanliness', '$cleanliness ★'),
                          _detailRow('Staff Service', '$service ★'),
                          _detailRow('Facilities', '$location ★'),
                          _detailRow('Value For Money', '$value ★'),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _detailBlock('Recommendation', [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  recommendation == 'Yes'
                                      ? Icons.thumb_up
                                      : Icons.thumb_down,
                                  color: recommendation == 'Yes'
                                      ? Colors.green
                                      : Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  recommendation == 'Yes'
                                      ? 'Would recommend stay'
                                      : 'Would not recommend stay',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _detailRow('Feedback Status', status.toUpperCase()),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Guest feedback comments
                  _detailBlock('Guest Comments', [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        (f['comment'] as String?)?.isNotEmpty == true
                            ? '"${f['comment']}"'
                            : 'No comments provided.',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Manager Response
                  _detailBlock('Manager Response', [
                    if (hasResponse) ...[
                      Text(
                        'Response text: "${f['response']['text']}"',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Responded at: ${f['response']['respondedAt'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(f['response']['respondedAt'])) : "N/A"}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'No response posted yet. Submit a response to the review below:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Enter your response...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (textController.text.trim().isEmpty)
                                    return;
                                  setDetailsState(() => isSaving = true);
                                  try {
                                    final api = ref.read(apiClientProvider);
                                    final res = await api.patch(
                                      '/feedback/$id/respond',
                                      data: {
                                        'text': textController.text.trim(),
                                      },
                                    );
                                    final updatedFeedback =
                                        res.data['data']['feedback'];
                                    setState(() {
                                      final index = _feedback.indexWhere(
                                        (item) =>
                                            (item['_id'] ?? item['id']) == id,
                                      );
                                      if (index != -1) {
                                        _feedback[index] =
                                            Map<String, dynamic>.from(
                                              updatedFeedback,
                                            );
                                        _feedback[index]['propertyName'] =
                                            f['propertyName'];
                                      }
                                    });
                                    setDetailsState(() {
                                      f['response'] =
                                          updatedFeedback['response'];
                                      f['status'] = updatedFeedback['status'];
                                      isSaving = false;
                                    });
                                  } catch (e) {
                                    setDetailsState(() => isSaving = false);
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Post Response'),
                        ),
                      ),
                    ],
                  ]),

                  // Resolution Information
                  const SizedBox(height: 16),
                  _detailBlock('Resolution Information (Complaints Handling)', [
                    if (status.toString().toLowerCase() == 'resolved') ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'This feedback has been resolved.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      if (f['resolutionDate'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Resolution Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(f['resolutionDate']))}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Needs Manager Resolution?',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: const Text('Mark as Resolved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setDetailsState(() => isSaving = true);
                                    try {
                                      final api = ref.read(apiClientProvider);
                                      final res = await api.patch(
                                        '/feedback/$id/resolve',
                                      );
                                      final updatedFeedback =
                                          res.data['data']['feedback'];
                                      setState(() {
                                        final index = _feedback.indexWhere(
                                          (item) =>
                                              (item['_id'] ?? item['id']) == id,
                                        );
                                        if (index != -1) {
                                          _feedback[index] =
                                              Map<String, dynamic>.from(
                                                updatedFeedback,
                                              );
                                          _feedback[index]['propertyName'] =
                                              f['propertyName'];
                                        }
                                      });
                                      setDetailsState(() {
                                        f['status'] = updatedFeedback['status'];
                                        f['resolutionDate'] =
                                            updatedFeedback['resolutionDate'];
                                        isSaving = false;
                                      });
                                    } catch (e) {
                                      setDetailsState(() => isSaving = false);
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ]),
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

  Widget _detailBlock(String title, List<Widget> children) {
    return Card(
      color: Colors.grey.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...children,
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
