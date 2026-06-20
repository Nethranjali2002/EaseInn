/// Dashboard Screen - The main landing screen for mobile users after login.
///
/// This screen provides a personalized overview based on the user's role:
/// - **Admin (Owner)**: Sees full property stats, revenue, AI insights, and management features.
/// - **Manager**: Sees operational stats (rooms, bookings, tasks) and recent activity.
/// - **Staff**: Sees only their assigned tasks and a staff mode info card.
///
/// The dashboard loads data immediately via [initState] using a post-frame callback
/// to ensure the widget tree is built before fetching. It watches multiple providers
/// to reactively update the UI as data changes.
///
/// Architecture notes:
/// - Uses [ConsumerStatefulWidget] because we need both state management (Riverpod)
///   and lifecycle hooks (initState for data loading).
/// - Data is fetched from the first property in the user's property list. In a multi-
///   property scenario, this would need a property selector (future enhancement).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Trigger data loading after the first frame to avoid calling setState during build.
  /// This is a Flutter best practice - providers should be read/written after the
  /// widget tree is mounted, not during it.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// Loads dashboard, bookings, and tasks data for the user's first property.
  ///
  /// We use `ref.read()` (not `ref.watch()`) here because this is a one-time
  /// fetch triggered by initState. The UI will update reactively when the
  /// providers' states change.
  ///
  /// TODO: Support property selection when users have multiple properties.
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
    // Watch providers to rebuild the UI whenever their state changes.
    // `ref.watch()` establishes a subscription - when data updates, this widget rebuilds.
    final auth = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final taskState = ref.watch(taskProvider);
    final bookingState = ref.watch(bookingProvider);
    final user = auth.user;
    final isManager = user?.isManager ?? false;

    final greeting = _getGreeting();

    // SingleChildScrollView makes the dashboard scrollable on small screens.
    // Column with CrossAxisAlignment.start ensures left-aligned content flow.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personalized greeting based on time of day
          Text('Good $greeting, ${user?.name ?? ''}!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          // Role-specific subtitle clarifies what the user can see/do
          Text(
            user?.isAdmin == true
                ? 'Owner Dashboard - Full Access'
                : isManager
                    ? 'Manager Dashboard - Operations'
                    : 'Staff Dashboard - Assigned Tasks',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          // Property overview section - only shown to managers and admins.
          // Staff don't need property-level stats; they focus on their tasks.
          if (isManager) ...[
            _buildSectionTitle('Property Overview'),
            const SizedBox(height: 8),
            if (dashState.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // First row: Room inventory stats (always visible to managers)
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
              // Second row: Context-dependent stats based on user role.
              // Admins see revenue (sensitive financial data), managers see operational metrics.
              Row(
                children: [
                  _StatBox(label: 'Check-ins', value: '${dashState.stats.todayCheckIns}', color: Colors.purple),
                  const SizedBox(width: 8),
                  _StatBox(label: 'Check-outs', value: '${dashState.stats.todayCheckOuts}', color: Colors.teal),
                  const SizedBox(width: 8),
                  if (user?.isAdmin == true) ...[
                    _StatBox(label: 'Revenue', value: 'LKR ${(dashState.stats.totalRevenue / 1000).toStringAsFixed(0)}k', color: Colors.green),
                    const SizedBox(width: 8),
                    _StatBox(label: 'Payments Due', value: '${dashState.stats.pendingPayments}', color: Colors.red),
                  ] else ...[
                    _StatBox(label: 'Active Bookings', value: '${dashState.stats.activeBookings}', color: Colors.orange),
                    const SizedBox(width: 8),
                    _StatBox(label: 'Overdue Tasks', value: '${dashState.stats.overdueTasks}', color: Colors.red),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // AI Insights section - Admin-only feature for data-driven decisions.
              // These are placeholder cards; onTap handlers would navigate to
              // dedicated analytics screens in a full implementation.
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

              // Recent bookings - limited to 3 for quick glance on mobile.
              // Full booking list is in the dedicated Bookings screen.
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

          // Tasks section - visible to ALL roles (staff, managers, admins).
          // This is the primary view for staff users.
          _buildSectionTitle('My Tasks'),
          if (taskState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (taskState.tasks.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No tasks assigned'))))
          else
            // Limited to 5 tasks on dashboard; full list in Tasks screen
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
          // Staff mode info card - explains limitations to staff users.
          // This reduces support queries by setting clear expectations.
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

  /// Reusable section header for consistent visual hierarchy across the dashboard.
  /// Extracted as a method to avoid repeating the same Text widget styling.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  /// Returns a time-appropriate greeting based on the current hour.
  /// This is a simple UX touch that makes the app feel more personal.
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

/// Reusable stat card that displays a label, value, and color-coded indicator.
///
/// Used in a horizontal [Row] with [Expanded] to create an evenly-spaced
/// stat grid. The color parameter helps users quickly scan and differentiate
/// between stat categories (e.g., green for positive, red for attention needed).
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    // Expanded ensures equal width distribution in the parent Row
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
