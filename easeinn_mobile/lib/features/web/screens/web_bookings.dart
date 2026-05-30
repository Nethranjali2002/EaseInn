import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../booking/data/booking_provider.dart';
import '../../property/data/property_provider.dart';
import '../../property/data/room_provider.dart';
import '../widgets/web_data_table.dart';
import '../widgets/web_form_dialog.dart';

class WebBookingsScreen extends ConsumerStatefulWidget {
  const WebBookingsScreen({super.key});

  @override
  ConsumerState<WebBookingsScreen> createState() => _WebBookingsScreenState();
}

class _WebBookingsScreenState extends ConsumerState<WebBookingsScreen> {
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
      await ref.read(roomProvider.notifier).fetchRooms(pid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final rooms = ref.watch(roomProvider).rooms;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bookings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Booking'),
                onPressed: () => _showBookingDialog(context, rooms),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: state.isLoading && state.bookings.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.bookings.isEmpty
                    ? const Center(child: Text('No bookings found'))
                    : WebDataTable(
                        searchHint: 'Search bookings...',
                        columns: const [
                          DataColumn(label: Text('Guest')),
                          DataColumn(label: Text('Room')),
                          DataColumn(label: Text('Check-in')),
                          DataColumn(label: Text('Check-out')),
                          DataColumn(label: Text('Guests')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Payment')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: state.bookings
                            .map((b) => _bookingRow(b))
                            .toList(),
                      ),
          ),
        ],
      ),
    );
  }

  List<DataCell> _bookingRow(Booking b) {
    return [
      DataCell(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.guestName, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              b.guestEmail,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      DataCell(Text('${b.roomNumber} (${b.roomType})')),
      DataCell(Text(DateFormat('MMM dd, yyyy').format(b.checkIn))),
      DataCell(Text(DateFormat('MMM dd, yyyy').format(b.checkOut))),
      DataCell(Text('${b.numberOfGuests}')),
      DataCell(Text('LKR ${b.totalAmount.toStringAsFixed(0)}')),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (b.bookingStatus == 'confirmed') ...[
              _actionChip(
                'Check-in',
                const Color(0xFF2E7D32),
                () => _doCheckIn(b),
              ),
              const SizedBox(width: 4),
              _actionChip(
                'Cancel',
                Colors.red,
                () => _doCancel(b),
              ),
            ] else if (b.bookingStatus == 'checked-in' ||
                b.bookingStatus == 'checked_in') ...[
              _actionChip(
                'Check-out',
                const Color(0xFF1565C0),
                () => _doCheckOut(b),
              ),
            ] else ...[
              const Text('-', style: TextStyle(color: Colors.grey)),
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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }

  Future<void> _doCheckIn(Booking booking) async {
    final success = await ref.read(bookingProvider.notifier).checkIn(booking.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Guest checked in' : 'Failed to check in'),
          backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
        ),
      );
    }
  }

  Future<void> _doCheckOut(Booking booking) async {
    final success = await ref.read(bookingProvider.notifier).checkOut(booking.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Guest checked out' : 'Failed to check out'),
          backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red,
        ),
      );
    }
  }

  Future<void> _doCancel(Booking booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cancel booking for ${booking.guestName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
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
    }
  }

  Future<void> _showBookingDialog(
      BuildContext context, List<Room> rooms) async {
    final formKey = GlobalKey<FormState>();
    final guestNameController = TextEditingController();
    final guestEmailController = TextEditingController();
    final guestPhoneController = TextEditingController();
    final guestsCountController = TextEditingController(text: '1');
    String? selectedRoomId;
    DateTime? checkIn;
    DateTime? checkOut;
    bool isSaving = false;

    final properties = ref.read(propertyProvider).properties;
    String? selectedPropertyId = properties.isNotEmpty ? properties.first.id : null;

    final availableRooms = rooms.where((r) => r.status == 'available').toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: const Text('New Booking'),
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
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(v.trim())) return 'Invalid email address';
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
                          if (!phoneRegex.hasMatch(v.trim())) return 'Invalid phone number';
                          return null;
                        },
                      ),
                      WebFormField(
                        label: 'Number of Guests',
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
                              final room = rooms.firstWhere((r) => r.id == selectedRoomId);
                              if (count > room.capacity) {
                                return 'Exceeds room capacity (${room.capacity})';
                              }
                            } catch (_) {}
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: selectedPropertyId,
                          isExpanded: true,
                          items: properties
                              .map((p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(p.name),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedPropertyId = v),
                          decoration: const InputDecoration(
                            labelText: 'Property',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: selectedRoomId,
                          isExpanded: true,
                          items: availableRooms
                              .map((r) => DropdownMenuItem(
                                    value: r.id,
                                    child: Text(
                                        '${r.roomNumber} - ${r.roomType} (LKR ${r.basePrice.toStringAsFixed(0)}/night)'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedRoomId = v),
                          validator: (v) => v == null ? 'Select a room' : null,
                          decoration: const InputDecoration(
                            labelText: 'Room',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
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
                                  checkIn?.add(const Duration(days: 1)) ??
                                      DateTime.now().add(
                                        const Duration(days: 1),
                                      ),
                              firstDate: checkIn ?? DateTime.now(),
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
                              content: Text('Please select check-in and check-out dates'),
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
                        final selectedRoom = rooms.firstWhere((r) => r.id == selectedRoomId);
                        final success = await ref
                            .read(bookingProvider.notifier)
                            .createBooking({
                          'property': selectedPropertyId,
                          'room': selectedRoomId,
                          'guest': {
                            'name': guestNameController.text.trim(),
                            'email': guestEmailController.text.trim(),
                            'phone': guestPhoneController.text.trim(),
                          },
                          'checkIn': checkIn!.toIso8601String(),
                          'checkOut': checkOut!.toIso8601String(),
                          'numberOfGuests':
                              int.parse(guestsCountController.text),
                          'roomType': selectedRoom.roomType,
                        });
                        if (ctx.mounted) Navigator.pop(ctx, success);
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking created'),
          backgroundColor: Color(0xFF2E7D32),
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
}
