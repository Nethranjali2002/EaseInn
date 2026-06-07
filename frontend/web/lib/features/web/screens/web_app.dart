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

final webRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/web/login',
    routes: [
      GoRoute(path: '/web/login', builder: (c, s) => const WebLoginScreen()),
      // Public review route - accessible without authentication
      GoRoute(
        path: '/web/review',
        builder: (c, s) {
          final token = s.uri.queryParameters['token'] ?? '';
          return PublicReviewScreen(token: token);
        },
      ),
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
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.isAuthenticated;
      final isLogin = state.matchedLocation == '/web/login';
      final isPublicReview = state.matchedLocation == '/web/review';

      // Allow public review page without auth
      if (isPublicReview) return null;

      if (!isAuth && !isLogin) return '/web/login';
      if (isAuth && isLogin) return '/web/dashboard';
      return null;
    },
  );

  ref.listen<AuthState>(authProvider, (_, _) {
    router.refresh();
  });

  return router;
});

class WebApp extends ConsumerStatefulWidget {
  const WebApp({super.key});

  @override
  ConsumerState<WebApp> createState() => _WebAppState();
}

class _WebAppState extends ConsumerState<WebApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(authProvider.notifier)
        .tryAutoLogin()
        .timeout(const Duration(seconds: 3))
        .then((_) {
          if (mounted) setState(() => _initialized = true);
        })
        .catchError((_) {
          if (mounted) setState(() => _initialized = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(webRouterProvider);

    return MaterialApp.router(
      title: 'EaseInn Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1B5E20),
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Color(0xFF1B5E20), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ),
      routerConfig: router,
      builder: (context, child) {
        if (!_initialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
