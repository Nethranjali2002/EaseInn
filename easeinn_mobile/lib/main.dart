import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'features/web/screens/web_app_stub.dart'
    if (dart.library.html) 'features/web/screens/web_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EaseInnRoot()));
}

class EaseInnRoot extends StatelessWidget {
  const EaseInnRoot({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebApp();
    }
    return const EaseInnApp();
  }
}
