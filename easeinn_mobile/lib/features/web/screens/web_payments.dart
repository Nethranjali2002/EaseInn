import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../booking/data/booking_provider.dart';
import '../../property/data/property_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/auth_provider.dart';
import '../widgets/web_form_dialog.dart';
import '../widgets/web_data_table.dart';

class Payment {
  final String id;
  final String bookingId;
  final String guestName;
  final double amount;
  final String method;
  final String type;
  final String status;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.guestName,
    required this.amount,
    required this.method,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['_id'] ?? json['id'] ?? '',
      bookingId: json['booking']?['_id'] ?? json['booking'] ?? '',
      guestName: json['booking']?['guest']?['name'] ?? json['guestName'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
      method: json['method'] ?? 'cash',
      type: json['type'] ?? 'full_payment',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String()),
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

final paymentProvider =
    NotifierProvider<PaymentNotifier, PaymentState>(PaymentNotifier.new);

class PaymentNotifier extends Notifier<PaymentState> {
  @override
  PaymentState build() => PaymentState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> fetchPayments(String propertyId) async {
    state = PaymentState(isLoading: true);
    try {
      final response =
          await _api.get('/properties/$propertyId/payments');
      final data = response.data['data'];
      final payments = (data['payments'] as List?)
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

  Future<bool> createPayment(String propertyId, Map<String, dynamic> data) async {
    state = PaymentState(isLoading: true, payments: state.payments);
    try {
      final response =
          await _api.post('/properties/$propertyId/payments', data: data);
      final payment = Payment.fromJson(response.data['data']['payment']);
      state = PaymentState(
        payments: [payment, ...state.payments],
        totalRevenue: state.totalRevenue +
            (payment.status == 'completed' ? payment.amount : 0),
        pendingAmount: state.pendingAmount +
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
      final response =
          await _api.patch('/payments/$paymentId/status', data: {'status': status});
      final payment = Payment.fromJson(response.data['data']['payment']);
      state = PaymentState(
        payments: state.payments
            .map((p) => p.id == paymentId ? payment : p)
            .toList(),
        totalRevenue: state.payments
            .where((p) => p.id != paymentId && (p.status == 'completed' || p.status == 'paid'))
            .fold(0.0, (sum, p) => sum + p.amount) +
            (status == 'completed' || status == 'paid' ? payment.amount : 0),
        pendingAmount: state.payments
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await ref.read(propertyProvider.notifier).fetchProperties();
    final properties = ref.read(propertyProvider).properties;
    if (properties.isNotEmpty) {
      final pid = properties.first.id;
      await ref.read(bookingProvider.notifier).fetchBookings(pid);
      await ref.read(paymentProvider.notifier).fetchPayments(pid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);
    final bookings = ref.watch(bookingProvider).bookings;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payments',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Payment'),
                onPressed: () => _showPaymentDialog(context, bookings),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRevenueCards(state),
          const SizedBox(height: 20),
          Expanded(
            child: state.isLoading && state.payments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.payments.isEmpty
                    ? const Center(child: Text('No payments found'))
                    : WebDataTable(
                        searchHint: 'Search payments...',
                        columns: const [
                          DataColumn(label: Text('Guest')),
                          DataColumn(label: Text('Booking')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Method')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: state.payments
                            .map((p) => _paymentRow(p))
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCards(PaymentState state) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.attach_money,
                        color: Color(0xFF2E7D32), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Revenue',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        'LKR ${state.totalRevenue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.pending_outlined,
                        color: Colors.orange.shade700, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pending',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        'LKR ${state.pendingAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: Color(0xFF1565C0), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transactions',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '${state.payments.length}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DataCell> _paymentRow(Payment p) {
    return [
      DataCell(
        Text(p.guestName.isNotEmpty ? p.guestName : '-',
            style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
      DataCell(Text(p.bookingId.length > 8
          ? '${p.bookingId.substring(0, 8)}...'
          : p.bookingId)),
      DataCell(Text('LKR ${p.amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600))),
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
      DataCell(Text(p.type.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontSize: 11))),
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
      DataCell(Text(DateFormat('MMM dd, yyyy').format(p.createdAt))),
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
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(
      BuildContext context, List<dynamic> bookings) async {
    final properties = ref.read(propertyProvider).properties;
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No properties available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final propertyId = properties.first.id;

    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedBookingId;
    String method = 'cash';
    String type = 'full_payment';
    bool isSaving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Record Payment'),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: selectedBookingId,
                          isExpanded: true,
                          items: bookings
                              .map<DropdownMenuItem<String>>((b) =>
                                  DropdownMenuItem(
                                    value: b.id,
                                    child: Text(
                                        '${b.guestName} - Room ${b.roomNumber}'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setDialogState(() => selectedBookingId = v);
                          },
                          validator: (v) => v == null ? 'Select booking' : null,
                          decoration: const InputDecoration(
                            labelText: 'Booking',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      WebFormField(
                        label: 'Amount',
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = double.tryParse(v.trim());
                          if (val == null || val <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: method,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(
                                value: 'card', child: Text('Card')),
                            DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Bank Transfer')),
                            DropdownMenuItem(
                                value: 'online', child: Text('Online')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => method = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: type,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                                value: 'full_payment',
                                child: Text('Full Payment')),
                            DropdownMenuItem(
                                value: 'partial_payment',
                                child: Text('Partial Payment')),
                            DropdownMenuItem(
                                value: 'deposit', child: Text('Deposit')),
                            DropdownMenuItem(
                                value: 'refund', child: Text('Refund')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => type = v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Payment Type',
                            border: OutlineInputBorder(),
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
                        setDialogState(() => isSaving = true);
                        final success = await ref
                            .read(paymentProvider.notifier)
                            .createPayment(propertyId, {
                          'booking': selectedBookingId,
                          'amount': double.parse(amountController.text),
                          'method': method,
                          'type': type,
                        });
                        if (ctx.mounted) Navigator.pop(ctx, success);
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Record'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment recorded'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _loadData();
    }
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
