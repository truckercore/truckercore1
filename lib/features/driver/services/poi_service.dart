import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/poi_models.dart';

final poiServiceProvider = Provider<POIService>((ref) {
  return POIService();
});

class POIService {
  /// Find nearby truck stops with real-time parking availability
  Future<List<TruckStop>> findNearbyTruckStops({
    required double lat,
    required double lng,
    double radiusMiles = 50,
    bool parkingAvailable = false,
  }) async {
    final response = await SupaClient.rpc('find_nearby_truck_stops', params: {
      'search_lat': lat,
      'search_lng': lng,
      'radius_miles': radiusMiles,
      'parking_only': parkingAvailable,
    });

    return (response as List).map((t) => TruckStop.fromJson(Map<String, dynamic>.from(t))).toList();
  }

  /// Get weigh station status (open/closed/bypassable)
  Future<List<WeighStation>> getWeighStations({
    required double lat,
    required double lng,
    double radiusMiles = 100,
  }) async {
    final response = await SupaClient.rpc('get_weigh_stations', params: {
      'search_lat': lat,
      'search_lng': lng,
      'radius_miles': radiusMiles,
    });

    return (response as List).map((w) => WeighStation.fromJson(Map<String, dynamic>.from(w))).toList();
  }

  /// Find fuel stations with current pricing
  Future<List<FuelStation>> findFuelStations({
    required double lat,
    required double lng,
    double radiusMiles = 25,
    String? fuelType,
  }) async {
    final response = await SupaClient.rpc('find_fuel_stations', params: {
      'search_lat': lat,
      'search_lng': lng,
      'radius_miles': radiusMiles,
      'fuel_type': fuelType,
    });

    return (response as List).map((f) => FuelStation.fromJson(Map<String, dynamic>.from(f))).toList();
  }

  /// Find rest areas for HOS compliance
  Future<List<RestArea>> findRestAreas({
    required double lat,
    required double lng,
    double radiusMiles = 50,
  }) async {
    final response = await SupaClient.rpc('find_rest_areas', params: {
      'search_lat': lat,
      'search_lng': lng,
      'radius_miles': radiusMiles,
    });

    return (response as List).map((r) => RestArea.fromJson(Map<String, dynamic>.from(r))).toList();
  }

  /// Get load-to-dock guidance with satellite imagery
  Future<DockGuidance> getDockGuidance({
    required String loadId,
    required double lat,
    required double lng,
  }) async {
    final response = await SupaClient.functions('get-dock-guidance', {
      'load_id': loadId,
      'destination_lat': lat,
      'destination_lng': lng,
    });

    return DockGuidance.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Stream real-time parking availability updates
  Stream<Map<String, int>> watchParkingAvailability(List<String> truckStopIds) {
    return SupaClient.stream(
      'truck_stop_parking',
      primaryKey: const ['truck_stop_id'],
      filter: (query) => query.in_('truck_stop_id', truckStopIds),
    ).map((data) {
      return Map.fromEntries(
        data.map((d) => MapEntry(
              d['truck_stop_id'].toString(),
              (d['available_spaces'] as num).toInt(),
            )),
      );
    });
  }
}
