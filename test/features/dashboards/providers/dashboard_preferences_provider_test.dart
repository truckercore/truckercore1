import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/dashboards/providers/dashboard_preferences_provider.dart';

void main() {
  group('DashboardPreferencesNotifier', () {
    test('initializes with default preferences', () {
      final notifier = DashboardPreferencesNotifier('test-dashboard');

      expect(notifier.state.dashboardId, 'test-dashboard');
      expect(notifier.state.autoRefresh, true);
      expect(notifier.state.refreshIntervalSeconds, 30);
    });

    test('updates auto refresh setting', () {
      final notifier = DashboardPreferencesNotifier('test-dashboard');

      notifier.setAutoRefresh(false);

      expect(notifier.state.autoRefresh, false);
    });
  });
}
