import 'package:supabase_flutter/supabase_flutter.dart';

class HosService {
  final SupabaseClient _c;
  HosService(this._c);

  /// Close the most recent HOS segment for driver today by setting end_time=now().
  Future<void> _closeLastIfAny(String driverId) async {
    // Get latest segment for today (UTC day)
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final rows = await _c
        .from('hos_logs')
        .select('id, start_time, end_time')
        .eq('driver_user_id', driverId)
        .gte('start_time', startOfDay.toIso8601String())
        .order('start_time', ascending: false)
        .limit(1);
    final list = (rows as List?) ?? const [];
    if (list.isNotEmpty) {
      final r = Map<String, dynamic>.from(list.first as Map);
      // If the latest segment already has end_time >= start_time, we will still update to 'now' to close precisely at switch time.
      await _c
          .from('hos_logs')
          .update({'end_time': now.toIso8601String()})
          .eq('id', r['id'] as String);
    }
  }

  /// Change duty status by closing the previous segment (if any today) and opening a new one with start=end=now.
  /// newStatus: 'off' | 'sleeper' | 'on' | 'driving'
  Future<void> changeDutyStatus({
    required String driverId,
    required String newStatus,
  }) async {
    // 1) Close last segment (if any)
    await _closeLastIfAny(driverId);
    // 2) Open new segment with start=end=now to satisfy NOT NULL end_time
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _c.from('hos_logs').insert({
      'driver_user_id': driverId,
      'start_time': nowIso,
      'end_time': nowIso,
      'status': newStatus,
      'source': 'manual',
    });
  }

  /// Ensure a segment exists for today; if none, create an initial Off Duty segment at current time.
  Future<void> ensureTodayInitialized(String driverId) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final rows = await _c
        .from('hos_logs')
        .select('id')
        .eq('driver_user_id', driverId)
        .gte('start_time', startOfDay.toIso8601String())
        .limit(1);
    final hasToday = (rows as List?)?.isNotEmpty == true;
    if (!hasToday) {
      final iso = now.toIso8601String();
      await _c.from('hos_logs').insert({
        'driver_user_id': driverId,
        'start_time': iso,
        'end_time': iso,
        'status': 'off',
        'source': 'manual',
      });
    }
  }

  /// Get latest status label for today.
  Future<String?> currentStatusToday(String driverId) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
    final rows = await _c
        .from('hos_logs')
        .select('status, start_time')
        .eq('driver_user_id', driverId)
        .gte('start_time', startOfDay.toIso8601String())
        .order('start_time', ascending: false)
        .limit(1);
    final list = (rows as List?) ?? const [];
    if (list.isNotEmpty) {
      final r = Map<String, dynamic>.from(list.first as Map);
      return r['status'] as String?;
    }
    return null;
  }
}
