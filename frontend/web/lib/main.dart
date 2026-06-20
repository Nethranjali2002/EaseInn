import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/web/screens/web_app.dart';

/// ==========================================
/// EASEINN WEB ADMIN PORTAL - Entry Point
/// ==========================================
/// This is the main entry point for the EaseInn Web Admin Dashboard.
/// It's a Flutter Web application used by admins and managers to:
/// - Manage properties, rooms, and bookings
/// - Assign and track staff tasks
/// - View analytics and revenue reports
/// - Manage users and permissions
///
/// The app uses Riverpod for state management and GoRouter for navigation.
/// ==========================================
void main() {
  // Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();

  // ProviderScope wraps the entire app and manages all Riverpod providers.
  // It must be at the root of the widget tree.
  runApp(const ProviderScope(child: EaseInnAdminApp()));
}

/// ==========================================
/// ROOT WIDGET - EaseInn Admin App
/// ==========================================
/// The root widget of the web admin portal.
/// Delegates to WebApp which handles routing and theme configuration.
/// ==========================================
class EaseInnAdminApp extends StatelessWidget {
  const EaseInnAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebApp();
  }
}
