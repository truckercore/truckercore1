import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal models with fromJson to keep providers usable across the app.
/// If your project already has canonical models, replace these with imports.
class Vehicle {
  final String id;
  final String unitNumber;
  final String status;
  final double? speed;
  final String? driverName;
  final double? latitude;
  final double? longitude;
  final String? city;

  Vehicle({
    required this.id,
    required this.unitNumber,
    required this.status,
    this.speed,
    this.driverName,
    this.latitude,
    this.longitude,
    this.city,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: (json['id'] ?? json['vehicle_id']).toString(),
      unitNumber: (json['unit_number'] ?? json['unitNumber'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      speed: (json['speed'] as num?)?.toDouble(),
      driverName: json['driver_name']?.toString() ?? json['driverName']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? (json['lat'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble() ?? (json['lon'] as num?)?.toDouble(),
      city: json['city']?.toString(),
    );
  }
}

class DriverMetric {
  final String driverId;
  final String driverName;
  final double overallScore;
  final double safetyScore;
  final double fuelEfficiency;
  final double onTimePercent;
  final int totalTrips;
  final int totalMiles;

  DriverMetric({
    required this.driverId,
    required this.driverName,
    required this.overallScore,
    required this.safetyScore,
    required this.fuelEfficiency,
    required this.onTimePercent,
    required this.totalTrips,
    required this.totalMiles,
  });

  factory DriverMetric.fromJson(Map<String, dynamic> json) {
    return DriverMetric(
      driverId: (json['driver_id'] ?? json['driverId'] ?? '').toString(),
      driverName: (json['driver_name'] ?? json['driverName'] ?? 'Unknown').toString(),
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0,
      safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 0,
      fuelEfficiency: (json['fuel_efficiency'] as num?)?.toDouble() ?? 0,
      onTimePercent: (json['on_time_percent'] as num?)?.toDouble() ??
          (json['on_time_delivery_percent'] as num?)?.toDouble() ?? 0,
      totalTrips: (json['total_trips'] as num?)?.toInt() ?? 0,
      totalMiles: (json['total_miles'] as num?)?.toInt() ?? 0,
    );
  }
}

// Real-time vehicle stream
final vehiclesStreamProvider = StreamProvider.autoDispose<List<Vehicle>>((ref) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('vehicles')
      .stream(primaryKey: ['id'])
      .order('unit_number')
      .map((rows) => rows.map((json) => Vehicle.fromJson(json)).toList());
});

// Driver performance from analytics table (last 30 days)
final driverPerformanceProvider =
    FutureProvider.autoDispose<List<DriverMetric>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('driver_analytics')
      .select()
      .gte('period_start', DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
      .order('overall_score', ascending: false);

  // response is a List<dynamic>
  return (response as List)
      .map((e) => DriverMetric.fromJson(e as Map<String, dynamic>))
      .toList();
});
