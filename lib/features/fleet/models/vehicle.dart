class Vehicle {
  final String id;
  final double latitude;
  final double longitude;
  final String? status;
  final String? currentDriver;

  const Vehicle({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.status,
    this.currentDriver,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String?,
      currentDriver: json['current_driver'] as String? ?? json['current_driver_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'current_driver': currentDriver,
      };
}
