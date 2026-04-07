import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

final _distance = const Distance();

// Returns distance in miles between two coordinates.
double milesBetween(LatLng a, LatLng b) {
  final meters = _distance(a, b);
  return meters / 1609.344;
}

// Try to get current position; returns null if permission denied or unavailable.
Future<LatLng?> safeCurrentPosition() async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.denied ||
          req == LocationPermission.deniedForever) {
        return null;
      }
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}
