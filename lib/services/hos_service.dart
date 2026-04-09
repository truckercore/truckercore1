import 'package:supabase_flutter/supabase_flutter.dart';

class HosService {
  final _supabase = Supabase.instance.client;

  // HOS limits in minutes
  static const int maxDrivingMinutes = 660;    // 11 hours
  static const int maxOnDutyMinutes = 840;     // 14 hours
  static const int resetAfterMinutes = 600;    // 10 hours off duty

  Future<Map<String, dynamic>> getHosStatus(String driverId) async {
    final driver = await _supabase
        .from('drivers')
        .select('hos_driving_minutes, hos_on_duty_minutes, hos_reset_at, status')
        .eq('id', driverId)
        .single();

    final drivingMinutes = driver['hos_driving_minutes'] as int? ?? 0;
    final onDutyMinutes = driver['hos_on_duty_minutes'] as int? ?? 0;

    final drivingRemaining = maxDrivingMinutes - drivingMinutes;
    final onDutyRemaining = maxOnDutyMinutes - onDutyMinutes;

    return {
      'drivingMinutes': drivingMinutes,
      'onDutyMinutes': onDutyMinutes,
      'drivingRemaining': drivingRemaining,
      'onDutyRemaining': onDutyRemaining,
      'isOverDrivingLimit': drivingMinutes >= maxDrivingMinutes,
      'isOverOnDutyLimit': onDutyMinutes >= maxOnDutyMinutes,
      'needsReset': drivingRemaining <= 60,
      'status': driver['status'],
    };
  }

  Future<void> logEvent({
    required String driverId,
    required String userId,
    required String eventType,
    String? orgId,
    String? notes,
  }) async {
    // Close previous open event
    await _supabase
        .from('hos_events')
        .update({
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('driver_id', driverId)
        .isFilter('ended_at', null);

    // Insert new event
    await _supabase.from('hos_events').insert({
      'driver_id': driverId,
      'user_id': userId,
      'org_id': orgId,
      'event_type': eventType,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'notes': notes,
    });

    // Update driver status
    await _supabase
        .from('drivers')
        .update({'status': _mapEventToStatus(eventType)})
        .eq('id', driverId);

    // Check HOS limits
    if (eventType == 'driving') {
      final status = await getHosStatus(driverId);
      if (status['isOverDrivingLimit'] == true) {
        throw Exception('⚠️ 11-hour driving limit exceeded. You must take a 10-hour break.');
      }
      if (status['needsReset'] == true) {
        print('⚠️ Warning: Less than 1 hour of driving time remaining');
      }
    }
  }

  String _mapEventToStatus(String eventType) {
    switch (eventType) {
      case 'driving': return 'driving';
      case 'on_duty': return 'on_duty';
      case 'sleeper': return 'sleeper';
      default: return 'off_duty';
    }
  }

  Future<void> updateDrivingTime(String driverId, int additionalMinutes) async {
    await _supabase.rpc('increment_hos_minutes', params: {
      'driver_id': driverId,
      'driving_minutes': additionalMinutes,
    });
  }
}
