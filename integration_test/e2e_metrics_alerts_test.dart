import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truckercore1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final bool configured = const String.fromEnvironment('SUPABASE_URL').isNotEmpty;

  testWidgets('E2E: ROI/Detention panel + metrics_events write + alerts ack (smoke)', (tester) async {
    if (!configured) {
      print('SKIPPING e2e metrics/alerts test: env not configured');
      return; // skip when not configured
    }
    app.main();
    await tester.pumpAndSettle();

    // TODO: Fetch ROI/Detention panels and trigger a metrics write path.
    // TODO: Emit a sample alert and hit the ack route (admin cookie/session needed).

    expect(find.byType(app.TruckerCoreApp), findsOneWidget);
  });
}
