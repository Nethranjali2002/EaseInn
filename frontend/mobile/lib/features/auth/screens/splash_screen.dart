import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

/// ==========================================
/// SPLASH SCREEN - Initial App Loading
/// ==========================================
/// The first screen shown when the app launches. Its sole purpose is to:
/// 1. Display the EaseInn branding while the app initializes
/// 2. Check if the user has a stored access token (auto-login)
/// 3. Validate the token by fetching the user profile
/// 4. Redirect to the appropriate screen based on auth status:
///    - Valid token + staff role -> /tasks (main screen)
///    - Valid token + non-staff role -> logout + /login (mobile is staff-only)
///    - No token -> /login
///
/// This screen is shown briefly (1-2 seconds) during the auto-login check.
/// ==========================================
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  /// ==========================================
  /// AUTO-LOGIN CHECK
  /// ==========================================
  /// Attempts to auto-login using stored tokens.
  /// If successful and the user is staff, navigates to tasks.
  /// If the user is not staff, logs them out (mobile is staff-only).
  /// If no token exists, navigates to login.
  /// ==========================================
  Future<void> _init() async {
    final auth = ref.read(authProvider.notifier);
    final isLoggedIn = await auth.tryAutoLogin();
    if (!mounted) return;
    if (isLoggedIn) {
      final user = ref.read(authProvider).user;
      // ==========================================
      // ROLE ENFORCEMENT - Staff Only
      // ==========================================
      if (user?.role != 'staff') {
        await auth.logout();
        if (!mounted) return;
        context.go('/login');
      } else {
        context.go('/tasks');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple branded loading screen while auto-login check runs
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel, size: 80, color: Color(0xFF1B5E20)),
            SizedBox(height: 16),
            Text(
              'EaseInn',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Staff Portal',
              style: TextStyle(fontSize: 14, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
