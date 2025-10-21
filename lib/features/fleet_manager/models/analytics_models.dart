class UtilizationReport {
  final double utilizationPercent;
  final int totalMiles;
  final int activeHours;

  UtilizationReport({
    required this.utilizationPercent,
    required this.totalMiles,
    required this.activeHours,
  });

  factory UtilizationReport.fromJson(Map<String, dynamic> json) => UtilizationReport(
        utilizationPercent: (json['utilization_percent'] as num?)?.toDouble() ?? 0.0,
        totalMiles: (json['total_miles'] as num?)?.toInt() ?? 0,
        activeHours: (json['active_hours'] as num?)?.toInt() ?? 0,
      );
}

class PerformanceMetrics {
  final double safetyScore;
  final double onTimeDeliveryRate;
  final double complianceScore;

  PerformanceMetrics({
    required this.safetyScore,
    required this.onTimeDeliveryRate,
    required this.complianceScore,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) => PerformanceMetrics(
        safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 0.0,
        onTimeDeliveryRate: (json['on_time_delivery_rate'] as num?)?.toDouble() ?? 0.0,
        complianceScore: (json['compliance_score'] as num?)?.toDouble() ?? 0.0,
      );
}

class FuelAnalysis {
  final double avgMpg;
  final double fuelCost;

  FuelAnalysis({
    required this.avgMpg,
    required this.fuelCost,
  });

  factory FuelAnalysis.fromJson(Map<String, dynamic> json) => FuelAnalysis(
        avgMpg: (json['avg_mpg'] as num?)?.toDouble() ?? 0.0,
        fuelCost: (json['fuel_cost'] as num?)?.toDouble() ?? 0.0,
      );
}

class MileageReport {
  final int totalMiles;
  final Map<String, int>? milesByState;

  MileageReport({
    required this.totalMiles,
    this.milesByState,
  });

  factory MileageReport.fromJson(Map<String, dynamic> json) => MileageReport(
        totalMiles: (json['total_miles'] as num?)?.toInt() ?? 0,
        milesByState: json['miles_by_state'] is Map
            ? (json['miles_by_state'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
            : null,
      );
}

class DriverRanking {
  final String driverId;
  final double score;
  final int rank;

  DriverRanking({
    required this.driverId,
    required this.score,
    required this.rank,
  });

  factory DriverRanking.fromJson(Map<String, dynamic> json) => DriverRanking(
        driverId: json['driver_id']?.toString() ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0.0,
        rank: (json['rank'] as num?)?.toInt() ?? 0,
      );
}

class CostAnalysis {
  final double totalCost;
  final double costPerMile;

  CostAnalysis({
    required this.totalCost,
    required this.costPerMile,
  });

  factory CostAnalysis.fromJson(Map<String, dynamic> json) => CostAnalysis(
        totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
        costPerMile: (json['cost_per_mile'] as num?)?.toDouble() ?? 0.0,
      );
}
