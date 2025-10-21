// lib/features/gps/gps_service.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// A simple mock that moves the "truck" along a short path near Denver.
class MockTruckPositions {
  static final List<LatLng> _route = [
    const LatLng(39.7392, -104.9903), // Denver
    const LatLng(39.75, -104.98),
    const LatLng(39.76, -104.97),
    const LatLng(39.77, -104.96),
    const LatLng(39.78, -104.95),
    const LatLng(39.79, -104.94),
    const LatLng(39.80, -104.93),
    const LatLng(39.81, -104.92),
    const LatLng(39.82, -104.91),
  ];

  Stream<LatLng> stream({
    Duration interval = const Duration(seconds: 1),
  }) async* {
    var i = 0;
    while (true) {
      yield _route[i % _route.length];
      i++;
      await Future.delayed(interval);
    }
  }
}

// Riverpod StreamProvider exposing the mock truck position stream.
final truckPositionStreamProvider = StreamProvider<LatLng>((ref) {
  final mock = MockTruckPositions();
  return mock.stream();
});
