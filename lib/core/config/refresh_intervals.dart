// lib/core/config/refresh_intervals.dart
import 'dart:math';

class RefreshIntervals {
  // Base intervals for panels
  static const Duration marketplace = Duration(seconds: 30);
  static const Duration fleetKpis = Duration(seconds: 20);

  // Jitter ranges
  static const Duration marketplaceJitter = Duration(seconds: 5);
  static const Duration fleetKpisJitter = Duration(seconds: 4);

  static Duration withJitter(Duration base, Duration jitterRange) {
    if (jitterRange.inMilliseconds <= 0) return base;
    final r = Random();
    final jitterMs = r.nextInt(jitterRange.inMilliseconds + 1);
    return base + Duration(milliseconds: jitterMs);
  }
}
