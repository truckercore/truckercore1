// lib/features/gps/mock_gps_repository.dart
import 'dart:async';
import 'dart:math' as math;

import 'igps_repository.dart';

/// A deterministic mock GPS repository that walks a small circle for demos/tests.
class MockGpsRepository implements IGpsRepository {
  final _controller = StreamController<PositionFix>.broadcast();
  Timer? _timer;
  PositionFix? _last;

  @override
  Stream<PositionFix> watch({GpsConfig config = const GpsConfig()}) {
    // Start a periodic timer if not running
    _timer ??= Timer.periodic(config.interval, (_) {
      final now = DateTime.now().toUtc();
      _last = _nextFix(now, config);
      // Accuracy filtering/jitter drop: skip if accuracy is too poor
      if ((_last!.accuracyM ?? 0) <= config.desiredAccuracyM) {
        _controller.add(_last!);
      }
    });
    return _controller.stream;
  }

  PositionFix _nextFix(DateTime ts, GpsConfig cfg) {
    // Center around a fixed point and move on a small circle with noise.
    const lat0 = 37.7749; // SF
    const lon0 = -122.4194;
    final t = ts.millisecondsSinceEpoch / 1000.0;
    final r = 0.0008; // ~90 m radius
    final lat = lat0 + r * math.sin(t / 30.0);
    final lon = lon0 + r * math.cos(t / 30.0);
    return PositionFix(
      lat: lat,
      lon: lon,
      speedMps: 5 + 2 * math.sin(t / 5.0),
      headingDeg: (t * 6) % 360, 
      accuracyM: 10.0,
      ts: ts,
    );
  }

  @override
  Future<PositionFix?> lastKnown() async => _last;

  @override
  Future<void> startContinuous() async {
    // No-op for mock; watch() starts the timer lazily.
  }

  @override
  Future<void> stopContinuous() async {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
