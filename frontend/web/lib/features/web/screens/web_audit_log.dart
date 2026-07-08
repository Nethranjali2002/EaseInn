import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';

/// Audit log screen showing system activity timeline for admin users.
class WebAuditLogScreen extends ConsumerStatefulWidget {
  const WebAuditLogScreen({super.key});

  @override
  ConsumerState<WebAuditLogScreen> createState() => _WebAuditLogScreenState();
}

class _WebAuditLogScreenState extends ConsumerState<WebAuditLogScreen> {
  List<Map<String, dynamic>> _logs = []; // Raw audit log entries from API
  bool _isLoading = false;

  // Search & Filters
  final _searchController = TextEditingController();
  String _selectedModule =
      'All Modules'; // All Modules, Users, Properties, Rooms, Bookings, Payments, Tasks, Feedback
  String _selectedAction =
      'All Actions'; // All Actions, Created, Updated, Deleted, Logged In, Logged Out, Payment, Task
  String _selectedDateRange =
      'This Month'; // Today, This Week, This Month, All Time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLogs());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches all audit logs from the admin API endpoint.
  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/admin/audit-logs');
      final list = (res.data['data']['logs'] as List?) ?? [];
      setState(() {
        _logs = list.map((e) => e as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter Logic
    final now = DateTime.now();
    final filteredLogs = _logs.where((log) {
      // Date Filter
      if (log['createdAt'] != null) {
        final logDate = DateTime.tryParse(log['createdAt'].toString()) ?? now;
        final difference = now.difference(logDate).inDays;
        if (_selectedDateRange == 'Today' && difference > 0) return false;
        if (_selectedDateRange == 'This Week' && difference > 7) return false;
        if (_selectedDateRange == 'This Month' && difference > 30) return false;
      }

      // Module Filter
      if (_selectedModule != 'All Modules') {
        final entity = (log['entity'] ?? '').toString().toLowerCase();
        final actionField = (log['action'] ?? '').toString().toLowerCase();
        final matchModule = _selectedModule.toLowerCase();

        if (matchModule == 'users' && !entity.contains('user')) return false;
        if (matchModule == 'properties' && !entity.contains('property'))
          return false;
        if (matchModule == 'rooms' && !entity.contains('room')) return false;
        if (matchModule == 'bookings' && !entity.contains('booking'))
          return false;
        if (matchModule == 'payments' &&
            !entity.contains('payment') &&
            actionField != 'payment')
          return false;
        if (matchModule == 'tasks' &&
            !entity.contains('task') &&
            actionField != 'task')
          return false;
        if (matchModule == 'feedback' &&
            !entity.contains('feedback') &&
            !entity.contains('review'))
          return false;
      }

      // Action Filter
      if (_selectedAction != 'All Actions') {
        final actionStr = (log['action'] ?? '').toString().toLowerCase();
        final matchAction = _selectedAction.toLowerCase();

        if (matchAction == 'created' && actionStr != 'create') return false;
        if (matchAction == 'updated' && actionStr != 'update') return false;
        if (matchAction == 'deleted' && actionStr != 'delete') return false;
        if (matchAction == 'logged in' && actionStr != 'login') return false;
        if (matchAction == 'logged out' && actionStr != 'logout') return false;
        if (matchAction == 'payment' && actionStr != 'payment') return false;
        if (matchAction == 'task' && actionStr != 'task') return false;
      }

      // Search Query Filter (User, Booking ID, Room Number, Property)
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        final userName = (log['user']?['name'] ?? '').toString().toLowerCase();
        final description = (log['description'] ?? '').toString().toLowerCase();
        final entityVal = (log['entity'] ?? '').toString().toLowerCase();
        final propertyName = (log['property']?['name'] ?? '')
            .toString()
            .toLowerCase();

        if (!userName.contains(query) &&
            !description.contains(query) &&
            !entityVal.contains(query) &&
            !propertyName.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // 2. Metrics Calculation
    int todayEvents = 0;
    int userChanges = 0;
    int bookingChanges = 0;
    int paymentChanges = 0;

    for (final log in _logs) {
      if (log['createdAt'] != null) {
        final logDate = DateTime.tryParse(log['createdAt'].toString()) ?? now;
        if (now.difference(logDate).inDays == 0) todayEvents++;
      }
      final entity = (log['entity'] ?? '').toString().toLowerCase();
      if (entity.contains('user')) userChanges++;
      if (entity.contains('booking')) bookingChanges++;
      if (entity.contains('payment') || (log['action'] ?? '') == 'payment')
        paymentChanges++;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Audit Log Tracker',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _loadLogs,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Logs'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Summary Cards
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
                      "Today's Events",
                      '$todayEvents',
                      Icons.today,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildSummaryCard(
                      "User Changes",
                      '$userChanges',
                      Icons.people,
                      Colors.teal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildSummaryCard(
                      "Booking Changes",
                      '$bookingChanges',
                      Icons.book_online,
                      Colors.orange,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildSummaryCard(
                      "Payment Actions",
                      '$paymentChanges',
                      Icons.payment,
                      Colors.green,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // 4. Filters Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 1000;
                  final double itemWidth = isDesktop
                      ? (constraints.maxWidth - (12 * 4)) / 5
                      : (constraints.maxWidth - 12) / 2;
                  final double searchWidth = isDesktop
                      ? itemWidth * 2 + 12
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search
                      SizedBox(
                        width: searchWidth,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Search logs',
                            hintText:
                                'Search by User, Booking ID, Room, Property...',
                            prefixIcon: Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      // Module Filter
                      SizedBox(
                        width: itemWidth,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedModule,
                          decoration: const InputDecoration(
                            labelText: 'Module',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              [
                                    'All Modules',
                                    'Users',
                                    'Properties',
                                    'Rooms',
                                    'Bookings',
                                    'Payments',
                                    'Tasks',
                                    'Feedback',
                                  ]
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedModule = val!),
                        ),
                      ),
                      // Action Filter
                      SizedBox(
                        width: itemWidth,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedAction,
                          decoration: const InputDecoration(
                            labelText: 'Action',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              [
                                    'All Actions',
                                    'Created',
                                    'Updated',
                                    'Deleted',
                                    'Logged In',
                                    'Logged Out',
                                    'Payment',
                                    'Task',
                                  ]
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedAction = val!),
                        ),
                      ),
                      // Date Range Filter
                      SizedBox(
                        width: itemWidth,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDateRange,
                          decoration: const InputDecoration(
                            labelText: 'Timeframe',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              ['Today', 'This Week', 'This Month', 'All Time']
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedDateRange = val!),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Audit Log Table
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredLogs.isEmpty
                  ? const Center(
                      child: Text('No audit logs match current filters.'),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.grey.shade50,
                                  ),
                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        'Log ID',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Time',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'User',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Module / Entity',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Action',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Description',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Actions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: filteredLogs.map((log) {
                                    final id = log['_id'] ?? log['id'] ?? '';
                                    final shortId = id.length > 6
                                        ? id
                                              .substring(id.length - 6)
                                              .toUpperCase()
                                        : id.toUpperCase();
                                    final logDisplayId = '#ALG-$shortId';

                                    final timeStr = log['createdAt'] != null
                                        ? DateFormat(
                                            'dd MMM yyyy, hh:mm a',
                                          ).format(
                                            DateTime.parse(log['createdAt']),
                                          )
                                        : 'N/A';
                                    final userName =
                                        log['user']?['name'] ?? 'System';
                                    final userRole =
                                        log['user']?['role'] ?? 'system';
                                    return DataRow(
                                      onSelectChanged: (_) =>
                                          _showLogDetails(log),
                                      cells: [
                                        DataCell(
                                          Text(
                                            logDisplayId,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            timeStr,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                userName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                userRole
                                                    .toString()
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                log['entity'] ?? 'General',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (log['property'] != null)
                                                Text(
                                                  log['property']['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          _buildActionBadge(
                                            log['action'] ?? 'other',
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            log['description'] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(
                                              Icons.visibility,
                                              size: 18,
                                            ),
                                            tooltip: 'View Diff Details',
                                            onPressed: () =>
                                                _showLogDetails(log),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBadge(String action) {
    Color badgeColor = Colors.grey;
    final act = action.toLowerCase();
    if (act == 'create') badgeColor = Colors.green;
    if (act == 'update') badgeColor = Colors.blue;
    if (act == 'delete') badgeColor = Colors.red;
    if (act == 'login' || act == 'logout') badgeColor = Colors.teal;
    if (act == 'payment') badgeColor = Colors.amber.shade800;
    if (act == 'booking') badgeColor = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        action.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (ctx) {
        final id = log['_id'] ?? log['id'] ?? '';
        final shortId = id.length > 6
            ? id.substring(id.length - 6).toUpperCase()
            : id.toUpperCase();
        final logDisplayId = '#ALG-$shortId';

        final timeStr = log['createdAt'] != null
            ? DateFormat(
                'dd MMM yyyy, hh:mm a',
              ).format(DateTime.parse(log['createdAt']))
            : 'N/A';
        final before = log['changes']?['before'] as Map<String, dynamic>?;
        final after = log['changes']?['after'] as Map<String, dynamic>?;
        final action = (log['action'] ?? '').toString().toUpperCase();
        final actionColor = action == 'CREATE' || action == 'CREATED'
            ? const Color(0xFF2E7D32)
            : action == 'DELETE' || action == 'DELETED'
            ? Colors.red
            : const Color(0xFF1565C0);

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.history, size: 20, color: Color(0xFF1B5E20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audit Log Details',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                logDisplayId,
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
            child: SingleChildScrollView(
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
                      color: actionColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: actionColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: actionColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            action,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          log['entity'] ?? 'General',
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
                          timeStr,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          log['user']?['name'] ?? 'System',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Event Info Card
                  _buildDetailsHeader('Event Information'),
                  _detailsRow('Log ID', '$logDisplayId ($id)'),
                  _detailsRow('Timestamp', timeStr),
                  _detailsRow('Module / Entity', log['entity'] ?? 'General'),
                  _detailsRow('Action Performed', action),
                  _detailsRow('IP Address', log['ip'] ?? '-'),
                  _detailsRow('User Agent', log['userAgent'] ?? '-'),
                  const SizedBox(height: 16),

                  // Performed By User Card
                  _buildDetailsHeader('Performed By User'),
                  _detailsRow('User Name', log['user']?['name'] ?? 'System'),
                  _detailsRow('Email Address', log['user']?['email'] ?? '-'),
                  _detailsRow(
                    'User Role',
                    (log['user']?['role'] ?? 'system').toUpperCase(),
                  ),
                  _detailsRow(
                    'Assigned Property',
                    log['property']?['name'] ?? 'All Properties',
                  ),
                  const SizedBox(height: 16),

                  // Changes Diff Grid
                  _buildDetailsHeader('Field Changes & Diff'),
                  const SizedBox(height: 8),
                  _buildChangeHistory(before, after),
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
    );
  }

  Widget _buildDetailsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1B5E20),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _detailsRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeHistory(
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  ) {
    if (before == null && after == null) {
      return const Text(
        'No detailed values modified.',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    final keys = <String>{};
    if (before != null) keys.addAll(before.keys);
    if (after != null) keys.addAll(after.keys);

    // Clean schema technical properties
    keys.removeWhere(
      (k) =>
          k == 'updatedAt' ||
          k == 'createdAt' ||
          k == 'id' ||
          k == '_id' ||
          k == 'password' ||
          k == '__v' ||
          k == 'refreshToken',
    );

    if (keys.isEmpty) {
      return const Text(
        'No differences in fields detected.',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade200,
        width: 1,
        borderRadius: BorderRadius.circular(4),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Field',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Old Value',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'New Value',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        ...keys
            .map((k) {
              final oldVal = before?[k]?.toString() ?? '-';
              final newVal = after?[k]?.toString() ?? '-';
              if (oldVal == newVal)
                return const TableRow(
                  children: [SizedBox(), SizedBox(), SizedBox()],
                );
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      k,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      oldVal,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      newVal,
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            })
            .where((row) => row.children.first is! SizedBox),
      ],
    );
  }
}
