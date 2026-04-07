class SecurityAlert {
  final String id;
  final String vehicleId;
  final String alertType;
  final double lat;
  final double lng;
  final String? details;
  final String severity;
  final DateTime triggeredAt;
  final bool acknowledged;

  const SecurityAlert({
    required this.id,
    required this.vehicleId,
    required this.alertType,
    required this.lat,
    required this.lng,
    this.details,
    required this.severity,
    required this.triggeredAt,
    this.acknowledged = false,
  });

  factory SecurityAlert.fromJson(Map<String, dynamic> json) => SecurityAlert(
        id: json['id'] as String,
        vehicleId: json['vehicle_id'] as String,
        alertType: json['alert_type'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        details: json['details'] as String?,
        severity: json['severity'] as String,
        triggeredAt: DateTime.parse(json['triggered_at'] as String),
        acknowledged: json['acknowledged'] as bool? ?? false,
      );
}

class SecurityIncident {
  final String id;
  final String vehicleId;
  final String incidentType;
  final String description;
  final DateTime occurredAt;
  final String status;

  const SecurityIncident({
    required this.id,
    required this.vehicleId,
    required this.incidentType,
    required this.description,
    required this.occurredAt,
    required this.status,
  });

  factory SecurityIncident.fromJson(Map<String, dynamic> json) => SecurityIncident(
        id: json['id'] as String,
        vehicleId: json['vehicle_id'] as String,
        incidentType: json['incident_type'] as String,
        description: json['description'] as String,
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        status: json['status'] as String,
      );
}
