import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owl_ads_gromore_example/main.dart';

void main() {
  testWidgets('missing real credentials are visible and block init', (
    tester,
  ) async {
    await tester.pumpWidget(const GroMoreExampleApp());

    expect(find.textContaining('Missing real credentials'), findsOneWidget);
    final initialize = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Initialize'),
    );
    expect(initialize.onPressed, isNull);
  });
}
