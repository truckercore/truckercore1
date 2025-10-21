// lib/features/gps/state/gps_map_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// App config holds environment/runtime configuration (including Mapbox token)
import '../../../common/config/app_config.dart';

/// Mapbox access token (public)
final mapboxTokenProvider = Provider<String>((ref) {
  final cfg = ref.watch(appConfigProvider);
  // Prefer the public token field name used in this project
  final token = cfg.mapboxToken;
  if (token.isEmpty) {
    throw StateError('Mapbox public token is not configured');
  }
  return token;
});

/// Initial map center
final mapCenterProvider = StateProvider<LatLng>((ref) {
  // USA centroid by default; adjust as needed
  return const LatLng(39.8283, -98.5795);
});

/// Initial/default zoom level
final mapZoomProvider = StateProvider<double>((ref) {
  return 3.5;
});
