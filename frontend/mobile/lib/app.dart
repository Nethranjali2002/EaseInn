import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'router/app_router.dart';

/// ==========================================
/// EASEINN APP - MaterialApp Configuration
/// ==========================================
/// The root MaterialApp widget for the mobile staff app.
/// Configures:
/// - App title ("EaseInn Staff Portal")
/// - Theme (light/dark based on system preference)
/// - Router (GoRouter for URL-based navigation)
/// - Debug banner disabled for production look
///
/// Uses the shared AppTheme from the shared package for
/// consistent styling between web and mobile apps.
/// ==========================================
class EaseInnApp extends ConsumerWidget {
  const EaseInnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the router provider to rebuild when auth state changes
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'EaseInn Staff Portal',
      debugShowCheckedModeBanner: false,

      // ==========================================
      // THEME CONFIGURATION
      // ==========================================
      // Uses shared AppTheme for consistent styling.
      // ThemeMode.system automatically switches between light/dark
      // based on the device's system settings.
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // GoRouter handles URL-based navigation for the mobile app
      routerConfig: router,
    );
  }
}
