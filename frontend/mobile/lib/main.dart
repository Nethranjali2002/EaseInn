import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

/// ==========================================
/// EASEINN MOBILE STAFF APP - Entry Point
/// ==========================================
/// This is the main entry point for the EaseInn Mobile Staff App.
/// It's a Flutter mobile application used by staff members to:
/// - View and complete assigned tasks
/// - Upload completion photos
/// - Manage their profile
/// - View notifications
///
/// This app is STAFF-ONLY - admins and managers use the web portal.
/// Non-staff users are automatically logged out with an error message.
///
/// Uses Riverpod for state management and GoRouter for navigation.
/// ==========================================
void main() {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // ProviderScope wraps the entire app and manages all Riverpod providers.
  // It must be at the root of the widget tree.
  runApp(const ProviderScope(child: EaseInnStaffApp()));
}

/// ==========================================
/// ROOT WIDGET - EaseInn Staff App
/// ==========================================
/// The root widget of the mobile staff portal.
/// Delegates to EaseInnApp which handles routing and theme configuration.
/// ==========================================
class EaseInnStaffApp extends StatelessWidget {
  const EaseInnStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const EaseInnApp();
  }
}
