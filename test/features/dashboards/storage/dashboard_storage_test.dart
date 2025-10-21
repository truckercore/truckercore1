import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truckercore1/features/dashboards/storage/dashboard_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardStorage (SharedPrefs)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('set/get string', () async {
      final storage = const SharedPrefsDashboardStorage();
      await storage.setString('k1', 'v1');
      final v = await storage.getString('k1');
      expect(v, 'v1');
    });

    test('set/get string list', () async {
      final storage = const SharedPrefsDashboardStorage();
      await storage.setStringList('list', ['a', 'b', 'c']);
      final v = await storage.getStringList('list');
      expect(v, isNotNull);
      expect(v!.length, 3);
      expect(v[0], 'a');
    });

    test('remove key', () async {
      final storage = const SharedPrefsDashboardStorage();
      await storage.setString('k2', 'x');
      await storage.remove('k2');
      final v = await storage.getString('k2');
      expect(v, isNull);
    });
  });
}
