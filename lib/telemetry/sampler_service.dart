// lib/telemetry/sampler_service.dart
// Adaptive GPS sampling and batching outline for wiring to events.gps.ingest
// Requires: geolocator in pubspec and appropriate platform permissions.

import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

enum SamplingMode { off, navigate, cruise, idle }

class SamplerService {
  final Future<void> Function(List<Map<String, dynamic>> batch) uploader;
  final Duration maxBatchAge;
  final int maxBatchSize;

  final _buffer = <Map<String, dynamic>>[];
  StreamSubscription<Position>? _sub;
  SamplingMode _mode = SamplingMode.idle;
  DateTime _lastFlush = DateTime.now();

  SamplerService({
    required this.uploader,
    this.maxBatchAge = const Duration(seconds: 45),
    this.maxBatchSize = 20,
  });

  SamplingMode get mode => _mode;

  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<void> start({required bool consentAlwaysOn}) async {
    final ok = await ensurePermission();
    if (!ok) return;
    _mode = consentAlwaysOn ? SamplingMode.idle : SamplingMode.off;
    _listen();
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void setNavigating(bool on) {
    final next = on ? SamplingMode.navigate : SamplingMode.cruise;
    if (next == _mode) return;
    _mode = next;
    _restart();
  }

  void setAlwaysOn(bool on) {
    final next = on ? SamplingMode.idle : SamplingMode.off;
    if (_mode == next) return;
    _mode = next;
    _restart();
  }

  void _restart() {
    _sub?.cancel();
    _listen();
  }

  void _listen() {
    final settings = _settingsFor(_mode);
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final sample = {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed_kph': (pos.speed) * 3.6,
        'heading_deg': pos.heading,
        'accuracy_m': pos.accuracy,
        'ts': DateTime.now().toUtc().toIso8601String(),
        'source': 'mobile',
      };
      _buffer.add(sample);
      _maybeFlush();
    });
  }

  LocationSettings _settingsFor(SamplingMode m) {
    switch (m) {
      case SamplingMode.navigate:
        return const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 25);
      case SamplingMode.cruise:
        return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 60);
      case SamplingMode.idle:
        return const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 120);
      case SamplingMode.off:
        return const LocationSettings(accuracy: LocationAccuracy.lowest, distanceFilter: 1000);
    }
  }

  Future<void> _maybeFlush() async {
    final now = DateTime.now();
    final age = now.difference(_lastFlush);
    if (_buffer.length >= maxBatchSize || age >= maxBatchAge) {
      final batch = List<Map<String, dynamic>>.from(_buffer);
      _buffer.clear();
      _lastFlush = now;
      try {
        await uploader(batch);
      } catch (_) {
        // best-effort: requeue small portion
        final head = batch.take(math.min(5, batch.length)).toList();
        _buffer.insertAll(0, head);
      }
    }
  }
}
