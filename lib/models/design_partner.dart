import 'package:collection/collection.dart';

class DesignPartner {
  final String id;
  final String orgId;
  final DateTime pilotStart;
  final DateTime? pilotEnd;
  final Map<String, dynamic> successCriteria;
  final String status; // 'active' | 'completed' | 'failed'

  const DesignPartner({
    required this.id,
    required this.orgId,
    required this.pilotStart,
    this.pilotEnd,
    required this.successCriteria,
    required this.status,
  });

  DesignPartner copyWith({
    String? id,
    String? orgId,
    DateTime? pilotStart,
    DateTime? pilotEnd,
    Map<String, dynamic>? successCriteria,
    String? status,
  }) {
    return DesignPartner(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      pilotStart: pilotStart ?? this.pilotStart,
      pilotEnd: pilotEnd ?? this.pilotEnd,
      successCriteria: successCriteria ?? this.successCriteria,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'org_id': orgId,
      'pilot_start': pilotStart.toIso8601String(),
      'pilot_end': pilotEnd?.toIso8601String(),
      'success_criteria': successCriteria,
      'status': status,
    };
  }

  factory DesignPartner.fromJson(Map<String, dynamic> json) {
    final sc = json['success_criteria'];
    return DesignPartner(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      pilotStart: _parseDate(json['pilot_start']),
      pilotEnd: json['pilot_end'] == null ? null : _parseDate(json['pilot_end']),
      successCriteria: sc is Map<String, dynamic> ? sc : <String, dynamic>{},
      status: json['status'] as String,
    );
  }

  // PostgREST rows sometimes ship Date/Timestamp as DateTime; handle both.
  static DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v.toLocal();
    if (v is String) return DateTime.parse(v).toLocal();
    throw ArgumentError('Invalid date: $v');
  }

  @override
  String toString() => 'DesignPartner($orgId, $status, $pilotStart→$pilotEnd)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesignPartner &&
          id == other.id &&
          orgId == other.orgId &&
          pilotStart == other.pilotStart &&
          pilotEnd == other.pilotEnd &&
          const DeepCollectionEquality().equals(successCriteria, other.successCriteria) &&
          status == other.status;

  @override
  int get hashCode =>
      Object.hash(id, orgId, pilotStart, pilotEnd, const DeepCollectionEquality().hash(successCriteria), status);
}
