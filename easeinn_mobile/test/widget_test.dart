import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easeinn_mobile/app.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EaseInnApp()));
    await tester.pumpAndSettle();
    expect(find.byType(EaseInnApp), findsOneWidget);
  });
}
