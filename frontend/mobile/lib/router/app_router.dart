import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/change_password_screen.dart';
import '../features/task/screens/staff_task_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/notification/screens/mobile_notifications_screen.dart';

/// ==========================================
/// MOBILE APP ROUTER - Navigation Configuration
/// ==========================================
/// Defines all routes and navigation guards for the mobile staff app.
///
/// Route structure:
/// - /splash - Initial loading screen (checks for existing session)
/// - /login, /register, /forgot-password - Auth screens (public)
/// - /tasks - Main task list (staff home screen)
/// - /profile - User profile management
/// - /notifications - Notification list
/// - /change-password - Password change screen
///
/// AUTH GUARDS:
/// - Unauthenticated users -> redirected to /login
/// - Non-staff users -> logged out and redirected to /login
/// - Authenticated users on /login -> redirected to /tasks
/// ==========================================
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // ==========================================
      // AUTH FLOW ROUTES
      // ==========================================
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (c, s) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (c, s) => const ChangePasswordScreen(),
      ),

      // ==========================================
      // MAIN APP ROUTES (Protected)
      // ==========================================
      GoRoute(path: '/tasks', builder: (c, s) => const StaffTaskScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/notifications', builder: (c, s) => const MobileNotificationsScreen()),
    ],

    // ==========================================
    // REDIRECT LOGIC - Authentication & Role Guards
    // ==========================================
    // Enforces three rules:
    // 1. Allow splash screen to handle initial auth check
    // 2. Non-staff users are logged out (mobile is staff-only)
    // 3. Unauthenticated users can only access public routes
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuthenticated = auth.isAuthenticated;
      final publicRoutes = [
        '/login',
        '/register',
        '/forgot-password',
        '/splash',
      ];
      final isPublicRoute = publicRoutes.contains(state.matchedLocation);

      // Always allow splash screen
      if (state.matchedLocation == '/splash') return null;

      // ==========================================
      // ROLE ENFORCEMENT - Staff Only
      // ==========================================
      // The mobile app is exclusively for staff members.
      // Admins and managers must use the web portal.
      if (isAuthenticated && auth.user?.role != 'staff') {
        ref.read(authProvider.notifier).logout();
        return '/login';
      }

      // ==========================================
      // AUTH GUARDS
      // ==========================================
      // Redirect unauthenticated users to login
      if (!isAuthenticated && !isPublicRoute) return '/login';
      // Redirect authenticated users away from login screen
      if (isAuthenticated && state.matchedLocation == '/login') return '/tasks';
      return null;
    },
  );

  // ==========================================
  // ROUTE REFRESH ON AUTH CHANGE
  // ==========================================
  // Listen for auth state changes and refresh the router.
  // This ensures navigation guards re-evaluate when the user
  // logs in or out.
  ref.listen<AuthState>(authProvider, (_, _) {
    router.refresh();
  });

  return router;
});
