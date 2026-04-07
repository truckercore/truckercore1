import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle.dart';

/// Holds the current map viewport bounds
final viewportBoundsProvider = StateProvider<LatLngBounds?>((ref) => null);

/// Returns vehicles visible within the current viewport bounds (hard-limited for safety)
final visibleVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final bounds = ref.watch(viewportBoundsProvider);
  if (bounds == null) return [];

  final supabase = Supabase.instance.client;
  final data = await supabase
      .from('vehicles')
      .select('id, status, current_driver_id, latitude, longitude')
      .gte('latitude', bounds.southwest.latitude)
      .lte('latitude', bounds.northeast.latitude)
      .gte('longitude', bounds.southwest.longitude)
      .lte('longitude', bounds.northeast.longitude)
      .limit(1000);

  return (data as List<dynamic>)
      .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
      .toList();
});
