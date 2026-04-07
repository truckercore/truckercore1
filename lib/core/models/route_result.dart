class RouteResult {
  final String routeId;
  final double distanceMiles;
  final int durationMinutes;
  final List<LatLng> polyline;
  final List<RouteRestriction> restrictions;
  final List<TrafficIncident> trafficIncidents;
  final List<WeatherAlert> weatherAlerts;
  final List<RouteWaypoint> waypoints;

  const RouteResult({
    required this.routeId,
    required this.distanceMiles,
    required this.durationMinutes,
    required this.polyline,
    required this.restrictions,
    required this.trafficIncidents,
    required this.weatherAlerts,
    required this.waypoints,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) => RouteResult(
        routeId: json['route_id'] as String,
        distanceMiles: (json['distance_miles'] as num).toDouble(),
        durationMinutes: json['duration_minutes'] as int,
        polyline: (json['polyline'] as List)
            .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
            .toList(),
        restrictions: (json['restrictions'] as List)
            .map((r) => RouteRestriction.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
        trafficIncidents: (json['traffic_incidents'] as List)
            .map((t) => TrafficIncident.fromJson(Map<String, dynamic>.from(t)))
            .toList(),
        weatherAlerts: (json['weather_alerts'] as List)
            .map((w) => WeatherAlert.fromJson(Map<String, dynamic>.from(w)))
            .toList(),
        waypoints: (json['waypoints'] as List)
            .map((w) => RouteWaypoint.fromJson(Map<String, dynamic>.from(w)))
            .toList(),
      );
}

class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class RouteRestriction {
  final String type; // 'low_clearance', 'weight_limit', 'truck_restricted'
  final double lat;
  final double lng;
  final String description;
  final String? limit;

  const RouteRestriction({
    required this.type,
    required this.lat,
    required this.lng,
    required this.description,
    this.limit,
  });

  factory RouteRestriction.fromJson(Map<String, dynamic> json) => RouteRestriction(
        type: json['type'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        description: json['description'] as String,
        limit: json['limit'] as String?,
      );
}

class RouteWaypoint {
  final double lat;
  final double lng;
  final String? name;

  const RouteWaypoint({required this.lat, required this.lng, this.name});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'name': name};

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) => RouteWaypoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        name: json['name'] as String?,
      );
}

class TrafficIncident {
  final String type;
  final double lat;
  final double lng;
  final String description;
  final int delayMinutes;

  const TrafficIncident({
    required this.type,
    required this.lat,
    required this.lng,
    required this.description,
    required this.delayMinutes,
  });

  factory TrafficIncident.fromJson(Map<String, dynamic> json) => TrafficIncident(
        type: json['type'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        description: json['description'] as String,
        delayMinutes: json['delay_minutes'] as int,
      );
}

class WeatherAlert {
  final String severity;
  final String type;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;

  const WeatherAlert({
    required this.severity,
    required this.type,
    required this.description,
    required this.startTime,
    this.endTime,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) => WeatherAlert(
        severity: json['severity'] as String,
        type: json['type'] as String,
        description: json['description'] as String,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      );
}

class RouteCalculationException implements Exception {
  final String message;
  RouteCalculationException(this.message);

  @override
  String toString() => message;
}
