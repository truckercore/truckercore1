class Load {
  final String id;
  final String loadNumber;
  final String status;
  final String? driverId;
  final String? vehicleId;
  final LoadLocation pickupLocation;
  final LoadLocation deliveryLocation;
  final DateTime pickupDate;
  final DateTime deliveryDate;
  final double weight;
  final String commodity;
  final double rate;
  final double miles;
  final String? specialInstructions;
  final DateTime createdAt;

  const Load({
    required this.id,
    required this.loadNumber,
    required this.status,
    this.driverId,
    this.vehicleId,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.pickupDate,
    required this.deliveryDate,
    required this.weight,
    required this.commodity,
    required this.rate,
    required this.miles,
    this.specialInstructions,
    required this.createdAt,
  });

  factory Load.fromJson(Map<String, dynamic> json) => Load(
        id: json['id']?.toString() ?? '',
        loadNumber: json['load_number'] as String? ?? '',
        status: json['status'] as String? ?? 'available',
        driverId: json['driver_id']?.toString(),
        vehicleId: json['vehicle_id']?.toString(),
        pickupLocation: LoadLocation.fromJson(Map<String, dynamic>.from(json['pickup_location'] as Map)),
        deliveryLocation: LoadLocation.fromJson(Map<String, dynamic>.from(json['delivery_location'] as Map)),
        pickupDate: DateTime.parse(json['pickup_date'] as String),
        deliveryDate: DateTime.parse(json['delivery_date'] as String),
        weight: (json['weight'] as num).toDouble(),
        commodity: json['commodity'] as String? ?? '',
        rate: (json['rate'] as num).toDouble(),
        miles: (json['miles'] as num).toDouble(),
        specialInstructions: json['special_instructions'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}

class LoadLocation {
  final String name;
  final String address;
  final String city;
  final String state;
  final String zip;
  final double lat;
  final double lng;

  const LoadLocation({
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.lat,
    required this.lng,
  });

  factory LoadLocation.fromJson(Map<String, dynamic> json) => LoadLocation(
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        zip: json['zip'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'lat': lat,
        'lng': lng,
      };
}
