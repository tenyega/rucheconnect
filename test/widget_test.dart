import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tp_flutter/main.dart';

void main() {
  testWidgets('RucheConnectée app loads successfully', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const MyApp());

    // Allow Flutter to settle animations and async UI
    await tester.pumpAndSettle();

    // Look for a key widget or text, e.g., App title or dashboard label
    expect(find.text('Ruchers'), findsOneWidget);

    // Optionally check presence of navigation or a button
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
