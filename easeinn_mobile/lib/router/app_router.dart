import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_provider.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/change_password_screen.dart';
import '../features/task/screens/staff_task_screen.dart';
import '../features/profile/screens/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: '/change-password', builder: (c, s) => const ChangePasswordScreen()),

      GoRoute(path: '/tasks', builder: (c, s) => const StaffTaskScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
    ],
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuthenticated = auth.isAuthenticated;
      final publicRoutes = ['/login', '/register', '/forgot-password', '/splash'];
      final isPublicRoute = publicRoutes.contains(state.matchedLocation);

      if (state.matchedLocation == '/splash') return null;

      if (isAuthenticated && auth.user?.role != 'staff') {
        ref.read(authProvider.notifier).logout();
        return '/login';
      }

      if (!isAuthenticated && !isPublicRoute) return '/login';
      if (isAuthenticated && state.matchedLocation == '/login') return '/tasks';
      return null;
    },
  );

  ref.listen<AuthState>(authProvider, (_, __) {
    router.refresh();
  });

  return router;
});
