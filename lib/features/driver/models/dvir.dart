class InspectionItem {
  final String name;
  final bool passed;
  final String? notes;
  final String? severity; // e.g., minor, major, critical

  InspectionItem({
    required this.name,
    required this.passed,
    this.notes,
    this.severity,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'passed': passed,
        'notes': notes,
        'severity': severity,
      };

  factory InspectionItem.fromJson(Map<String, dynamic> json) => InspectionItem(
        name: json['name'] as String? ?? '',
        passed: json['passed'] as bool? ?? false,
        notes: json['notes'] as String?,
        severity: json['severity'] as String?,
      );
}

class DVIR {
  final String id;
  final String vehicleId;
  final String inspectionType; // pre_trip | post_trip
  final Map<String, InspectionItem> items;
  final String status; // satisfactory | defects_found | out_of_service
  final DateTime submittedAt;
  final String? defectsNotes;
  final List<String>? photoUrls;

  DVIR({
    required this.id,
    required this.vehicleId,
    required this.inspectionType,
    required this.items,
    required this.status,
    required this.submittedAt,
    this.defectsNotes,
    this.photoUrls,
  });

  factory DVIR.fromJson(Map<String, dynamic> json) => DVIR(
        id: json['id']?.toString() ?? '',
        vehicleId: json['vehicle_id']?.toString() ?? '',
        inspectionType: json['inspection_type'] as String? ?? 'pre_trip',
        items: (json['items'] as Map<String, dynamic>? ?? const {})
            .map((k, v) => MapEntry(k, InspectionItem.fromJson(Map<String, dynamic>.from(v)))),
        status: json['status'] as String? ?? 'satisfactory',
        submittedAt: DateTime.parse(json['submitted_at'] as String? ?? DateTime.now().toIso8601String()),
        defectsNotes: json['defects_notes'] as String?,
        photoUrls: (json['photo_urls'] as List?)?.map((e) => e.toString()).toList(),
      );
}

class DVIRDefect {
  final String id;
  final String vehicleId;
  final String component;
  final String severity; // minor | major | critical
  final String status; // open | resolved
  final String? notes;

  DVIRDefect({
    required this.id,
    required this.vehicleId,
    required this.component,
    required this.severity,
    required this.status,
    this.notes,
  });

  factory DVIRDefect.fromJson(Map<String, dynamic> json) => DVIRDefect(
        id: json['id']?.toString() ?? '',
        vehicleId: json['vehicle_id']?.toString() ?? '',
        component: json['component'] as String? ?? '',
        severity: json['severity'] as String? ?? 'minor',
        status: json['status'] as String? ?? 'open',
        notes: json['notes'] as String?,
      );
}
