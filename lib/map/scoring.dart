// lib/map/scoring.dart
// Scoring utilities for StopPin, matching the provided outline.

import 'stop_pin.dart';

// Blend weights
const double wParking = 0.35;
const double wFuel = 0.25;
const double wLoyalty = 0.15;
const double wAmen = 0.15;
const double wDist = 0.10;
const double wConf = 0.10;

// Local copies of normalizers to avoid exposing private ones from stop_pin.dart

double parkingScore(String occ) => switch (occ) {
      'open' => 1.0,
      'some' => 0.6,
      'full' => 0.1,
      _ => 0.4,
    };

double fuelNorm(int? cents) => cents == null ? 0 : (cents.clamp(0, 20) / 20.0);

double distNorm(double mi) => 1.0 / (1.0 + 0.2 * mi);

double computeScore(StopPin s) {
  return wParking * parkingScore(s.occupancy) +
      wFuel * fuelNorm(s.fuelDiscountCents) +
      wLoyalty * s.loyalty +
      wAmen * s.amenities +
      wDist * distNorm(s.distanceMi) +
      wConf * s.confidence;
}

StopPin pickRep(List<StopPin> pins) {
  final sorted = [...pins]..sort((a, b) => computeScore(b).compareTo(computeScore(a)));
  return sorted.first;
}
