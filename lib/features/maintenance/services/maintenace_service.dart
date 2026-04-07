// lib/features/maintenance/services/maintenance_service.dart
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Aggregated maintenance metrics per truck (MVP; replace with Supabase query later)
class MaintenanceSummary {
  final String truckId;
  final int events; // count of service events in window
  final int totalCostCents; // total spend in cents (window)
  final int last90DaysCents; // last 90 days spend
  final int ageYears; // truck age (approx)
  final bool underWarranty; // warranty flag
  final String suggestion; // 'Repair' | 'Replace Soon' | 'Monitor'
  final String rationale; // short explanation

  const MaintenanceSummary({
    required this.truckId,
    required this.events,
    required this.totalCostCents,
    required this.last90DaysCents,
    required this.ageYears,
    required this.underWarranty,
    required this.suggestion,
    required this.rationale,
  });
}

class MaintenanceService {
  const MaintenanceService(this._ref);
  // ignore: unused_field
  final Ref _ref;

  // MVP: Stable mock by truck id hash. Replace with real sums from maintenance_events later.
  Future<List<MaintenanceSummary>> topHighCost({int take = 5}) async {
    final trucks = <String>[
      'TRK-1201',
      'TRK-1202',
      'TRK-2310',
      'TRK-4507',
      'TRK-5520',
      'TRK-6641',
      'TRK-7789',
    ];
    final items = trucks.map(_mockFor).toList();
    // Sort by last 90 days cost desc
    items.sort((a, b) => b.last90DaysCents.compareTo(a.last90DaysCents));
    return items.take(take).toList();
  }

  MaintenanceSummary _mockFor(String truckId) {
    final rng = Random(truckId.hashCode);
    final events = 6 + rng.nextInt(12);
    final total =
        (20000 + rng.nextInt(120000)) *
        100; // lifetime-like window (placeholder)
    final recent = (2000 + rng.nextInt(22000)) * 100; // last 90d
    final age = 2 + rng.nextInt(8);
    final warranty = rng.nextBool() && age <= 3;

    // Heuristic: if recent spend > $10k and age > 6 → Replace Soon
    // if warranty true and recent spend > $4k → Repair (covered/discount potential)
    // else Monitor
    String suggestion;
    String rationale;
    if (recent > 10000 * 100 && age > 6) {
      suggestion = 'Replace Soon';
      rationale =
          'High 90-day spend and older truck; replacement may be cost-effective.';
    } else if (warranty && recent > 4000 * 100) {
      suggestion = 'Repair';
      rationale =
          'Under warranty and recent spend elevated; repairs likely covered/reduced.';
    } else if (recent > 8000 * 100) {
      suggestion = 'Repair';
      rationale = 'Recent spend is high; targeted repairs advised.';
    } else {
      suggestion = 'Monitor';
      rationale = 'Recent spend normal; monitor cost trends.';
    }

    return MaintenanceSummary(
      truckId: truckId,
      events: events,
      totalCostCents: total,
      last90DaysCents: recent,
      ageYears: age,
      underWarranty: warranty,
      suggestion: suggestion,
      rationale: rationale,
    );
  }
}

final maintenanceServiceProvider = Provider<MaintenanceService>(
  (ref) => MaintenanceService(ref),
);
