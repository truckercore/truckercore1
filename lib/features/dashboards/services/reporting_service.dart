import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class OrgDailyStats {
  final DateTime day;
  final double kmTraveled;
  final double drivingMinutes;
  final double idleMinutes;
  final int deliveries;
  final int onTimeDeliveries;
  const OrgDailyStats({
    required this.day,
    required this.kmTraveled,
    required this.drivingMinutes,
    required this.idleMinutes,
    required this.deliveries,
    required this.onTimeDeliveries,
  });
  factory OrgDailyStats.fromRow(Map<String, dynamic> r) => OrgDailyStats(
    day: DateTime.parse(r['day'] as String),
    kmTraveled: (r['km_traveled'] as num?)?.toDouble() ?? 0,
    drivingMinutes: (r['driving_minutes'] as num?)?.toDouble() ?? 0,
    idleMinutes: (r['idle_minutes'] as num?)?.toDouble() ?? 0,
    deliveries: (r['deliveries'] as int?) ?? 0,
    onTimeDeliveries: (r['on_time_deliveries'] as int?) ?? 0,
  );
}

class ReportingService {
  ReportingService(this._ref);
  final Ref _ref;
  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<OrgDailyStats>> lastNDaysOrgStats({int days = 7}) async {
    final c = _maybe();
    if (c == null) return const [];
    final since = DateTime.now().toUtc().subtract(Duration(days: days));
    final rows = await c
        .from('v_daily_org_stats')
        .select()
        .gte('day', since.toIso8601String().substring(0, 10))
        .order('day');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(OrgDailyStats.fromRow)
        .toList();
  }

  Future<int> todayPositionsUsed() async {
    final c = _maybe();
    if (c == null) return 0;
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final rowDyn = await c
        .from('usage_counters')
        .select('count')
        .eq('metric', 'positions')
        .eq('day', today)
        .maybeSingle();
    if (rowDyn == null) return 0;
    final row = Map<String, dynamic>.from(rowDyn as Map);
    return (row['count'] as int?) ?? 0;
  }
}

final reportingServiceProvider = Provider<ReportingService>(
  (ref) => ReportingService(ref),
);
