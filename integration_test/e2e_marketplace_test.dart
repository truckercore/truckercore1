import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truckercore1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final bool configured = const String.fromEnvironment('SUPABASE_URL').isNotEmpty;

  testWidgets('E2E: Auth + post load + publish (smoke)', (tester) async {
    if (!configured) {
      print('SKIPPING e2e marketplace test: env not configured');
      return; // skip when not configured
    }
    app.main();
    await tester.pumpAndSettle();

    // TODO: Implement real auth and marketplace flows against a test project.
    expect(find.byType(app.TruckerCoreApp), findsOneWidget);
  });
}
