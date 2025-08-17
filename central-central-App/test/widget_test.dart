// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:central_central_new/main.dart'; // This imports CentralCentralApp

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Use CentralCentralApp as defined in your main.dart
    await tester.pumpWidget(const CentralCentralApp()); // <--- CHANGED THIS LINE

    // Verify that our counter starts at 0.
    // NOTE: The default Flutter counter test expects a counter.
    // If your CentralCentralApp doesn't have a counter on its initial screen,
    // this test will likely fail. You might need to adjust the test
    // to match the actual UI of your LoginPage or create a more relevant test.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}