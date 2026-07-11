import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hard_kapitalizm/main.dart';

void main() {
  testWidgets('App loads correctly smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HardKapitalizmApp()));

    expect(find.text('HARD'), findsOneWidget);
  });
}
