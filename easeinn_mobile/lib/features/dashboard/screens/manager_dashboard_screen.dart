import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../booking/data/booking_provider.dart';
import '../../property/data/property_provider.dart';
import '../../task/data/task_provider.dart';
import '../data/dashboard_provider.dart';

class ManagerDashboardScreen extends ConsumerStatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  ConsumerState<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends ConsumerState<ManagerDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final props = ref.read(propertyProvider).properties;
      if (props.isNotEmpty) {
        ref.read(dashboardProvider.notifier).fetchDashboard(props.first.id);
        ref.read(bookingProvider.notifier).fetchBookings(props.first.id);
        ref.read(taskProvider.notifier).fetchTasks(props.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);
    final bookingState = ref.watch(bookingProvider);
    final taskState = ref.watch(taskProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => context.go('/bookings'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: _currentIndex == 0
          ? RefreshIndicator(
              onRefresh: () async {
                final props = ref.read(propertyProvider).properties;
                if (props.isNotEmpty) {
                  await ref.read(dashboardProvider.notifier).fetchDashboard(props.first.id);
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickStats(dashState.stats),
                    const SizedBox(height: 24),
                    const Text('Today\'s Check-ins', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...bookingState.bookings.where((b) => b.bookingStatus == 'confirmed').take(5).map(
                      (b) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.login, color: Colors.green),
                          title: Text(b.guestName),
                          subtitle: Text('Room ${b.roomNumber}'),
                          trailing: TextButton(
                            onPressed: () => ref.read(bookingProvider.notifier).checkIn(b.id),
                            child: const Text('Check In'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Urgent Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...taskState.tasks.where((t) => t.priority == 'urgent' || t.status == 'open').take(5).map(
                      (t) => Card(
                        child: ListTile(
                          leading: Icon(
                            t.status == 'completed' ? Icons.check_circle : Icons.pending,
                            color: t.status == 'completed' ? Colors.green : Colors.orange,
                          ),
                          title: Text(t.title),
                          subtitle: Text('${t.type} • ${t.roomNumber}'),
                          trailing: TextButton(
                            onPressed: () => context.go('/tasks/${t.id}'),
                            child: const Text('View'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _currentIndex == 1
              ? _buildBookingsTab(bookingState)
              : _buildTasksTab(taskState),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
        ],
      ),
    );
  }

  Widget _buildQuickStats(DashboardStats stats) {
    return Row(
      children: [
        Expanded(child: _QuickStat(label: 'Check-ins', value: '${stats.todayCheckIns}', color: Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _QuickStat(label: 'Check-outs', value: '${stats.todayCheckOuts}', color: Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _QuickStat(label: 'Pending', value: '${stats.pendingPayments}', color: Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _QuickStat(label: 'Tasks', value: '${stats.openTasks}', color: Colors.blue)),
      ],
    );
  }

  Widget _buildBookingsTab(BookingState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search bookings...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (v) => ref.read(bookingProvider.notifier).fetchBookings(
                    ref.read(propertyProvider).properties.first.id,
                    search: v,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.bookings.length,
                  itemBuilder: (ctx, i) {
                    final b = state.bookings[i];
                    return Card(
                      child: ListTile(
                        title: Text(b.guestName),
                        subtitle: Text('Room ${b.roomNumber} • ${b.checkIn.day}/${b.checkIn.month} - ${b.checkOut.day}/${b.checkOut.month}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: b.bookingStatus == 'checked-in' ? Colors.green.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(b.bookingStatus, style: TextStyle(fontSize: 11)),
                        ),
                        onTap: () => context.go('/bookings/${b.id}'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTasksTab(TaskState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '', label: Text('All')),
                    ButtonSegment(value: 'open', label: Text('Open')),
                    ButtonSegment(value: 'in-progress', label: Text('Active')),
                    ButtonSegment(value: 'completed', label: Text('Done')),
                  ],
                  selected: const {''},
                  onSelectionChanged: (v) => ref.read(taskProvider.notifier).fetchTasks(
                    ref.read(propertyProvider).properties.first.id,
                    status: v.first.isEmpty ? null : v.first,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.tasks.length,
                  itemBuilder: (ctx, i) {
                    final t = state.tasks[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          t.status == 'completed' ? Icons.check_circle : Icons.pending,
                          color: t.status == 'completed' ? Colors.green : Colors.orange,
                        ),
                        title: Text(t.title),
                        subtitle: Text('${t.type} • ${t.roomNumber}'),
                        trailing: Text(t.priority, style: TextStyle(
                          fontSize: 12,
                          color: t.priority == 'urgent' ? Colors.red : Colors.grey,
                        )),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuickStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
