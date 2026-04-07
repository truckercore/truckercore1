class LatLngFM {
  final double lat;
  final double lng;
  const LatLngFM(this.lat, this.lng);

  factory LatLngFM.fromJson(Map<String, dynamic> json) => LatLngFM(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

enum GeofenceType { customer, yard, restricted }

class VehicleStatus {
  final String vehicleId;
  final double lat;
  final double lng;
  final bool active;
  final DateTime? updatedAt;

  VehicleStatus({
    required this.vehicleId,
    required this.lat,
    required this.lng,
    required this.active,
    this.updatedAt,
  });

  factory VehicleStatus.fromJson(Map<String, dynamic> json) => VehicleStatus(
        vehicleId: json['vehicle_id']?.toString() ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        active: json['active'] as bool? ?? true,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      );
}

class Geofence {
  final String id;
  final String name;
  final List<LatLngFM> polygon;
  final GeofenceType type;
  final Map<String, dynamic>? metadata;

  Geofence({
    required this.id,
    required this.name,
    required this.polygon,
    required this.type,
    this.metadata,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) => Geofence(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        polygon: (json['polygon'] as List?)?.map((p) => LatLngFM.fromJson(Map<String, dynamic>.from(p))).toList() ?? const [],
        type: GeofenceType.values.firstWhere(
          (e) => e.name == (json['type'] as String? ?? 'customer'),
          orElse: () => GeofenceType.customer,
        ),
        metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : null,
      );
}

class GeofenceEvent {
  final String id;
  final String geofenceId;
  final String vehicleId;
  final String eventType; // entry/exit
  final DateTime createdAt;

  GeofenceEvent({
    required this.id,
    required this.geofenceId,
    required this.vehicleId,
    required this.eventType,
    required this.createdAt,
  });

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) => GeofenceEvent(
        id: json['id']?.toString() ?? '',
        geofenceId: json['geofence_id']?.toString() ?? '',
        vehicleId: json['vehicle_id']?.toString() ?? '',
        eventType: json['event_type'] as String? ?? 'entry',
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class VehiclePosition {
  final String vehicleId;
  final double lat;
  final double lng;
  final DateTime timestamp;

  VehiclePosition({
    required this.vehicleId,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  factory VehiclePosition.fromJson(Map<String, dynamic> json) => VehiclePosition(
        vehicleId: json['vehicle_id']?.toString() ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class FleetOverview {
  final int activeVehicles;
  final int idleVehicles;
  final int inService;
  final int outOfService;

  FleetOverview({
    required this.activeVehicles,
    required this.idleVehicles,
    required this.inService,
    required this.outOfService,
  });

  factory FleetOverview.fromJson(Map<String, dynamic> json) => FleetOverview(
        activeVehicles: (json['active_vehicles'] as num?)?.toInt() ?? 0,
        idleVehicles: (json['idle_vehicles'] as num?)?.toInt() ?? 0,
        inService: (json['in_service'] as num?)?.toInt() ?? 0,
        outOfService: (json['out_of_service'] as num?)?.toInt() ?? 0,
      );
}
