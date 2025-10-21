import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:truckercore1/features/dashboards/models/dashboard_preferences.dart';
import 'package:truckercore1/features/dashboards/providers/dashboard_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardPreferencesNotifier', () {
    test('save and load preferences roundtrip', () async {
      // Start with empty mock storage
      SharedPreferences.setMockInitialValues({});

      final id = 'driver_performance';
      final notifier = DashboardPreferencesNotifier(id);

      // Update some values and save
      final prefs = DashboardPreferences(
        dashboardId: id,
        refreshIntervalSeconds: 5,
        alwaysOnTop: true,
        showNotifications: false,
      );
      await notifier.updatePreferences(id, prefs);

      // Recreate notifier to force load from file storage
      final notifier2 = DashboardPreferencesNotifier(id);
      // Wait a short tick for async load in constructor
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loaded = notifier2.getPreferences(id);
      expect(loaded.refreshIntervalSeconds, 5);
      expect(loaded.autoRefresh, true);
      expect(loaded.alwaysOnTop, true);
      expect(loaded.showNotifications, false);
    });
  });
}
