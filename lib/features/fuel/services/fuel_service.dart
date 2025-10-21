// lib/features/fuel/services/fuel_service.dart
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FuelAnomaly {
  final String truckId;
  final DateTime ts;
  final String type; // 'siphon_suspected' | 'mpg_outlier' | 'over_report'
  final String summary; // short description
  final String detail; // longer explanation
  final double severity; // 0..1 (1=critical)

  const FuelAnomaly({
    required this.truckId,
    required this.ts,
    required this.type,
    required this.summary,
    required this.detail,
    required this.severity,
  });
}

class FuelService {
  const FuelService(this._ref);
  // ignore: unused_field
  final Ref _ref;

  // MVP: synthetic anomalies by truck id hash
  Future<List<FuelAnomaly>> detect({int take = 6}) async {
    final trucks = <String>[
      'TRK-1201',
      'TRK-2310',
      'TRK-4507',
      'TRK-5520',
      'TRK-6641',
      'TRK-7789',
    ];
    final out = <FuelAnomaly>[];
    for (final t in trucks) {
      final a = _mockFor(t);
      out.addAll(a);
    }
    out.sort((a, b) => b.severity.compareTo(a.severity));
    return out.take(take).toList();
  }

  List<FuelAnomaly> _mockFor(String truckId) {
    final rng = Random(truckId.hashCode);
    final now = DateTime.now().toUtc();
    final anomalies = <FuelAnomaly>[];

    // chance of siphoning
    if (rng.nextDouble() < 0.35) {
      final sev = 0.7 + rng.nextDouble() * 0.3;
      anomalies.add(
        FuelAnomaly(
          truckId: truckId,
          ts: now.subtract(Duration(hours: rng.nextInt(72))),
          type: 'siphon_suspected',
          summary: 'Fuel drop without movement',
          detail:
              'Fuel level decreased by ~${10 + rng.nextInt(20)} gal while odometer unchanged.',
          severity: sev,
        ),
      );
    }
    // chance of mpg outlier
    if (rng.nextDouble() < 0.5) {
      final sev = 0.5 + rng.nextDouble() * 0.4;
      anomalies.add(
        FuelAnomaly(
          truckId: truckId,
          ts: now.subtract(Duration(hours: 12 + rng.nextInt(72))),
          type: 'mpg_outlier',
          summary: 'MPG outlier detected',
          detail:
              'Distance vs gallons indicates unusually low MPG on last segment.',
          severity: sev,
        ),
      );
    }
    // chance of over reporting
    if (rng.nextDouble() < 0.25) {
      final sev = 0.4 + rng.nextDouble() * 0.3;
      anomalies.add(
        FuelAnomaly(
          truckId: truckId,
          ts: now.subtract(Duration(days: rng.nextInt(5))),
          type: 'over_report',
          summary: 'Possible over-reported fueling',
          detail: 'Reported gallons exceed capacity or expected range.',
          severity: sev,
        ),
      );
    }

    return anomalies;
  }
}

final fuelServiceProvider = Provider<FuelService>((ref) => FuelService(ref));
