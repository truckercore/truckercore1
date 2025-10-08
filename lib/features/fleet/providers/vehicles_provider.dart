import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle.dart';

/// Fetch up to 5000 active vehicles with coordinates for clustering
final allVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final supabase = Supabase.instance.client;
  final data = await supabase
      .from('vehicles')
      .select('id, status, current_driver_id, latitude, longitude')
      .eq('status', 'active')
      .limit(5000);

  return (data as List<dynamic>)
      .where((row) => row['latitude'] != null && row['longitude'] != null)
      .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
      .toList();
});
