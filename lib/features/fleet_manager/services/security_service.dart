import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/security_alert.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final securityAlertsProvider = StreamProvider<List<SecurityAlert>>((ref) {
  final service = ref.watch(securityServiceProvider);
  return service.watchSecurityAlerts();
});

class SecurityService {
  /// Watch security alerts (unauthorized movement, zone violations)
  Stream<List<SecurityAlert>> watchSecurityAlerts() {
    return SupaClient.stream(
      'security_alerts',
      primaryKey: const ['id'],
      filter: (query) => query
          .eq('acknowledged', false)
          .order('triggered_at', ascending: false),
    ).map((data) => data.map((a) => SecurityAlert.fromJson(a)).toList());
  }

  /// Report unauthorized vehicle movement
  Future<String> reportUnauthorizedMovement({
    required String vehicleId,
    required double lat,
    required double lng,
    String? details,
  }) async {
    final response = await SupaClient.from('security_alerts').insert({
      'vehicle_id': vehicleId,
      'alert_type': 'unauthorized_movement',
      'lat': lat,
      'lng': lng,
      'details': details,
      'severity': 'critical',
      'triggered_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    return response['id'] as String;
  }

  /// Set vehicle immobilization
  Future<void> immobilizeVehicle(String vehicleId) async {
    await SupaClient.from('vehicle_security')
        .update({
          'immobilized': true,
          'immobilized_at': DateTime.now().toIso8601String(),
        })
        .eq('vehicle_id', vehicleId);

    // Trigger command to telematics device
    await SupaClient.functions('immobilize-vehicle', {
      'vehicle_id': vehicleId,
    });
  }

  /// Release vehicle immobilization
  Future<void> releaseVehicle(String vehicleId) async {
    await SupaClient.from('vehicle_security')
        .update({
          'immobilized': false,
          'released_at': DateTime.now().toIso8601String(),
        })
        .eq('vehicle_id', vehicleId);

    await SupaClient.functions('release-vehicle', {
      'vehicle_id': vehicleId,
    });
  }

  /// Check if vehicle is in authorized zone
  Future<bool> isInAuthorizedZone({
    required String vehicleId,
    required double lat,
    required double lng,
  }) async {
    final response = await SupaClient.rpc('check_authorized_zone', params: {
      'vehicle_id': vehicleId,
      'lat': lat,
      'lng': lng,
    });

    return response as bool;
  }

  /// Set authorized operating hours
  Future<void> setAuthorizedHours({
    required String vehicleId,
    required String startTime,
    required String endTime,
    List<int>? daysOfWeek,
  }) async {
    await SupaClient.from('vehicle_authorized_hours').upsert({
      'vehicle_id': vehicleId,
      'start_time': startTime,
      'end_time': endTime,
      'days_of_week': daysOfWeek,
    });
  }

  /// Get vehicle theft history
  Future<List<SecurityIncident>> getSecurityIncidents({
    String? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = SupaClient.from('security_incidents')
        .select('*')
        .order('occurred_at', ascending: false);

    if (vehicleId != null) {
      query = query.eq('vehicle_id', vehicleId);
    }
    if (startDate != null) {
      query = query.gte('occurred_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('occurred_at', endDate.toIso8601String());
    }

    final response = await query;
    return (response as List).map((i) => SecurityIncident.fromJson(i)).toList();
  }

  /// Acknowledge security alert
  Future<void> acknowledgeAlert(String alertId) async {
    await SupaClient.from('security_alerts')
        .update({
          'acknowledged': true,
          'acknowledged_at': DateTime.now().toIso8601String(),
        })
        .eq('id', alertId);
  }

  /// Enable/disable geofence alerts
  Future<void> setGeofenceAlerts({
    required String vehicleId,
    required bool enabled,
  }) async {
    await SupaClient.from('vehicle_security')
        .update({'geofence_alerts_enabled': enabled})
        .eq('vehicle_id', vehicleId);
  }
}
