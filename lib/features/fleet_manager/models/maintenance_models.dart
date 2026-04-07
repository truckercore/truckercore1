class MaintenanceAlert {
  final String id;
  final String vehicleId;
  final String severity; // low/medium/high/critical
  final String message;
  final bool resolved;
  final DateTime createdAt;

  MaintenanceAlert({
    required this.id,
    required this.vehicleId,
    required this.severity,
    required this.message,
    required this.resolved,
    required this.createdAt,
  });

  factory MaintenanceAlert.fromJson(Map<String, dynamic> json) => MaintenanceAlert(
        id: json['id']?.toString() ?? '',
        vehicleId: json['vehicle_id']?.toString() ?? '',
        severity: json['severity']?.toString() ?? 'low',
        message: json['message']?.toString() ?? '',
        resolved: json['resolved'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class MaintenanceRecord {
  final String id;
  final String vehicleId;
  final String maintenanceType;
  final int odometerReading;
  final double cost;
  final String? notes;
  final List<String>? invoiceUrls;
  final DateTime completedAt;

  MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.maintenanceType,
    required this.odometerReading,
    required this.cost,
    this.notes,
    this.invoiceUrls,
    required this.completedAt,
  });

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) => MaintenanceRecord(
        id: json['id']?.toString() ?? '',
        vehicleId: json['vehicle_id']?.toString() ?? '',
        maintenanceType: json['maintenance_type']?.toString() ?? '',
        odometerReading: (json['odometer_reading'] as num?)?.toInt() ?? 0,
        cost: (json['cost'] as num?)?.toDouble() ?? 0,
        notes: json['notes']?.toString(),
        invoiceUrls: (json['invoice_urls'] as List?)?.map((e) => e.toString()).toList(),
        completedAt: DateTime.parse(json['completed_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class VehicleDiagnostics {
  final String vehicleId;
  final Map<String, dynamic> sensors; // generic diagnostics payload

  VehicleDiagnostics({
    required this.vehicleId,
    required this.sensors,
  });

  factory VehicleDiagnostics.fromJson(Map<String, dynamic> json) => VehicleDiagnostics(
        vehicleId: json['vehicle_id']?.toString() ?? '',
        sensors: json['sensors'] is Map ? Map<String, dynamic>.from(json['sensors']) : <String, dynamic>{},
      );
}
