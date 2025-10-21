// Basic app smoke test for TruckerCoreApp.
// Ensures the app builds without throwing and the MaterialApp is present.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:truckercore1/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: TruckerCoreApp()),
    );

    // Verify that MaterialApp is in the widget tree.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
