import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

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

  Future<void> _init() async {
    final auth = ref.read(authProvider.notifier);
    final isLoggedIn = await auth.tryAutoLogin();
    if (!mounted) return;
    if (isLoggedIn) {
      final user = ref.read(authProvider).user;
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
