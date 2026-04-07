import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// Severity levels for compliance alerts
enum ComplianceSeverity { info, warning, critical }

// Types of compliance alerts we may emit
enum ComplianceAlertType {
  weighStationOpen,
  restrictedRoute,
  lowClearance,
  general,
}

// Audience for alerts (driver, fleet manager, etc.)
enum ComplianceAudience { driver, fleetManager }

class ComplianceAlert {
  final String id;
  final String title;
  final String message;
  final ComplianceSeverity severity;
  final ComplianceAlertType type;
  final DateTime createdAt;

  const ComplianceAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.type,
    required this.createdAt,
  });
}

abstract class ComplianceAlertsService {
  Stream<ComplianceAlert> routeAwareAlerts({
    required ComplianceAudience audience,
    required List<LatLng> route,
    required double radiusMiles,
  });
}

class MockComplianceAlertsService implements ComplianceAlertsService {
  @override
  Stream<ComplianceAlert> routeAwareAlerts({
    required ComplianceAudience audience,
    required List<LatLng> route,
    required double radiusMiles,
  }) {
    // Simple mock: emits an alternating sequence of alert types every few seconds
    final controller = StreamController<ComplianceAlert>();
    int i = 0;
    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 6), (_) {
      final now = DateTime.now();
      final idx = i++ % 3;
      switch (idx) {
        case 0:
          controller.add(
            ComplianceAlert(
              id: 'ws-${now.millisecondsSinceEpoch}',
              title: 'Weigh station ahead — reported OPEN',
              message:
                  'Next station along route is open. Ensure logs and docs are ready.',
              severity: ComplianceSeverity.info,
              type: ComplianceAlertType.weighStationOpen,
              createdAt: now,
            ),
          );
          break;
        case 1:
          controller.add(
            ComplianceAlert(
              id: 'rest-${now.millisecondsSinceEpoch}',
              title: 'Restricted segment on planned route',
              message:
                  'Hazmat restriction flagged near mile 14. Consider alternate.',
              severity: ComplianceSeverity.warning,
              type: ComplianceAlertType.restrictedRoute,
              createdAt: now,
            ),
          );
          break;
        default:
          controller.add(
            ComplianceAlert(
              id: 'lowclr-${now.millisecondsSinceEpoch}',
              title: 'Low clearance reported nearby',
              message:
                  '12\'6" clearance on upcoming segment. Verify route suitability.',
              severity: ComplianceSeverity.critical,
              type: ComplianceAlertType.lowClearance,
              createdAt: now,
            ),
          );
      }
    });

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }
}

final complianceAlertsServiceProvider = Provider<ComplianceAlertsService>((
  ref,
) {
  // Replace with a real implementation later
  return MockComplianceAlertsService();
});
