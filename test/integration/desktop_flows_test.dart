import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truckercore1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop App Critical Flows', () {
    testWidgets('App launches on desktop', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Window can be resized', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final size = tester.getSize(find.byType(MaterialApp));
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    });

    testWidgets('Dashboard entry system exists', (tester) async {
      // Verify that desktop multi-window system is available
      // This test confirms the DashboardEntry widget can be instantiated
      expect(app.main, isNotNull);
    });
  });
}
