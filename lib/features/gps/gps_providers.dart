/// GPS providers and derived streams for location processing.
library;

// Group 1: dart imports
import 'dart:math' as math;

// Group 2: package imports
import 'package:flutter/widgets.dart' show AppLifecycleState; // replaces dart:ui
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Group 3: relative imports
import '../../core/refresh/refresh_orchestrator.dart';
import 'igps_repository.dart';
import 'mock_gps_repository.dart';

/// Whether the user enabled continuous tracking (background). In a real app,
/// this should come from persistent settings. Defaults to false.
final continuousTrackingEnabledProvider = StateProvider<bool>((ref) => false);

/// Expose current GPS permission state. This is a placeholder that models a
/// minimal foreground/background flow; integrate real platform permission
/// checks (e.g., geolocator) in a production implementation.
final gpsPermissionStateProvider = StateProvider<GpsPermissionState>((ref) {
  final continuous = ref.watch(continuousTrackingEnabledProvider);
  // In this placeholder we assume foreground is granted in dev mode; background
  // requires the toggle. Production should inspect platform permission APIs.
  return continuous
      ? GpsPermissionState.backgroundGranted
      : GpsPermissionState.foregroundGranted;
});

/// Provide an implementation of IGpsRepository based on app configuration.
final gpsRepositoryProvider = Provider<IGpsRepository>((ref) {
  // For now we only wire the mock repo to avoid adding heavy deps.
  // A real GeolocatorGpsRepository can be wired here when available.
  return MockGpsRepository();
});

/// A derived stream that applies accuracy filtering, displacement drop, and
/// throttling when the app is backgrounded.
final filteredGpsStreamProvider = StreamProvider.autoDispose<PositionFix>((ref) {
  final repo = ref.watch(gpsRepositoryProvider);
  final lifecycle = ref.watch(appLifecycleStateProvider);

  // Throttle more aggressively when in background to save battery.
  final interval = lifecycle == AppLifecycleState.paused ||
          lifecycle == AppLifecycleState.inactive ||
          lifecycle == AppLifecycleState.detached
      ? const Duration(seconds: 20)
      : const Duration(seconds: 5);

  // Fetch desired accuracy from config if available; otherwise default.
  const desiredAccuracyM = 25.0;

  final stream = repo.watch(
    config: GpsConfig(
      interval: interval,
    ),
  );

  // Debounce small jitter and drop poor accuracy.
  PositionFix? last;
  double distanceM(PositionFix a, PositionFix b) {
    const earthR = 6371000.0;
    final dLat = _deg2rad(b.lat - a.lat);
    final dLon = _deg2rad(b.lon - a.lon);
    final la1 = _deg2rad(a.lat);
    final la2 = _deg2rad(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthR * c;
  }

  return stream.where((fix) {
    // Drop poor accuracy
    if ((fix.accuracyM ?? 9999) > desiredAccuracyM) return false;
    if (last == null) {
      last = fix;
      return true;
    }
    final d = distanceM(last!, fix);
    if (d < 3.0) {
      // jitter below 3 m: drop
      return false;
    }
    last = fix;
    return true;
  });
});

double _deg2rad(double deg) => deg * (math.pi / 180.0);
