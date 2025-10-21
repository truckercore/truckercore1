class UtilizationReport {
  final double utilizationPercent;
  final int activeHours;
  final int idleHours;
  final int totalMiles;

  UtilizationReport({
    required this.utilizationPercent,
    required this.activeHours,
    required this.idleHours,
    required this.totalMiles,
  });

  factory UtilizationReport.fromJson(Map<String, dynamic> json) => UtilizationReport(
        utilizationPercent: (json['utilization_percent'] as num?)?.toDouble() ?? 0.0,
        activeHours: (json['active_hours'] as num?)?.toInt() ?? 0,
        idleHours: (json['idle_hours'] as num?)?.toInt() ?? 0,
        totalMiles: (json['total_miles'] as num?)?.toInt() ?? 0,
      );
}
