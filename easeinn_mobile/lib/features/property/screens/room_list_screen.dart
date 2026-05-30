import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../property/data/room_provider.dart';

class RoomListScreen extends ConsumerStatefulWidget {
  final String propertyId;
  const RoomListScreen({super.key, required this.propertyId});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomProvider.notifier).fetchRooms(widget.propertyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/properties/${widget.propertyId}/rooms/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(label: 'All', selected: _statusFilter == '', onTap: () => _filter('')),
                _FilterChip(label: 'Available', selected: _statusFilter == 'available', onTap: () => _filter('available')),
                _FilterChip(label: 'Booked', selected: _statusFilter == 'booked', onTap: () => _filter('booked')),
                _FilterChip(label: 'Maintenance', selected: _statusFilter == 'maintenance', onTap: () => _filter('maintenance')),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.rooms.isEmpty
                    ? const Center(child: Text('No rooms found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.rooms.length,
                        itemBuilder: (ctx, i) {
                          final room = state.rooms[i];
                          return _RoomCard(room: room);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _filter(String status) {
    setState(() => _statusFilter = status);
    ref.read(roomProvider.notifier).fetchRooms(widget.propertyId, status: status.isEmpty ? null : status);
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
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (room.status) {
      case 'available': statusColor = Colors.green; break;
      case 'booked': statusColor = Colors.blue; break;
      case 'maintenance': statusColor = Colors.orange; break;
      default: statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(room.roomNumber, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.name.isNotEmpty ? room.name : 'Room ${room.roomNumber}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${room.roomType} • Floor ${room.floor} • Capacity ${room.capacity}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(room.status, style: TextStyle(fontSize: 11, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('LKR ${room.basePrice.toStringAsFixed(0)}/night',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                const Spacer(),
                if (room.amenities.isNotEmpty)
                  Text('${room.amenities.length} amenities', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
