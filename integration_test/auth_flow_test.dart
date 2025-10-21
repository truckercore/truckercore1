import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truckercore1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('My integration test', (WidgetTester tester) async {
    app.main(); // boot the app
    await tester.pumpAndSettle();

    // TODO: add actual assertions/user flows
    expect(find.byType(app.TruckerCoreApp), findsOneWidget);
  });
}
