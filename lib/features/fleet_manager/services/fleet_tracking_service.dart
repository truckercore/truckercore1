import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/vehicle_models.dart' as vm;

final fleetTrackingServiceProvider = Provider<FleetTrackingService>((ref) {
  return FleetTrackingService();
});

final activeVehiclesProvider = StreamProvider<List<vm.VehicleStatus>>((ref) {
  final service = ref.watch(fleetTrackingServiceProvider);
  return service.watchActiveVehicles();
});

class FleetTrackingService {
  /// Watch real-time positions of all active vehicles
  Stream<List<vm.VehicleStatus>> watchActiveVehicles() {
    return SupaClient.stream(
      'vehicle_locations',
      primaryKey: const ['vehicle_id'],
      filter: (query) => query.eq('active', true),
    ).map((data) => data.map((v) => vm.VehicleStatus.fromJson(Map<String, dynamic>.from(v))).toList());
  }

  /// Get single vehicle details
  Future<vm.VehicleStatus> getVehicleStatus(String vehicleId) async {
    final response = await SupaClient.from('vehicle_locations')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .single();

    return vm.VehicleStatus.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Create geofence
  Future<String> createGeofence({
    required String name,
    required List<vm.LatLngFM> polygon,
    vm.GeofenceType type = vm.GeofenceType.customer,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await SupaClient.from('geofences')
        .insert({
          'name': name,
          'polygon': polygon.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
          'type': type.name,
          'metadata': metadata,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return (response as Map)['id']?.toString() ?? '';
  }

  /// Watch geofence events (entry/exit)
  Stream<vm.GeofenceEvent> watchGeofenceEvents() {
    return SupaClient.stream(
      'geofence_events',
      primaryKey: const ['id'],
      filter: (query) => query.order('created_at', ascending: false),
    ).map((data) => vm.GeofenceEvent.fromJson(Map<String, dynamic>.from(data.first)));
  }

  /// Get historical route playback data
  Future<List<vm.VehiclePosition>> getHistoricalRoute({
    required String vehicleId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final response = await SupaClient.from('vehicle_location_history')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .gte('timestamp', startTime.toIso8601String())
        .lte('timestamp', endTime.toIso8601String())
        .order('timestamp', ascending: true);

    return (response as List)
        .map((p) => vm.VehiclePosition.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  /// Get fleet overview statistics
  Future<vm.FleetOverview> getFleetOverview() async {
    final response = await SupaClient.rpc('get_fleet_overview');
    return vm.FleetOverview.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
