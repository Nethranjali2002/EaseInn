import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_provider.dart';
import '../../booking/data/booking_provider.dart';
import '../../property/data/property_provider.dart';
import '../../task/data/task_provider.dart';
import '../data/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final props = ref.read(propertyProvider).properties;
    if (props.isNotEmpty) {
      final pid = props.first.id;
      ref.read(dashboardProvider.notifier).fetchDashboard(pid);
      ref.read(bookingProvider.notifier).fetchBookings(pid);
      ref.read(taskProvider.notifier).fetchMyTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final taskState = ref.watch(taskProvider);
    final bookingState = ref.watch(bookingProvider);
    final user = auth.user;
    final isManager = user?.isManager ?? false;

    final greeting = _getGreeting();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good $greeting, ${user?.name ?? ''}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            user?.isAdmin == true
                ? 'Owner Dashboard - Full Access'
                : isManager
                    ? 'Manager Dashboard - Operations'
                    : 'Staff Dashboard - Assigned Tasks',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          if (isManager) ...[
            _buildSectionTitle('Property Overview'),
            const SizedBox(height: 8),
            if (dashState.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                children: [
                  _StatBox(label: 'Rooms', value: '${dashState.stats.totalRooms}', color: Colors.blue),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Available', value: '${dashState.stats.availableRooms}', color: Colors.green),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Booked', value: '${dashState.stats.bookedRooms}', color: Colors.orange),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Tasks Open', value: '${dashState.stats.openTasks}', color: Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatBox(label: 'Check-ins', value: '${dashState.stats.todayCheckIns}', color: Colors.purple),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Check-outs', value: '${dashState.stats.todayCheckOuts}', color: Colors.teal),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Revenue', value: 'LKR ${(dashState.stats.totalRevenue / 1000).toStringAsFixed(0)}k', color: Colors.green),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Payments Due', value: '${dashState.stats.pendingPayments}', color: Colors.red),
                ],
              ),
              const SizedBox(height: 24),

              if (user?.isAdmin == true) ...[
                _buildSectionTitle('AI Insights'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.psychology, color: Color(0xFF1B5E20)),
                    title: const Text('Pricing Suggestions'),
                    subtitle: const Text('AI-powered room pricing recommendations'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_up, color: Colors.blue),
                    title: const Text('Demand Forecast'),
                    subtitle: const Text('3-month booking prediction'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assessment, color: Colors.purple),
                    title: const Text('Consolidated Report'),
                    subtitle: const Text('Cross-property analytics'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _buildSectionTitle('Recent Bookings'),
              ...bookingState.bookings.take(3).map((b) => Card(
                child: ListTile(
                  leading: Icon(Icons.person, color: b.bookingStatus == 'checked-in' ? Colors.green : Colors.blue),
                  title: Text(b.guestName),
                  subtitle: Text('Room ${b.roomNumber} • ${b.checkIn.day}/${b.checkIn.month}'),
                  trailing: Text(b.bookingStatus, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
              )),
              const SizedBox(height: 24),
            ],
          ],

          _buildSectionTitle('My Tasks'),
          if (taskState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (taskState.tasks.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No tasks assigned'))))
          else
            ...taskState.tasks.take(5).map((t) => Card(
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
            )),

          const SizedBox(height: 16),
          if (!isManager)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text('Staff Mode'),
                subtitle: const Text('You can view and complete your assigned tasks. Contact your manager for booking or property changes.'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
