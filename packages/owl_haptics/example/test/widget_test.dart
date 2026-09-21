import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owl_haptics_example/main.dart';

void main() {
  testWidgets('shows real-device haptic controls', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byKey(const ValueKey('status')), findsOneWidget);
    expect(find.text('Selection'), findsOneWidget);
    expect(find.text('Light impact'), findsOneWidget);
    expect(find.text('Medium impact'), findsOneWidget);
    expect(find.text('Heavy impact'), findsOneWidget);
    expect(find.text('Success outcome'), findsOneWidget);
    expect(find.text('Warning outcome'), findsOneWidget);
    expect(find.text('Error outcome'), findsOneWidget);
    expect(find.text('Six-pulse sequence'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
