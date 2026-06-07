import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EaseInnStaffApp()));
}

class EaseInnStaffApp extends StatelessWidget {
  const EaseInnStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const EaseInnApp();
  }
}
