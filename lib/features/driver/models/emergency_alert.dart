enum EmergencyType {
  accident,
  medical,
  theft,
  breakdown,
  harassment,
  weather,
  other,
}

class EmergencyAlert {
  final String id;
  final EmergencyType type;
  final double lat;
  final double lng;
  final String? notes;
  final List<String>? photoUrls;
  final String status;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;

  const EmergencyAlert({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    this.notes,
    this.photoUrls,
    required this.status,
    required this.triggeredAt,
    this.resolvedAt,
  });

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) => EmergencyAlert(
        id: json['id'] as String,
        type: EmergencyType.values.firstWhere((e) => e.name == json['type']),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        notes: json['notes'] as String?,
        photoUrls: (json['photo_urls'] as List?)?.map((e) => e.toString()).toList(),
        status: json['status'] as String,
        triggeredAt: DateTime.parse(json['triggered_at'] as String),
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
      );
}

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String role;
  final int priority;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.priority,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        role: json['role'] as String,
        priority: json['priority'] as int,
      );
}
