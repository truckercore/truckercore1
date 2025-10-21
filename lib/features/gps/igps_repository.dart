// lib/features/gps/igps_repository.dart
import 'dart:async';

/// Represents a single GPS fix with optional speed/heading/accuracy metadata.
class PositionFix {
  final double lat;
  final double lon;
  final double? speedMps;
  final double? headingDeg;
  final double? accuracyM;
  final DateTime ts;

  const PositionFix({
    required this.lat,
    required this.lon,
    this.speedMps,
    this.headingDeg,
    this.accuracyM,
    required this.ts,
  });
}

/// Basic sampling configuration for GPS streams.
class GpsConfig {
  final Duration interval;
  final double minDisplacementM;
  final double desiredAccuracyM; // lower is better
  const GpsConfig({
    this.interval = const Duration(seconds: 5),
    this.minDisplacementM = 5.0,
    this.desiredAccuracyM = 25.0,
  });
}

/// Platform permission states for foreground/background location.
enum GpsPermissionState {
  notDetermined,
  denied,
  foregroundGranted,
  backgroundGranted,
}

/// Contract for GPS repository implementations.
abstract class IGpsRepository {
  /// Stream position fixes with given configuration.
  Stream<PositionFix> watch({GpsConfig config = const GpsConfig()});

  /// Last known position, if available.
  Future<PositionFix?> lastKnown();

  /// Start continuous tracking (e.g., foreground service on Android).
  Future<void> startContinuous();

  /// Stop continuous tracking.
  Future<void> stopContinuous();
}
