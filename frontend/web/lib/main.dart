import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/web/screens/web_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EaseInnAdminApp()));
}

class EaseInnAdminApp extends StatelessWidget {
  const EaseInnAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebApp();
  }
}
