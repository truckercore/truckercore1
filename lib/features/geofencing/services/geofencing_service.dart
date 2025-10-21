// lib/features/geofencing/services/geofence_service.dart
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeofenceEvent {
  final String truckId;
  final String geofenceName; // yard name or region
  final String event; // 'in' | 'out'
  final DateTime ts;
  final Duration? dwell; // if event is 'out', dwell duration since last 'in'

  const GeofenceEvent({
    required this.truckId,
    required this.geofenceName,
    required this.event,
    required this.ts,
    this.dwell,
  });
}

class GeofenceService {
  const GeofenceService(this._ref);
  // ignore: unused_field
  final Ref _ref;

  // MVP: synthetic events. Replace with Supabase query later:
  // select truck_id, geofence_id -> name, event, ts, dwell_seconds
  Future<List<GeofenceEvent>> recent({int take = 8}) async {
    final rng = Random(42);
    final now = DateTime.now().toUtc();

    final yards = [
      'Dallas Yard',
      'Denver Yard',
      'Nashville Yard',
      'Phoenix Yard',
    ];
    final trucks = ['TRK-1201', 'TRK-2310', 'TRK-4507', 'TRK-5520', 'TRK-6641'];

    final out = <GeofenceEvent>[];
    for (var i = 0; i < take; i++) {
      final t = trucks[rng.nextInt(trucks.length)];
      final y = yards[rng.nextInt(yards.length)];
      final enterTs = now.subtract(
        Duration(hours: rng.nextInt(72), minutes: rng.nextInt(59)),
      );
      final dwellHrs = 0.5 + rng.nextDouble() * 8; // 0.5..8.5h
      final leaveTs = enterTs.add(Duration(minutes: (dwellHrs * 60).round()));
      // Alternate showing IN or OUT entries
      if (rng.nextBool()) {
        out.add(
          GeofenceEvent(truckId: t, geofenceName: y, event: 'in', ts: enterTs),
        );
      } else {
        out.add(
          GeofenceEvent(
            truckId: t,
            geofenceName: y,
            event: 'out',
            ts: leaveTs,
            dwell: Duration(minutes: (dwellHrs * 60).round()),
          ),
        );
      }
    }

    // Sort newest first
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out;
  }
}

final geofenceServiceProvider = Provider<GeofenceService>(
  (ref) => GeofenceService(ref),
);
