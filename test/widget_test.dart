import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('HARD KAPITALIZM')),
        ),
      ),
    );

    expect(find.text('HARD KAPITALIZM'), findsOneWidget);
  });
}

