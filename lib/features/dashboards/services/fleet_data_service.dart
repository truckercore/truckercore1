import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data service abstraction to decouple dashboards from mock vs. real data sources.
abstract class IFleetDataService {
  Future<List<DriverPerformanceData>> getDriverPerformance();
  Future<FuelMaintenanceData> getFuelAndMaintenance();
}

class DriverPerformanceData {
  final String driverId;
  final String driverName;
  final double overallScore;
  final double safetyScore;
  final double fuelEfficiency;
  final double onTimePercent;
  final int totalTrips;
  final int totalMiles;
  const DriverPerformanceData({
    required this.driverId,
    required this.driverName,
    required this.overallScore,
    required this.safetyScore,
    required this.fuelEfficiency,
    required this.onTimePercent,
    required this.totalTrips,
    required this.totalMiles,
  });
}

class FuelMaintenanceData {
  final List<FuelRecordLite> fuel;
  final List<MaintenanceRecordLite> maintenance;
  const FuelMaintenanceData({required this.fuel, required this.maintenance});
}

class FuelRecordLite {
  final String vehicleId;
  final String unitNumber;
  final DateTime date;
  final double gallons;
  final double costPerGallon;
  final double totalCost;
  const FuelRecordLite({
    required this.vehicleId,
    required this.unitNumber,
    required this.date,
    required this.gallons,
    required this.costPerGallon,
    required this.totalCost,
  });
}

class MaintenanceRecordLite {
  final String vehicleId;
  final String unitNumber;
  final DateTime date;
  final String type;
  final String description;
  final double cost;
  const MaintenanceRecordLite({
    required this.vehicleId,
    required this.unitNumber,
    required this.date,
    required this.type,
    required this.description,
    required this.cost,
  });
}

/// Mock implementation used by current dashboards/tests.
class MockFleetDataService implements IFleetDataService {
  @override
  Future<List<DriverPerformanceData>> getDriverPerformance() async {
    // Lightweight deterministic mock
    final names = <String>[
      'John Smith',
      'Jane Doe',
      'Mike Johnson',
      'Sarah Williams',
      'Tom Brown',
    ];
    final list = names.map((n) {
      final h = n.hashCode;
      final safety = 70 + (h % 30).toDouble();
      final mpg = 6.0 + ((h >> 3) % 30) / 10.0;
      final onTime = 85 + ((h >> 5) % 15).toDouble();
      final overall = (safety + mpg * 10 + onTime) / 3.0;
      return DriverPerformanceData(
        driverId: 'drv_${h.abs()}',
        driverName: n,
        overallScore: overall,
        safetyScore: safety,
        fuelEfficiency: mpg,
        onTimePercent: onTime,
        totalTrips: 100 + ((h >> 7) % 120),
        totalMiles: 20000 + ((h >> 9) % 20000),
      );
    }).toList();
    list.sort((a, b) => b.overallScore.compareTo(a.overallScore));
    return list;
  }

  @override
  Future<FuelMaintenanceData> getFuelAndMaintenance() async {
    final now = DateTime.now();
    final units = List.generate(5, (i) => 'TRUCK-${(i + 1).toString().padLeft(3, '0')}');
    final fuel = units
        .expand((u) => List.generate(3, (i) {
              final gals = (120 + (u.hashCode % 30)).toDouble();
              final cpg = 3.5 + (i * 0.1);
              return FuelRecordLite(
                vehicleId: 'veh_${u.hashCode}',
                unitNumber: u,
                date: now.subtract(Duration(days: i * 7)),
                gallons: gals,
                costPerGallon: cpg,
                totalCost: gals * cpg,
              );
            }))
        .toList();
    final maintenance = units
        .expand((u) => [
              MaintenanceRecordLite(
                vehicleId: 'veh_${u.hashCode}',
                unitNumber: u,
                date: now.subtract(const Duration(days: 10)),
                type: 'Oil Change',
                description: 'Routine oil change',
                cost: 150 + (u.hashCode % 50).toDouble(),
              ),
            ])
        .toList();
    return FuelMaintenanceData(fuel: fuel, maintenance: maintenance);
  }
}

/// Real implementation (stub) using Supabase tables.
/// Replace the table/field names with your schema as you wire it up.
class FleetDataService implements IFleetDataService {
  final SupabaseClient _supabase;
  FleetDataService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  @override
  Future<List<DriverPerformanceData>> getDriverPerformance() async {
    try {
      final rows = await _supabase
          .from('driver_analytics')
          .select()
          .gte('period_start', DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
          .order('overall_score', ascending: false);
      return (rows as List)
          .map((e) => e as Map<String, dynamic>)
          .map((j) => DriverPerformanceData(
                driverId: (j['driver_id'] ?? '').toString(),
                driverName: (j['driver_name'] ?? 'Unknown').toString(),
                overallScore: (j['overall_score'] as num?)?.toDouble() ?? 0,
                safetyScore: (j['safety_score'] as num?)?.toDouble() ?? 0,
                fuelEfficiency: (j['fuel_efficiency'] as num?)?.toDouble() ?? 0,
                onTimePercent: (j['on_time_percent'] as num?)?.toDouble() ?? 0,
                totalTrips: (j['total_trips'] as num?)?.toInt() ?? 0,
                totalMiles: (j['total_miles'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[FleetDataService] getDriverPerformance failed: $e');
      }
      return const <DriverPerformanceData>[];
    }
  }

  @override
  Future<FuelMaintenanceData> getFuelAndMaintenance() async {
    // Placeholder: implement with your own schema or REST API.
    // Returning empty to avoid runtime failures until wired.
    return const FuelMaintenanceData(fuel: <FuelRecordLite>[], maintenance: <MaintenanceRecordLite>[]);
  }
}
