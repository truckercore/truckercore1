// lib/services/telematics_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/config/app_config.dart';

class TelematicsEvent {
  final String id;
  final String driverUserId;
  final String type; // speeding|idle|harsh_brake|harsh_turn|accel
  final DateTime occurredAt;
  final Map<String, dynamic> data;
  const TelematicsEvent({
    required this.id,
    required this.driverUserId,
    required this.type,
    required this.occurredAt,
    this.data = const {},
  });

  static TelematicsEvent fromMap(Map<String, dynamic> row) => TelematicsEvent(
    id: row['id']?.toString() ?? '',
    driverUserId: row['driver_user_id']?.toString() ?? '',
    type: row['type']?.toString() ?? 'unknown',
    occurredAt:
        DateTime.tryParse(row['occurred_at']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    data: Map<String, dynamic>.from(row['data'] as Map? ?? const {}),
  );
}

class TelematicsService {
  TelematicsService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<TelematicsEvent?> lastSpeedingEvent(String driverUserId) async {
    final c = _maybe();
    if (c == null) return null;
    final rows = await c
        .from('telematics_events')
        .select()
        .eq('driver_user_id', driverUserId)
        .eq('type', 'speeding')
        .order('occurred_at', ascending: false)
        .limit(1);
    final list = (rows as List?) ?? const [];
    if (list.isNotEmpty) {
      return TelematicsEvent.fromMap(
        Map<String, dynamic>.from(list.first as Map),
      );
    }
    return null;
  }

  Future<int> totalIdleMinutesToday(String driverUserId) async {
    final c = _maybe();
    if (c == null) return 0;
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final res = await c
        .rpc(
          'fn_total_idle_minutes',
          params: {
            'p_driver_user_id': driverUserId,
            'p_since': start.toIso8601String(),
            'p_until': now.toIso8601String(),
          },
        )
        .catchError((_) async {
          // Fallback: approximate by summing durations from events table if present
          final rows = await c
              .from('telematics_events')
              .select('data, occurred_at')
              .eq('driver_user_id', driverUserId)
              .eq('type', 'idle')
              .gte('occurred_at', start.toIso8601String())
              .lte('occurred_at', now.toIso8601String());
          int sum = 0;
          final list = (rows as List?) ?? const [];
          for (final r in list) {
            final m = (r['data'] is Map)
                ? Map<String, dynamic>.from(r['data'] as Map)
                : <String, dynamic>{};
            sum += (m['minutes'] as int?) ?? (m['duration_min'] as int?) ?? 0;
          }
          return sum;
        });
    if (res is int) return res;
    if (res is num) return res.toInt();
    return 0;
  }

  Future<int> harshEventsCount7d(String driverUserId) async {
    final c = _maybe();
    if (c == null) return 0;
    final now = DateTime.now().toUtc();
    final since = now.subtract(const Duration(days: 7));
    final rows = await c
        .from('telematics_events')
        .select('id')
        .eq('driver_user_id', driverUserId)
        .or('type.eq.harsh_brake,type.eq.harsh_turn,type.eq.accel')
        .gte('occurred_at', since.toIso8601String());
    final list = (rows as List?) ?? const [];
    return list.length;
  }

  Future<List<TelematicsEvent>> telemetryHistory(
    String driverUserId, {
    int limit = 100,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    final rows = await c
        .from('telematics_events')
        .select()
        .eq('driver_user_id', driverUserId)
        .order('occurred_at', ascending: false)
        .limit(limit);
    final list = (rows as List?) ?? const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(TelematicsEvent.fromMap)
        .toList();
  }
}

final telematicsServiceProvider = Provider<TelematicsService>(
  (ref) => TelematicsService(ref),
);
