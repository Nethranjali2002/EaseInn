import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../booking/data/booking_provider.dart';
import '../../property/data/property_provider.dart';
import '../../task/data/task_provider.dart';
import '../data/dashboard_provider.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  String? _selectedPropertyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final props = ref.read(propertyProvider).properties;
    if (props.isNotEmpty && _selectedPropertyId == null) {
      setState(() => _selectedPropertyId = props.first.id);
      ref.read(dashboardProvider.notifier).fetchDashboard(_selectedPropertyId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final propState = ref.watch(propertyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.business),
            onPressed: () => context.go('/properties'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedPropertyId != null) {
            await ref.read(dashboardProvider.notifier).fetchDashboard(_selectedPropertyId!);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (propState.properties.isNotEmpty)
                DropdownButton<String>(
                  value: _selectedPropertyId,
                  hint: const Text('Select Property'),
                  isExpanded: true,
                  items: propState.properties.map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.name))
                  ).toList(),
                  onChanged: (val) {
                    setState(() => _selectedPropertyId = val);
                    if (val != null) ref.read(dashboardProvider.notifier).fetchDashboard(val);
                  },
                ),
              const SizedBox(height: 16),
              if (dashState.isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _buildStatsGrid(dashState.stats),
                const SizedBox(height: 24),
                _buildSectionTitle('Recent Bookings'),
                ...dashState.recentBookings.map((b) => _BookingTile(booking: b)),
                const SizedBox(height: 24),
                _buildSectionTitle('Urgent Tasks'),
                ...dashState.urgentTasks.map((t) => _TaskTile(task: t)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(icon: Icons.hotel, title: 'Total Rooms', value: '${stats.totalRooms}', color: Colors.blue),
        _StatCard(icon: Icons.check_circle, title: 'Available', value: '${stats.availableRooms}', color: Colors.green),
        _StatCard(icon: Icons.book_online, title: 'Active Bookings', value: '${stats.activeBookings}', color: Colors.orange),
        _StatCard(icon: Icons.login, title: 'Check-ins Today', value: '${stats.todayCheckIns}', color: Colors.purple),
        _StatCard(icon: Icons.logout, title: 'Check-outs Today', value: '${stats.todayCheckOuts}', color: Colors.teal),
        _StatCard(icon: Icons.task, title: 'Open Tasks', value: '${stats.openTasks}', color: Colors.amber),
        _StatCard(icon: Icons.warning, title: 'Overdue Tasks', value: '${stats.overdueTasks}', color: Colors.red),
        _StatCard(icon: Icons.attach_money, title: 'Revenue', value: 'LKR ${stats.totalRevenue.toStringAsFixed(0)}', color: Colors.green),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: booking.bookingStatus == 'checked-in' ? Colors.green.shade100 : Colors.blue.shade100,
          child: Icon(Icons.person, color: booking.bookingStatus == 'checked-in' ? Colors.green : Colors.blue, size: 20),
        ),
        title: Text(booking.guestName, style: const TextStyle(fontSize: 14)),
        subtitle: Text('Room ${booking.roomNumber} • ${booking.checkIn.day}/${booking.checkIn.month}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: booking.bookingStatus == 'checked-in' ? Colors.green.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(booking.bookingStatus, style: TextStyle(fontSize: 11, color: booking.bookingStatus == 'checked-in' ? Colors.green : Colors.blue)),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final TaskItem task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: task.priority == 'urgent' ? Colors.red.shade100 : Colors.amber.shade100,
          child: Icon(Icons.task, color: task.priority == 'urgent' ? Colors.red : Colors.amber, size: 20),
        ),
        title: Text(task.title, style: const TextStyle(fontSize: 14)),
        subtitle: Text('${task.type} • ${task.roomNumber}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: task.priority == 'urgent' ? Colors.red.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(task.priority, style: TextStyle(fontSize: 11, color: task.priority == 'urgent' ? Colors.red : Colors.amber)),
        ),
      ),
    );
  }
}
