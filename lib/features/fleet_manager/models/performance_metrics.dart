class PerformanceMetrics {
  final double safetyScore; // 0-100
  final double onTimeDeliveryRate; // 0-1
  final double fuelEfficiency; // mpg
  final int incidents; 

  PerformanceMetrics({
    required this.safetyScore,
    required this.onTimeDeliveryRate,
    required this.fuelEfficiency,
    required this.incidents,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) => PerformanceMetrics(
        safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 0,
        onTimeDeliveryRate: (json['on_time_delivery_rate'] as num?)?.toDouble() ?? 0,
        fuelEfficiency: (json['fuel_efficiency'] as num?)?.toDouble() ?? 0,
        incidents: (json['incidents'] as num?)?.toInt() ?? 0,
      );
}

class FuelAnalysis {
  final double totalGallons;
  final double avgMpg;
  final double totalCost;

  FuelAnalysis({
    required this.totalGallons,
    required this.avgMpg,
    required this.totalCost,
  });

  factory FuelAnalysis.fromJson(Map<String, dynamic> json) => FuelAnalysis(
        totalGallons: (json['total_gallons'] as num?)?.toDouble() ?? 0,
        avgMpg: (json['avg_mpg'] as num?)?.toDouble() ?? 0,
        totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      );
}

class MileageReport {
  final int totalMiles;
  final int interstateMiles;
  final int intrastateMiles;

  MileageReport({
    required this.totalMiles,
    required this.interstateMiles,
    required this.intrastateMiles,
  });

  factory MileageReport.fromJson(Map<String, dynamic> json) => MileageReport(
        totalMiles: (json['total_miles'] as num?)?.toInt() ?? 0,
        interstateMiles: (json['interstate_miles'] as num?)?.toInt() ?? 0,
        intrastateMiles: (json['intrastate_miles'] as num?)?.toInt() ?? 0,
      );
}

class DriverRanking {
  final String driverId;
  final String driverName;
  final double score;

  DriverRanking({
    required this.driverId,
    required this.driverName,
    required this.score,
  });

  factory DriverRanking.fromJson(Map<String, dynamic> json) => DriverRanking(
        driverId: json['driver_id']?.toString() ?? '',
        driverName: json['driver_name']?.toString() ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

class CostAnalysis {
  final double totalCost;
  final double maintenanceCost;
  final double fuelCost;
  final double otherCost;

  CostAnalysis({
    required this.totalCost,
    required this.maintenanceCost,
    required this.fuelCost,
    required this.otherCost,
  });

  factory CostAnalysis.fromJson(Map<String, dynamic> json) => CostAnalysis(
        totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
        maintenanceCost: (json['maintenance_cost'] as num?)?.toDouble() ?? 0,
        fuelCost: (json['fuel_cost'] as num?)?.toDouble() ?? 0,
        otherCost: (json['other_cost'] as num?)?.toDouble() ?? 0,
      );
}
