import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared/shared.dart';
import '../widgets/web_data_table.dart';

class Payment {
  final String id;
  final String code;
  final String bookingId;
  final String bookingCode;
  final String guestName;
  final String propertyId;
  final double amount;
  final String method;
  final String type;
  final String status;
  final DateTime createdAt;

  Payment({
    required this.id,
    this.code = '',
    required this.bookingId,
    this.bookingCode = '',
    required this.guestName,
    required this.propertyId,
    required this.amount,
    required this.method,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final bookingJson = json['booking'];
    return Payment(
      id: json['_id'] ?? json['id'] ?? '',
      code: json['code'] ?? '',
      bookingId: bookingJson is Map
          ? (bookingJson['_id'] ?? bookingJson['id'] ?? '')
          : (json['booking'] ?? ''),
      bookingCode: bookingJson is Map ? (bookingJson['code'] ?? '') : '',
      guestName: bookingJson is Map
          ? (bookingJson['guest']?['name'] ?? '')
          : (json['guestName'] ?? ''),
      propertyId: json['property'] is Map
          ? (json['property']['_id'] ?? json['property']['id'] ?? '')
          : (json['property'] ?? ''),
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
      method: json['method'] ?? 'cash',
      type: json['type'] ?? 'full',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class PaymentState {
  final List<Payment> payments;
  final bool isLoading;
  final String? error;
  final double totalRevenue;
  final double pendingAmount;

  PaymentState({
    this.payments = const [],
    this.isLoading = false,
    this.error,
    this.totalRevenue = 0,
    this.pendingAmount = 0,
  });
}

final paymentProvider = NotifierProvider<PaymentNotifier, PaymentState>(
  PaymentNotifier.new,
);

class PaymentNotifier extends Notifier<PaymentState> {
  @override
  PaymentState build() => PaymentState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetchPayments(String propertyId) async {
    state = PaymentState(isLoading: true);
    try {
      final response = await _api.get('/properties/$propertyId/payments');
      final data = response.data['data'];
      final payments =
          (data['payments'] as List?)
              ?.map((p) => Payment.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [];
      double totalRevenue = 0;
      double pendingAmount = 0;
      for (final p in payments) {
        if (p.status == 'completed' || p.status == 'paid') {
          totalRevenue += p.amount;
        }
        if (p.status == 'pending') {
          pendingAmount += p.amount;
        }
      }
      state = PaymentState(
        payments: payments,
        totalRevenue: totalRevenue,
        pendingAmount: pendingAmount,
      );
    } on ApiException catch (e) {
      state = PaymentState(isLoading: false, error: e.message);
    } catch (e) {
      state = PaymentState(isLoading: false, error: 'Failed to load payments');
    }
  }

  Future<bool> createPayment(
    String propertyId,
    Map<String, dynamic> data,
  ) async {
    state = PaymentState(isLoading: true, payments: state.payments);
    try {
      // POST route on backend is /payments
      final response = await _api.post('/payments', data: data);
      final payment = Payment.fromJson(response.data['data']['payment']);
      state = PaymentState(
        payments: [payment, ...state.payments],
        totalRevenue:
            state.totalRevenue +
            (payment.status == 'completed' ? payment.amount : 0),
        pendingAmount:
            state.pendingAmount +
            (payment.status == 'pending' ? payment.amount : 0),
      );
      return true;
    } on ApiException catch (e) {
      state = PaymentState(isLoading: false, error: e.message);
      return false;
    }
  }

  Future<bool> updatePaymentStatus(String paymentId, String status) async {
    try {
      final response = await _api.patch(
        '/payments/$paymentId/status',
        data: {'status': status},
      );
      final payment = Payment.fromJson(response.data['data']['payment']);
      state = PaymentState(
        payments: state.payments
            .map((p) => p.id == paymentId ? payment : p)
            .toList(),
        totalRevenue:
            state.payments
                .where(
                  (p) =>
                      p.id != paymentId &&
                      (p.status == 'completed' || p.status == 'paid'),
                )
                .fold(0.0, (sum, p) => sum + p.amount) +
            (status == 'completed' || status == 'paid' ? payment.amount : 0),
        pendingAmount:
            state.payments
                .where((p) => p.id != paymentId && p.status == 'pending')
                .fold(0.0, (sum, p) => sum + p.amount) +
            (status == 'pending' ? payment.amount : 0),
      );
      return true;
    } on ApiException catch (e) {
      state = PaymentState(isLoading: false, error: e.message);
      return false;
    }
  }
}

class WebPaymentsScreen extends ConsumerStatefulWidget {
  const WebPaymentsScreen({super.key});

  @override
  ConsumerState<WebPaymentsScreen> createState() => _WebPaymentsScreenState();
}

class _WebPaymentsScreenState extends ConsumerState<WebPaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedPropertyId = 'All';
  String _selectedStatus = 'All';
  String _selectedMethod = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await ref.read(propertyProvider.notifier).fetchProperties();
    await _fetchPaymentsForProperty(_selectedPropertyId);
  }

  Future<void> _fetchPaymentsForProperty(String pid) async {
    final properties = ref.read(propertyProvider).properties;
    if (pid == 'All') {
      ref.read(paymentProvider.notifier).state = PaymentState(isLoading: true);
      try {
        final List<Payment> allPayments = [];
        for (final p in properties) {
          final response = await ref
              .read(apiClientProvider)
              .get('/properties/${p.id}/payments');
          final data = response.data['data'];
          final payments =
              (data['payments'] as List?)
                  ?.map((p) => Payment.fromJson(p as Map<String, dynamic>))
                  .toList() ??
              [];
          allPayments.addAll(payments);
        }
        double totalRevenue = 0;
        double pendingAmount = 0;
        for (final p in allPayments) {
          if (p.status == 'completed' || p.status == 'paid') {
            totalRevenue += p.amount;
          }
          if (p.status == 'pending') {
            pendingAmount += p.amount;
          }
        }
        ref.read(paymentProvider.notifier).state = PaymentState(
          payments: allPayments,
          totalRevenue: totalRevenue,
          pendingAmount: pendingAmount,
        );
      } catch (e) {
        ref.read(paymentProvider.notifier).state = PaymentState(
          isLoading: false,
          error: e.toString(),
        );
      }
    } else {
      await ref.read(paymentProvider.notifier).fetchPayments(pid);
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedStatus = 'All';
      _selectedMethod = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);
    final properties = ref.watch(propertyProvider).properties;

    // Apply filtering
    final filteredPayments = state.payments.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            p.id.toLowerCase().contains(q) ||
            p.bookingId.toLowerCase().contains(q) ||
            p.guestName.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_selectedStatus != 'All') {
        if (p.status.toLowerCase() != _selectedStatus.toLowerCase())
          return false;
      }
      if (_selectedMethod != 'All') {
        if (p.method.toLowerCase() != _selectedMethod.toLowerCase())
          return false;
      }
      return true;
    }).toList();

    // Summary Card calculation from filtered data
    final totalRevenue = filteredPayments
        .where((p) => p.status == 'completed' || p.status == 'paid')
        .fold(0.0, (sum, p) => sum + p.amount);
    final pendingAmount = filteredPayments
        .where((p) => p.status == 'pending')
        .fold(0.0, (sum, p) => sum + p.amount);
    final transactionsCount = filteredPayments.length;
    final refundAmount = filteredPayments
        .where((p) => p.status == 'refunded' || p.type == 'refund')
        .fold(0.0, (sum, p) => sum + p.amount);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payments Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildRevenueCard(
                    'Total Revenue',
                    'LKR ${totalRevenue.toStringAsFixed(0)}',
                    Icons.payments,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRevenueCard(
                    'Pending Payments',
                    'LKR ${pendingAmount.toStringAsFixed(0)}',
                    Icons.hourglass_top,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRevenueCard(
                    'Transactions',
                    '$transactionsCount',
                    Icons.receipt_long,
                    const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRevenueCard(
                    'Refunds',
                    'LKR ${refundAmount.toStringAsFixed(0)}',
                    Icons.replay_circle_filled_outlined,
                    const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filters Section
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
                    Row(
                      children: [
                        // Search Field
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText:
                                  'Search Guest, Booking ID, Payment ID...',
                              prefixIcon: Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              if (v != null) {
                                setState(() => _selectedPropertyId = v);
                                _fetchPaymentsForProperty(v);
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Payment Status Filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All Statuses'),
                              ),
                              DropdownMenuItem(
                                value: 'completed',
                                child: Text('Completed'),
                              ),
                              DropdownMenuItem(
                                value: 'pending',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'failed',
                                child: Text('Failed'),
                              ),
                              DropdownMenuItem(
                                value: 'refunded',
                                child: Text('Refunded'),
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
                        const SizedBox(width: 12),
                        // Payment Method Filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedMethod,
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All Methods'),
                              ),
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'card',
                                child: Text('Card'),
                              ),
                              DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Bank Transfer'),
                              ),
                              DropdownMenuItem(
                                value: 'online',
                                child: Text('Online'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedMethod = v!),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.filter_alt_off,
                            color: Colors.red,
                          ),
                          tooltip: 'Clear Filters',
                          onPressed: _clearFilters,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payments Data Table
            SizedBox(
              width: double.infinity,
              height: 600,
              child: state.isLoading && state.payments.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPayments.isEmpty
                  ? const Center(
                      child: Text('No payments found matching filters.'),
                    )
                  : WebDataTable(
                      showSearch: false,
                      searchHint: 'Filtered Payments',
                      columns: const [
                        DataColumn(label: Text('Payment ID')),
                        DataColumn(label: Text('Booking ID')),
                        DataColumn(label: Text('Guest')),
                        DataColumn(label: Text('Property')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Method')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filteredPayments
                          .map((p) => _paymentRow(p, properties))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(
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

  List<DataCell> _paymentRow(Payment p, List<Property> properties) {
    final displayPaymentId = p.code.isNotEmpty
        ? p.code
        : 'PAY-${p.id.length > 4 ? p.id.substring(p.id.length - 4).toUpperCase() : p.id.toUpperCase()}';
    final displayBookingId = p.bookingCode.isNotEmpty
        ? p.bookingCode
        : 'BK-${p.bookingId.length > 4 ? p.bookingId.substring(p.bookingId.length - 4).toUpperCase() : p.bookingId.toUpperCase()}';
    final propertyName = properties
        .firstWhere(
          (prop) => prop.id == p.propertyId,
          orElse: () => Property(id: '', name: 'Resort'),
        )
        .name;

    return [
      DataCell(
        Text(
          displayPaymentId,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      DataCell(Text(displayBookingId)),
      DataCell(
        Text(
          p.guestName.isNotEmpty ? p.guestName : '-',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      DataCell(Text(propertyName)),
      DataCell(
        Text(
          'LKR ${p.amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _methodColor(p.method).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            p.method.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _methodColor(p.method),
            ),
          ),
        ),
      ),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _paymentStatusColor(p.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            p.status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _paymentStatusColor(p.status),
            ),
          ),
        ),
      ),
      DataCell(Text(DateFormat('dd MMM yyyy').format(p.createdAt))),
      DataCell(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.status == 'pending') ...[
              _actionChip('Complete', const Color(0xFF2E7D32), () async {
                await ref
                    .read(paymentProvider.notifier)
                    .updatePaymentStatus(p.id, 'completed');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment marked as completed'),
                      backgroundColor: Color(0xFF2E7D32),
                    ),
                  );
                  _loadData();
                }
              }),
              const SizedBox(width: 4),
              _actionChip('Fail', Colors.red, () async {
                await ref
                    .read(paymentProvider.notifier)
                    .updatePaymentStatus(p.id, 'failed');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment marked as failed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _loadData();
                }
              }),
            ] else ...[
              Text(
                p.status == 'completed' || p.status == 'paid'
                    ? 'Completed'
                    : p.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: _paymentStatusColor(p.status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _actionChip(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'cash':
        return const Color(0xFF2E7D32);
      case 'card':
        return const Color(0xFF1565C0);
      case 'bank_transfer':
        return const Color(0xFF6A1B9A);
      case 'online':
        return const Color(0xFFE65100);
      default:
        return Colors.grey;
    }
  }

  Color _paymentStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'paid':
        return const Color(0xFF2E7D32);
      case 'pending':
        return Colors.orange;
      case 'failed':
        return const Color(0xFFC62828);
      case 'refunded':
        return const Color(0xFF1565C0);
      default:
        return Colors.grey;
    }
  }
}
