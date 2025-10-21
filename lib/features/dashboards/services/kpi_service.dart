import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class DashboardKpis {
  final int activeTrucks;
  final int deliveries;
  final double onTimeRate;
  final double km;
  // Prior-period (same length immediately preceding)
  final int deliveriesPrior;
  final double onTimeRatePrior;
  final double kmPrior;
  const DashboardKpis({
    required this.activeTrucks,
    required this.deliveries,
    required this.onTimeRate,
    required this.km,
    this.deliveriesPrior = 0,
    this.onTimeRatePrior = 0,
    this.kmPrior = 0,
  });
}

class DashboardRange {
  final DateTime start;
  final DateTime end;
  const DashboardRange({required this.start, required this.end});
  static DashboardRange today() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return DashboardRange(start: d, end: d);
  }

  static DashboardRange lastDays(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days - 1));
    return DashboardRange(start: start, end: end);
  }
}

class KpiService {
  KpiService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<DashboardKpis?> fetchKpis({DashboardRange? range}) async {
    final c = _maybe();
    if (c == null) {
      return const DashboardKpis(
        activeTrucks: 0,
        deliveries: 0,
        onTimeRate: 0,
        km: 0,
      );
    }
    final r = range ?? DashboardRange.today();
    final params = {
      'p_start_date': DateTime(
        r.start.year,
        r.start.month,
        r.start.day,
      ).toIso8601String().substring(0, 10),
      'p_end_date': DateTime(
        r.end.year,
        r.end.month,
        r.end.day,
      ).toIso8601String().substring(0, 10),
    };
    final rows = await c.rpc('fn_dashboard_kpis', params: params);
    final list = (rows as List?) ?? const [];
    if (list.isEmpty) {
      return const DashboardKpis(
        activeTrucks: 0,
        deliveries: 0,
        onTimeRate: 0,
        km: 0,
      );
    }
    final m = Map<String, dynamic>.from(list.first as Map);
    return DashboardKpis(
      activeTrucks: (m['active_trucks'] as int?) ?? 0,
      deliveries: (m['deliveries'] as int?) ?? 0,
      onTimeRate: (m['on_time_rate'] as num?)?.toDouble() ?? 0,
      km: (m['km'] as num?)?.toDouble() ?? 0,
      deliveriesPrior: (m['deliveries_prior'] as int?) ?? 0,
      onTimeRatePrior: (m['on_time_rate_prior'] as num?)?.toDouble() ?? 0,
      kmPrior: (m['km_prior'] as num?)?.toDouble() ?? 0,
    );
  }
}

final kpiServiceProvider = Provider<KpiService>((ref) => KpiService(ref));
