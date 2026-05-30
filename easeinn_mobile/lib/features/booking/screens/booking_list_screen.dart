import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../booking/data/booking_provider.dart';
import '../../property/data/property_provider.dart';

class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen> {
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final props = ref.read(propertyProvider).properties;
      if (props.isNotEmpty) {
        ref.read(bookingProvider.notifier).fetchBookings(props.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/bookings/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by guest name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (v) {
                      final props = ref.read(propertyProvider).properties;
                      if (props.isNotEmpty) {
                        ref.read(bookingProvider.notifier).fetchBookings(props.first.id, search: v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(label: 'All', selected: _statusFilter == '', onTap: () => _filter('')),
                _FilterChip(label: 'Confirmed', selected: _statusFilter == 'confirmed', onTap: () => _filter('confirmed')),
                _FilterChip(label: 'Checked In', selected: _statusFilter == 'checked-in', onTap: () => _filter('checked-in')),
                _FilterChip(label: 'Checked Out', selected: _statusFilter == 'checked-out', onTap: () => _filter('checked-out')),
                _FilterChip(label: 'Cancelled', selected: _statusFilter == 'cancelled', onTap: () => _filter('cancelled')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.bookings.isEmpty
                    ? const Center(child: Text('No bookings found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.bookings.length,
                        itemBuilder: (ctx, i) {
                          final b = state.bookings[i];
                          return _BookingCard(booking: b);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _filter(String status) {
    setState(() => _statusFilter = status);
    final props = ref.read(propertyProvider).properties;
    if (props.isNotEmpty) {
      ref.read(bookingProvider.notifier).fetchBookings(props.first.id, status: status.isEmpty ? null : status);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(booking.guestName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _StatusBadge(status: booking.bookingStatus),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.room, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Room ${booking.roomNumber} (${booking.roomType})', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${booking.checkIn.day}/${booking.checkIn.month}/${booking.checkIn.year} - ${booking.checkOut.day}/${booking.checkOut.month}/${booking.checkOut.year}',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${booking.numberOfGuests} guest(s)', style: TextStyle(color: Colors.grey.shade600)),
                const Spacer(),
                Text('LKR ${booking.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _PaymentBadge(status: booking.paymentStatus, amount: booking.amountPaid, total: booking.totalAmount),
                const Spacer(),
                if (booking.bookingStatus == 'confirmed')
                  TextButton(
                    onPressed: () => context.go('/bookings/${booking.id}'),
                    child: const Text('View Details'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'checked-in': color = Colors.green; break;
      case 'checked-out': color = Colors.blue; break;
      case 'cancelled': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String status;
  final double amount;
  final double total;
  const _PaymentBadge({required this.status, required this.amount, required this.total});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'paid': color = Colors.green; break;
      case 'partial': color = Colors.orange; break;
      case 'refunded': color = Colors.purple; break;
      default: color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$status (${amount.toStringAsFixed(0)}/${total.toStringAsFixed(0)})',
          style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
