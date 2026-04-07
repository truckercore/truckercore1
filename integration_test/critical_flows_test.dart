import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truckercore1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Critical flows: app boots and renders main shell (mock mode)', (tester) async {
    // By default, USE_MOCK_DATA is true via AppConfig; this test assumes no backend.
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // App root should exist
    expect(find.byType(app.TruckerCoreApp), findsOneWidget);

    // Let first frame callbacks run and settle again
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Nothing else is asserted here to keep the test resilient across UI changes.
    // This acts as a boot smoke for CI and validates no top-level exceptions occur.
  });
}
