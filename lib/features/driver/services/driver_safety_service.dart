import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/safety_event.dart';

final driverSafetyServiceProvider = Provider<DriverSafetyService>((ref) {
  return DriverSafetyService();
});

final drivingSafetyScoreProvider = StreamProvider<DrivingSafetyScore>((ref) {
  final service = ref.watch(driverSafetyServiceProvider);
  return service.watchSafetyScore();
});

class DriverSafetyService {
  /// Record safety event (harsh braking, acceleration, speeding)
  Future<void> recordSafetyEvent({
    required SafetyEventType type,
    required double severity,
    required double lat,
    required double lng,
    required double speed,
    Map<String, dynamic>? telemetry,
  }) async {
    await SupaClient.from('safety_events').insert({
      'event_type': type.name,
      'severity': severity,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'telemetry': telemetry,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get real-time safety score
  Stream<DrivingSafetyScore> watchSafetyScore() {
    return SupaClient.stream(
      'driver_safety_scores',
      primaryKey: const ['driver_id'],
      filter: (query) => query.order('updated_at', ascending: false).limit(1),
    ).map((data) => DrivingSafetyScore.fromJson(data.first));
  }

  /// Get safety events history
  Future<List<SafetyEvent>> getSafetyEvents({
    required DateTime startDate,
    required DateTime endDate,
    List<SafetyEventType>? types,
  }) async {
    var query = SupaClient.from('safety_events')
        .select('*')
        .gte('timestamp', startDate.toIso8601String())
        .lte('timestamp', endDate.toIso8601String())
        .order('timestamp', ascending: false);

    if (types != null && types.isNotEmpty) {
      query = query.in_('event_type', types.map((t) => t.name).toList());
    }

    final response = await query;
    return (response as List).map((e) => SafetyEvent.fromJson(e)).toList();
  }

  /// Get driving behavior analytics
  Future<DrivingBehaviorAnalytics> getBehaviorAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.rpc('analyze_driving_behavior', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    return DrivingBehaviorAnalytics.fromJson(response as Map<String, dynamic>);
  }

  /// Get speed violation alerts
  Stream<SpeedViolation> watchSpeedViolations() {
    return SupaClient.stream(
      'speed_violations',
      primaryKey: const ['id'],
      filter: (query) => query
          .eq('acknowledged', false)
          .order('timestamp', ascending: false),
    ).map((data) => SpeedViolation.fromJson(data.first));
  }

  /// Submit safety improvement acknowledgment
  Future<void> acknowledgeSafetyCoaching(String eventId) async {
    await SupaClient.from('safety_events')
        .update({
          'coached': true,
          'coached_at': DateTime.now().toIso8601String(),
        })
        .eq('id', eventId);
  }

  /// Get safety tips based on driving patterns
  Future<List<SafetyTip>> getPersonalizedSafetyTips() async {
    final response = await SupaClient.rpc('get_personalized_safety_tips');
    return (response as List).map((t) => SafetyTip.fromJson(t)).toList();
  }
}
