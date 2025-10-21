class ELDComplianceStatus {
  final bool compliant;
  final int violationsLast30Days;
  final String? message;

  ELDComplianceStatus({
    required this.compliant,
    required this.violationsLast30Days,
    this.message,
  });

  factory ELDComplianceStatus.fromJson(Map<String, dynamic> json) => ELDComplianceStatus(
        compliant: json['compliant'] as bool? ?? true,
        violationsLast30Days: (json['violations_last_30_days'] as num?)?.toInt() ?? 0,
        message: json['message']?.toString(),
      );
}

class IFTAReport {
  final String reportId;
  final String period; // e.g., Q1-2025
  final int totalMiles;
  final double totalGallons;
  final Map<String, dynamic>? details;

  IFTAReport({
    required this.reportId,
    required this.period,
    required this.totalMiles,
    required this.totalGallons,
    this.details,
  });

  factory IFTAReport.fromJson(Map<String, dynamic> json) => IFTAReport(
        reportId: json['report_id']?.toString() ?? '',
        period: json['period']?.toString() ?? '',
        totalMiles: (json['total_miles'] as num?)?.toInt() ?? 0,
        totalGallons: (json['total_gallons'] as num?)?.toDouble() ?? 0,
        details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : null,
      );
}

class ComplianceAlert {
  final String id;
  final String severity; // low/medium/high/critical
  final String type;
  final String message;
  final bool acknowledged;
  final DateTime createdAt;

  ComplianceAlert({
    required this.id,
    required this.severity,
    required this.type,
    required this.message,
    required this.acknowledged,
    required this.createdAt,
  });

  factory ComplianceAlert.fromJson(Map<String, dynamic> json) => ComplianceAlert(
        id: json['id']?.toString() ?? '',
        severity: json['severity']?.toString() ?? 'low',
        type: json['type']?.toString() ?? 'compliance',
        message: json['message']?.toString() ?? '',
        acknowledged: json['acknowledged'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      );
}
