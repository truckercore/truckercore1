import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/features/dashboards/driver_performance/driver_performance_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Driver Performance Dashboard', () {
    testWidgets('should render with mock data', (WidgetTester tester) async {
      // Provide a small set of mock drivers by overriding the provider
      final container = ProviderContainer(overrides: [
        driverMetricsProvider.overrideWithValue([
          DriverMetrics(
            driverId: 'd1',
            driverName: 'Alice Driver',
            safetyScore: 88,
            fuelEfficiency: 7.1,
            onTimeDeliveryPercent: 93,
            totalTrips: 150,
            totalMiles: 24000,
            hardBrakes: 2,
            rapidAccelerations: 1,
            speedingEvents: 0,
          ),
          DriverMetrics(
            driverId: 'd2',
            driverName: 'Bob Trucker',
            safetyScore: 80,
            fuelEfficiency: 6.8,
            onTimeDeliveryPercent: 90,
            totalTrips: 120,
            totalMiles: 21000,
            hardBrakes: 3,
            rapidAccelerations: 2,
            speedingEvents: 1,
          ),
        ]),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DriverPerformanceDashboard(),
        ),
      );

      // Allow first frame
      await tester.pumpAndSettle();

      // Expect header and some of the content
      expect(find.text('Performance Overview'), findsOneWidget);
      expect(find.text('Top 10 Leaderboard'), findsOneWidget);
      expect(find.text('Alice Driver'), findsOneWidget);
      expect(find.text('Bob Trucker'), findsOneWidget);
    });

    testWidgets('should handle empty data gracefully', (WidgetTester tester) async {
      final container = ProviderContainer(overrides: [
        driverMetricsProvider.overrideWithValue(const <DriverMetrics>[]),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DriverPerformanceDashboard(),
        ),
      );
      await tester.pumpAndSettle();

      // Expect the empty state UI
      expect(find.text('No driver data available'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  });
}
