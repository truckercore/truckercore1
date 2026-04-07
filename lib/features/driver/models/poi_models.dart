class TruckStop {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int? availableSpaces;

  TruckStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.availableSpaces,
  });

  factory TruckStop.fromJson(Map<String, dynamic> json) => TruckStop(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        availableSpaces: (json['available_spaces'] as num?)?.toInt(),
      );
}

class WeighStation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String status; // open/closed/bypassable

  WeighStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.status,
  });

  factory WeighStation.fromJson(Map<String, dynamic> json) => WeighStation(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        status: json['status'] as String? ?? 'unknown',
      );
}

class FuelStation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? fuelType;
  final double? pricePerGallon;

  FuelStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.fuelType,
    this.pricePerGallon,
  });

  factory FuelStation.fromJson(Map<String, dynamic> json) => FuelStation(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        fuelType: json['fuel_type'] as String?,
        pricePerGallon: (json['price_per_gallon'] as num?)?.toDouble(),
      );
}

class RestArea {
  final String id;
  final String name;
  final double lat;
  final double lng;

  RestArea({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  factory RestArea.fromJson(Map<String, dynamic> json) => RestArea(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

class DockGuidance {
  final String loadId;
  final String instructions;
  final List<String>? imageUrls;

  DockGuidance({
    required this.loadId,
    required this.instructions,
    this.imageUrls,
  });

  factory DockGuidance.fromJson(Map<String, dynamic> json) => DockGuidance(
        loadId: json['load_id']?.toString() ?? '',
        instructions: json['instructions'] as String? ?? '',
        imageUrls: (json['image_urls'] as List?)?.map((e) => e.toString()).toList(),
      );
}
