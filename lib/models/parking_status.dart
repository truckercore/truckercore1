// lib/models/parking_status.dart
// Robust model for parking status with null/shape tolerant parsing and helpers.

import 'package:collection/collection.dart';

class ParkingStatus {
  final String? stopId;
  final int? availableEstimate;
  final int? availableTotal;
  final double? confidence; // 0..1
  final String? lastReportedBy;
  final DateTime? lastReportedAt;
  // Free/masked fields
  final String? statusBucket; // 'open'|'limited'|'full'|'unknown'
  // Optional breakdown e.g., { operator_reports: N, driver_reports: N, sensor_reports: N }
  final Map<String, dynamic>? breakdown;

  const ParkingStatus({
    this.stopId,
    this.availableEstimate,
    this.availableTotal,
    this.confidence,
    this.lastReportedBy,
    this.lastReportedAt,
    this.statusBucket,
    this.breakdown,
  });

  bool get isPremium => availableEstimate != null || availableTotal != null;

  ParkingStatus copyWith({
    String? stopId,
    int? availableEstimate,
    int? availableTotal,
    double? confidence,
    String? lastReportedBy,
    DateTime? lastReportedAt,
    String? statusBucket,
    Map<String, dynamic>? breakdown,
  }) => ParkingStatus(
        stopId: stopId ?? this.stopId,
        availableEstimate: availableEstimate ?? this.availableEstimate,
        availableTotal: availableTotal ?? this.availableTotal,
        confidence: confidence ?? this.confidence,
        lastReportedBy: lastReportedBy ?? this.lastReportedBy,
        lastReportedAt: lastReportedAt ?? this.lastReportedAt,
        statusBucket: statusBucket ?? this.statusBucket,
        breakdown: breakdown ?? this.breakdown,
      );

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();
    if (v is String && v.isNotEmpty) {
      try { return DateTime.parse(v).toLocal(); } catch (_) { return null; }
    }
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final n = double.tryParse(v);
      return n;
    }
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory ParkingStatus.fromJson(Map<String, dynamic> j) {
    // Accept both detailed and masked shapes
    final breakdownRaw = j['breakdown'];
    return ParkingStatus(
      stopId: (j['stop_id'] ?? j['id'])?.toString(),
      availableEstimate: _toInt(j['available_estimate']),
      availableTotal: _toInt(j['available_total']),
      confidence: _toDouble(j['confidence']) ?? _toDouble(j['confidence_rounded']),
      lastReportedBy: j['last_reported_by']?.toString(),
      lastReportedAt: _parseDate(j['last_reported_at']),
      statusBucket: j['status_bucket']?.toString(),
      breakdown: breakdownRaw is Map<String, dynamic>
          ? breakdownRaw
          : (breakdownRaw is Map
              ? breakdownRaw.map((k, v) => MapEntry(k.toString(), v))
              : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'stop_id': stopId,
        'available_estimate': availableEstimate,
        'available_total': availableTotal,
        'confidence': confidence,
        'last_reported_by': lastReportedBy,
        'last_reported_at': lastReportedAt?.toIso8601String(),
        'status_bucket': statusBucket,
        'breakdown': breakdown,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParkingStatus &&
          stopId == other.stopId &&
          availableEstimate == other.availableEstimate &&
          availableTotal == other.availableTotal &&
          confidence == other.confidence &&
          lastReportedBy == other.lastReportedBy &&
          _eqDate(lastReportedAt, other.lastReportedAt) &&
          statusBucket == other.statusBucket &&
          const DeepCollectionEquality().equals(breakdown, other.breakdown);

  @override
  int get hashCode => Object.hash(
        stopId,
        availableEstimate,
        availableTotal,
        confidence,
        lastReportedBy,
        lastReportedAt?.millisecondsSinceEpoch,
        statusBucket,
        const DeepCollectionEquality().hash(breakdown),
      );

  static bool _eqDate(DateTime? a, DateTime? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.millisecondsSinceEpoch == b.millisecondsSinceEpoch;
  }
}
