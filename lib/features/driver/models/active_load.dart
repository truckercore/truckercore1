class ActiveLoad {
  final String id;
  final String loadNumber;
  final String driverId;
  final String status;
  final String pickupLocation;
  final String deliveryLocation;
  final DateTime? pickupTime;
  final DateTime? deliveryTime;
  final DateTime? eta;

  ActiveLoad({
    required this.id,
    required this.loadNumber,
    required this.driverId,
    required this.status,
    required this.pickupLocation,
    required this.deliveryLocation,
    this.pickupTime,
    this.deliveryTime,
    this.eta,
  });

  factory ActiveLoad.fromJson(Map<String, dynamic> json) {
    return ActiveLoad(
      id: json['id'] as String,
      loadNumber: json['load_number'] as String,
      driverId: json['driver_id'] as String,
      status: json['status'] as String,
      pickupLocation: json['pickup_location'] as String,
      deliveryLocation: json['delivery_location'] as String,
      pickupTime: json['pickup_time'] != null
          ? DateTime.parse(json['pickup_time'] as String)
          : null,
      deliveryTime: json['delivery_time'] != null
          ? DateTime.parse(json['delivery_time'] as String)
          : null,
      eta: json['eta'] != null ? DateTime.parse(json['eta'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'load_number': loadNumber,
      'driver_id': driverId,
      'status': status,
      'pickup_location': pickupLocation,
      'delivery_location': deliveryLocation,
      'pickup_time': pickupTime?.toIso8601String(),
      'delivery_time': deliveryTime?.toIso8601String(),
      'eta': eta?.toIso8601String(),
    };
  }
}
