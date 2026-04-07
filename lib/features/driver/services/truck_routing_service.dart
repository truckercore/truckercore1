import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/route_result.dart';
import '../../../core/models/traffic_update.dart';
import '../../../core/models/vehicle_dimensions.dart';
import '../../../services/supa_client.dart';

final truckRoutingServiceProvider = Provider<TruckRoutingService>((ref) {
  return TruckRoutingService();
});

class TruckRoutingService {
  /// Calculate truck-safe route considering vehicle dimensions and restrictions
  Future<RouteResult> calculateRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required VehicleDimensions dimensions,
    List<RouteWaypoint>? viaPoints,
    List<String>? avoidTypes,
    bool includeTraffic = true,
    bool includeWeather = true,
  }) async {
    try {
      final response = await SupaClient.functions('calculate-truck-route', {
        'start': {'lat': startLat, 'lng': startLng},
        'end': {'lat': endLat, 'lng': endLng},
        'dimensions': dimensions.toJson(),
        'via': viaPoints?.map((w) => w.toJson()).toList(),
        'avoid': avoidTypes,
        'include_traffic': includeTraffic,
        'include_weather': includeWeather,
      });

      return RouteResult.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw RouteCalculationException('Failed to calculate route: $e');
    }
  }

  /// Check route restrictions against vehicle profile
  Future<List<RouteRestriction>> checkRestrictions({
    required String routeId,
    required VehicleDimensions dimensions,
  }) async {
    final response = await SupaClient.functions('check-route-restrictions', {
      'route_id': routeId,
      'dimensions': dimensions.toJson(),
    });

    final map = Map<String, dynamic>.from(response.data as Map);
    return (map['restrictions'] as List)
        .map((r) => RouteRestriction.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Get real-time traffic updates for active route
  Stream<TrafficUpdate> watchTrafficUpdates(String routeId) {
    return SupaClient.stream(
      'traffic_updates',
      primaryKey: const ['id'],
      filter: (query) => query.eq('route_id', routeId),
    ).map((data) => TrafficUpdate.fromJson(Map<String, dynamic>.from(data.first)));
  }

  /// Get weather alerts along route
  Future<List<WeatherAlert>> getWeatherAlerts({
    required List<LatLng> routePoints,
  }) async {
    final response = await SupaClient.functions('get-weather-alerts', {
      'route_points': routePoints.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
    });

    final map = Map<String, dynamic>.from(response.data as Map);
    return (map['alerts'] as List)
        .map((a) => WeatherAlert.fromJson(Map<String, dynamic>.from(a)))
        .toList();
  }
}
