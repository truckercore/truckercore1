import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/services/loads_service.dart';
import '../compliance/compliance_alerts_service.dart';

class UnifiedAlert {
  final String id;
  final String title;
  final String message;
  final String kind; // compliance | weigh | delay | advisory
  final DateTime tsUtc;
  const UnifiedAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    required this.tsUtc,
  });
}

class AlertsFeedService {
  AlertsFeedService(this._ref);
  final Ref _ref;

  // Mock feed combining compliance alerts + delay alerts
  Stream<UnifiedAlert> streamOrgAlerts(String orgId) {
    final controller = StreamController<UnifiedAlert>.broadcast();

    // Compliance alerts stream
    final compSvc = _ref.read(complianceAlertsServiceProvider);
    final compSub = compSvc
        .routeAwareAlerts(
          audience: ComplianceAudience.fleetManager,
          route: const [], // global feed doesn’t depend on route here (mock)
          radiusMiles: 5,
        )
        .listen((a) {
          controller.add(
            UnifiedAlert(
              id: a.id,
              title: a.title,
              message: a.message,
              kind: a.type == ComplianceAlertType.weighStationOpen
                  ? 'weigh'
                  : 'compliance',
              tsUtc: DateTime.now().toUtc(),
            ),
          );
        });

    // Periodic delay checker (mock): every 60s
    Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final loads = await _ref.read(loadsServiceProvider).listLoads();
        final now = DateTime.now();
        for (final l in loads) {
          if (l.status == 'in_transit') {
            final etaLocal = l.dropoffAt; // using dropoff as mock ETA
            final lateMin = now.difference(etaLocal).inMinutes;
            if (lateMin > 15) {
              controller.add(
                UnifiedAlert(
                  id: 'delay_${l.id}_${now.millisecondsSinceEpoch}',
                  title: 'Delivery Delay',
                  message:
                      '${l.origin} → ${l.destination} is $lateMin min behind planned ETA',
                  kind: 'delay',
                  tsUtc: now.toUtc(),
                ),
              );
            }
          }
        }
      } catch (_) {}
    });

    controller.onCancel = () async {
      await compSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }
}

final alertsFeedServiceProvider = Provider<AlertsFeedService>(
  (ref) => AlertsFeedService(ref),
);
