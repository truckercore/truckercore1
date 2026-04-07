import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supa_client.dart';
import '../models/performance_metrics.dart';
import '../models/utilization_report.dart';

final fleetAnalyticsServiceProvider = Provider<FleetAnalyticsService>((ref) {
  return FleetAnalyticsService();
});

class FleetAnalyticsService {
  /// Get vehicle utilization analysis
  Future<UtilizationReport> getUtilizationReport({
    required DateTime startDate,
    required DateTime endDate,
    String? vehicleId,
  }) async {
    final response = await SupaClient.rpc('calculate_utilization', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'vehicle_id': vehicleId,
    });

    return UtilizationReport.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Get comprehensive performance metrics
  Future<PerformanceMetrics> getPerformanceMetrics({
    required DateTime startDate,
    required DateTime endDate,
    String? driverId,
    String? vehicleId,
  }) async {
    final response = await SupaClient.rpc('get_performance_metrics', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'driver_id': driverId,
      'vehicle_id': vehicleId,
    });

    return PerformanceMetrics.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Get fuel consumption analysis
  Future<FuelAnalysis> getFuelAnalysis({
    required DateTime startDate,
    required DateTime endDate,
    String? vehicleId,
  }) async {
    final response = await SupaClient.rpc('analyze_fuel_consumption', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'vehicle_id': vehicleId,
    });

    return FuelAnalysis.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Generate mileage report
  Future<MileageReport> getMileageReport({
    required DateTime startDate,
    required DateTime endDate,
    String? vehicleId,
  }) async {
    final response = await SupaClient.rpc('generate_mileage_report', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'vehicle_id': vehicleId,
    });

    return MileageReport.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Get driver performance rankings
  Future<List<DriverRanking>> getDriverRankings({
    required DateTime startDate,
    required DateTime endDate,
    String metric = 'safety_score',
  }) async {
    final response = await SupaClient.rpc('rank_drivers', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'metric': metric,
    });

    return (response as List)
        .map((r) => DriverRanking.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Get cost analysis
  Future<CostAnalysis> getCostAnalysis({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.rpc('analyze_costs', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    return CostAnalysis.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Export report to CSV
  Future<String> exportReport({
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? filters,
  }) async {
    final response = await SupaClient.functions('export-report', {
      'report_type': reportType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'filters': filters,
    });

    final map = Map<String, dynamic>.from(response.data as Map);
    return map['download_url']?.toString() ?? '';
  }
}
