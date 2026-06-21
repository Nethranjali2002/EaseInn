import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'web_login.dart';
import 'web_shell.dart';
import 'web_dashboard.dart';
import 'web_properties.dart';
import 'web_bookings.dart';
import 'web_rooms.dart';
import 'web_tasks.dart';
import 'web_payments.dart';
import 'web_users.dart';
import 'web_profile.dart';
import 'web_notifications.dart';
import 'web_calendar.dart';
import 'public_review_screen.dart';
import 'web_feedback.dart';
import 'web_audit_log.dart';

/// ==========================================
/// WEB APP - Router & Theme Configuration
/// ==========================================
/// This file configures the GoRouter navigation system and the Material theme
/// for the entire web admin portal. It defines:
///
/// 1. All routes (URL paths -> screen widgets)
/// 2. Authentication redirects (unauthenticated users go to login)
/// 3. The ShellRoute layout (sidebar + content area)
/// 4. Role-based route access (admin-only routes)
/// ==========================================

/// ==========================================
/// ROUTER PROVIDER - GoRouter Configuration
/// ==========================================
/// Defines the complete routing table for the web app.
///
/// Route structure:
/// - /web/login - Public login page
/// - /web/review - Public review page (no auth required)
/// - /web/* - Protected routes wrapped in WebShell (sidebar layout)
///
/// The redirect function handles:
/// - Unauthenticated users -> /web/login
/// - Already authenticated users on login page -> /web/dashboard
/// ==========================================
final webRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/web/login',
    routes: [
      // ==========================================
      // PUBLIC ROUTES (No authentication required)
      // ==========================================
      GoRoute(path: '/web/login', builder: (c, s) => const WebLoginScreen()),
      // Public review page - guests can leave reviews without logging in
      GoRoute(
        path: '/web/review',
        builder: (c, s) {
          final token = s.uri.queryParameters['token'] ?? '';
          return PublicReviewScreen(token: token);
        },
      ),

      // ==========================================
      // PROTECTED ROUTES (Wrapped in WebShell for sidebar layout)
      // ==========================================
      // ShellRoute wraps child routes in WebShell, which provides
      // the persistent sidebar navigation and top bar.
      ShellRoute(
        builder: (context, state, child) => WebShell(child: child),
        routes: [
          GoRoute(path: '/web', redirect: (_, _) => '/web/dashboard'),
          GoRoute(
            path: '/web/dashboard',
            builder: (c, s) => const WebDashboardScreen(),
          ),
          GoRoute(
            path: '/web/properties',
            builder: (c, s) => const WebPropertiesScreen(),
          ),
          GoRoute(
            path: '/web/bookings',
            builder: (c, s) => const WebBookingsScreen(),
          ),
          GoRoute(
            path: '/web/rooms',
            builder: (c, s) => const WebRoomsScreen(),
          ),
          GoRoute(
            path: '/web/tasks',
            builder: (c, s) => const WebTasksScreen(),
          ),
          GoRoute(
            path: '/web/payments',
            builder: (c, s) => const WebPaymentsScreen(),
          ),
          GoRoute(
            path: '/web/users',
            builder: (c, s) => const WebUsersScreen(),
          ),
          GoRoute(
            path: '/web/profile',
            builder: (c, s) {
              final tab = s.uri.queryParameters['tab'];
              return WebProfileScreen(initialTab: tab);
            },
          ),
          GoRoute(
            path: '/web/notifications',
            builder: (c, s) => const WebNotificationsScreen(),
          ),
          GoRoute(
            path: '/web/calendar',
            builder: (c, s) => const WebCalendarScreen(),
          ),
          GoRoute(
            path: '/web/feedback',
            builder: (c, s) => const WebFeedbackScreen(),
          ),
          GoRoute(
            path: '/web/audit-log',
            builder: (c, s) => const WebAuditLogScreen(),
          ),
        ],
      ),
    ],

    // ==========================================
    // REDIRECT LOGIC - Authentication Guards
    // ==========================================
    // Runs on every navigation to enforce authentication rules.
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.isAuthenticated;
      final isLogin = state.matchedLocation == '/web/login';
      final isPublicReview = state.matchedLocation == '/web/review';

      // Always allow the public review page
      if (isPublicReview) return null;
    },
  );
  return router;
});

/// ==========================================
/// WebApp - MaterialApp Root Widget
/// ==========================================
/// The root MaterialApp for the web admin portal.
/// Configures the theme, router, and global behavior.
/// ==========================================
class WebApp extends ConsumerWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(webRouterProvider);

    return MaterialApp.router(
      title: 'EaseInn Admin',
      debugShowCheckedModeBanner: false,

      // ==========================================
      // THEME CONFIGURATION
      // ==========================================
      // Green color scheme matching the hospitality brand
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5E20),
        useMaterial3: true,
        brightness: Brightness.light,
      ),

      // ==========================================
      // ROUTER CONFIGURATION
      // ==========================================
      // GoRouter handles URL-based navigation for Flutter Web
      routerConfig: router,
    );
  }
}
