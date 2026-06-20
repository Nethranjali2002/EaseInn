/// Fallback stub screen shown when the web admin panel is accessed on non-web platforms.
///
/// This screen exists as a safety net — the web admin panel is designed exclusively
/// for desktop browsers. If a user somehow reaches this screen on mobile or desktop
/// native, they see this message instead of a crash.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub widget that displays a platform warning message.
class WebApp extends ConsumerWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Web admin panel is only available on the web platform.'),
        ),
      ),
    );
  }
}
