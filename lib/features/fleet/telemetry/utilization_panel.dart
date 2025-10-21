import 'package:flutter/material.dart';
import '../../../services/telemetry_service.dart';

class UtilizationPanel extends StatelessWidget {
  final TelemetryService svc;
  final String truckId;
  const UtilizationPanel({super.key, required this.svc, required this.truckId});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: svc.recentTruckMetrics(truckId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            );
          }
          final rows = snap.data!;
          final idleMin = rows.fold<num>(0, (a, r) => a + (r['idle'] ?? 0));
          final fuel = rows.fold<num>(0, (a, r) => a + (r['fuel'] ?? 0));
          return ListTile(
            leading: const Icon(Icons.local_shipping),
            title: Text('Last 24h: Idle ${idleMin}m • Fuel ${fuel}gal'),
            subtitle: Text('Samples: ${rows.length}'),
          );
        },
      ),
    );
  }
}
