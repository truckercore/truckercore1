import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../dashboards/driver/driver_dashboard.dart'
    show activeTripControllerProvider;
import '../../fleet/services/telemetry_service.dart';

abstract class TripRouteRepository {
  // Emits the current active trip polyline; empty if none.
  Stream<List<LatLng>> routePolyline();
}

class MockTripRouteRepository implements TripRouteRepository {
  MockTripRouteRepository(this._ref);
  final Ref _ref;

  @override
  Stream<List<LatLng>> routePolyline() async* {
    // Whenever active trip changes, re-emit a simple polyline based on latest telemetry
    final controller = StreamController<List<LatLng>>();
    Future<void> emitFromTelemetry() async {
      final telemetry = _ref.read(telemetryServiceProvider);
      final list = await telemetry.listCurrentPositions();
      if (list.isNotEmpty) {
        final p = list.first;
        controller.add([
          LatLng(p.lat, p.lng),
          LatLng(p.lat + 0.1, p.lng + 0.1),
        ]);
      } else {
        controller.add(const [LatLng(39.5, -98.35), LatLng(39.6, -98.25)]);
      }
    }

    // Initial
    await emitFromTelemetry();

    // Re-emit on active trip state change (start/end/resume)
    final remove = _ref.read(activeTripControllerProvider.notifier).addListener(
      (_) {
        emitFromTelemetry();
      },
    );

    controller.onCancel = () {
      // remove listener
      try {
        remove();
      } catch (_) {}
    };

    yield* controller.stream;
  }
}

final tripRouteRepositoryProvider = Provider<TripRouteRepository>((ref) {
  // Swap this with a real implementation later
  return MockTripRouteRepository(ref);
});

// Convenience provider to subscribe to polyline stream
final tripRouteStreamProvider = StreamProvider<List<LatLng>>((ref) {
  return ref.read(tripRouteRepositoryProvider).routePolyline();
});
