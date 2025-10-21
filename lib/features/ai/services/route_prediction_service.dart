// lib/features/ai/services/route_prediction_service.dart
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/services/loads_service.dart';

class RoutePrediction {
  final String loadId;
  final String origin;
  final String destination;
  final DateTime pickupAt;
  final DateTime dropoffAt;
  final Duration eta; // predicted last-mile ETA from now
  final Duration slack; // time left until drop window
  final bool atRisk; // likely to be late
  final String rationale; // short explanation
  const RoutePrediction({
    required this.loadId,
    required this.origin,
    required this.destination,
    required this.pickupAt,
    required this.dropoffAt,
    required this.eta,
    required this.slack,
    required this.atRisk,
    required this.rationale,
  });
}

class RoutePredictionService {
  RoutePredictionService(this._ref);
  final Ref _ref;

  // MVP heuristic: assume distance bucket from text length, add traffic/weather factor.
  // Replace with: real distance (maps), traffic API, weather API, HOS hours remaining.
  Future<List<RoutePrediction>> getForecasts() async {
    final loads = await _ref.read(loadsServiceProvider).listLoads();
    final active = loads
        .where((l) => l.status != 'delivered' && l.status != 'canceled')
        .toList();

    final rng = Random(42);
    final now = DateTime.now().toUtc();

    final result = <RoutePrediction>[];
    for (final l in active) {
      // crude "distance" proxy (replace later with real geocoding distance)
      final pseudoMiles = 50 + (l.origin.length + l.destination.length) * 5;
      final baseHours = pseudoMiles / 50.0; // assume 50 mph avg
      // traffic/weather/random friction 0%..50%
      final friction = 0.0 + rng.nextDouble() * 0.5;
      final etaDuration = Duration(
        minutes: (baseHours * (1 + friction) * 60).round(),
      );

      // slack time until planned drop window from now
      final slack = l.dropoffAt.difference(now) - etaDuration;

      final atRisk = slack.inMinutes < 45; // threshold for "at risk"
      final rationale = atRisk
          ? 'Tight window: consider reroute (traffic/weather factor ${(friction * 100).toStringAsFixed(0)}%)'
          : 'On track (traffic/weather factor ${(friction * 100).toStringAsFixed(0)}%)';

      result.add(
        RoutePrediction(
          loadId: l.id,
          origin: l.origin,
          destination: l.destination,
          pickupAt: l.pickupAt,
          dropoffAt: l.dropoffAt,
          eta: etaDuration,
          slack: slack,
          atRisk: atRisk,
          rationale: rationale,
        ),
      );
    }

    // sort by risk first (at risk first), then by earliest drop time
    result.sort((a, b) {
      final r = (b.atRisk ? 1 : 0).compareTo(a.atRisk ? 1 : 0);
      if (r != 0) return r;
      return a.dropoffAt.compareTo(b.dropoffAt);
    });

    return result;
  }
}

final routePredictionServiceProvider = Provider<RoutePredictionService>(
  (ref) => RoutePredictionService(ref),
);
