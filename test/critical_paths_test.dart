import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/core/dashboards/dashboard_entry.dart';
import 'package:truckercore1/features/connectivity/connectivity_provider.dart' as conn; // pure helper
import 'package:truckercore1/features/fleet/widgets/optimized_fleet_map.dart' as maphelpers;
import 'package:truckercore1/features/reports/services/report_service.dart';
import 'package:truckercore1/src/routing/app_router.dart' as minimal_router;
import 'helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App startup & router', () {
    test('buildAppRouter returns a GoRouter', () {
      final r = minimal_router.buildAppRouter(supabaseReady: false);
      expect(r, isNotNull);
    });

    testWidgets('AppRouterRoot builds without throwing', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: minimal_router.AppRouterRoot()));
      await tester.pump();
      expect(find.byType(minimal_router.AppRouterRoot), findsOneWidget);
    });
  });

  group('Dashboard rendering (multi-window)', () {
    testWidgets('Unknown dashboard renders fallback UI', (tester) async {
      final w = dashboardEntryForTest({'dashboardId': 'does_not_exist'});
      await tester.pumpWidget(w);
      await tester.pump();
      expect(find.textContaining('Unknown Dashboard'), findsOneWidget);
    });
  });

  group('Fleet map visualization helpers', () {
    test('clusterSizeForCount thresholds', () {
      expect(maphelpers.clusterSizeForCount(0), 0.8);
      expect(maphelpers.clusterSizeForCount(50), 1.0);
      expect(maphelpers.clusterSizeForCount(500), 1.2);
      expect(maphelpers.clusterSizeForCount(5000), 1.5);
    });

    test('vehicleIconForStatus mapping', () {
      expect(maphelpers.vehicleIconForStatus('active'), 'vehicle-active');
      expect(maphelpers.vehicleIconForStatus('idle'), 'vehicle-idle');
      expect(maphelpers.vehicleIconForStatus('maintenance'), 'vehicle-maintenance');
      expect(maphelpers.vehicleIconForStatus(null), 'vehicle-default');
      expect(maphelpers.vehicleIconForStatus('other'), 'vehicle-default');
    });
  });

  group('Report generation (Icons usage)', () {
    test('ReportService templates contain icons and entries', () {
      final svc = ReportService();
      final templates = svc.getReportTemplates();
      expect(templates, isNotEmpty);
      for (final t in templates) {
        expect(t.icon, isA<IconData>());
      }
    });
  });

  group('Connectivity detection', () {
    test('isOnlineFromResults helper interprets connectivity', () {
      expect(conn.isOnlineFromResults([ConnectivityResult.wifi]), isTrue);
      expect(conn.isOnlineFromResults([ConnectivityResult.none]), isFalse);
      expect(conn.isOnlineFromResults([ConnectivityResult.mobile, ConnectivityResult.wifi]), isTrue);
      expect(conn.isOnlineFromResults([ConnectivityResult.ethernet, ConnectivityResult.none]), isFalse);
    });
  });
}
