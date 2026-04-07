class TruckRestriction {
  final int id;
  final String stateCode;
  final String category; // 'low_clearance' | 'weigh_station' | 'restricted_route'
  final String description;
  final Map<String, dynamic>? location; // { lat, lng }

  const TruckRestriction({
    required this.id,
    required this.stateCode,
    required this.category,
    required this.description,
    this.location,
  });

  factory TruckRestriction.fromJson(Map<String, dynamic> json) => TruckRestriction(
        id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
        stateCode: json['state_code'] ?? '',
        category: json['category'] ?? '',
        description: json['description'] ?? '',
        location: json['location'] as Map<String, dynamic>?,
      );
}
