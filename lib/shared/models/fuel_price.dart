/// Minimal FuelPrice model stub to align with TruckerCore shared package sketch.
class FuelPrice {
  final String locationId;
  final String fuelType; // e.g., "diesel", "unleaded"
  final double pricePerGallon;
  final DateTime updatedAt;

  const FuelPrice({
    required this.locationId,
    required this.fuelType,
    required this.pricePerGallon,
    required this.updatedAt,
  });

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    final p = json['price_per_gallon'] ?? json['price'] ?? json['ppg'];
    double price;
    if (p is num) {
      price = p.toDouble();
    } else if (p is String) {
      price = double.tryParse(p) ?? 0.0;
    } else {
      price = 0.0;
    }
    final ts = json['updated_at'] ?? json['updatedAt'];
    DateTime updated;
    if (ts is String) {
      updated = DateTime.tryParse(ts)?.toUtc() ?? DateTime.now().toUtc();
    } else if (ts is int) {
      updated = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    } else {
      updated = DateTime.now().toUtc();
    }
    return FuelPrice(
      locationId: json['location_id']?.toString() ?? json['locationId']?.toString() ?? '',
      fuelType: json['fuel_type']?.toString() ?? json['fuelType']?.toString() ?? 'diesel',
      pricePerGallon: price,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toJson() => {
        'location_id': locationId,
        'fuel_type': fuelType,
        'price_per_gallon': pricePerGallon,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
