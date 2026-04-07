import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class FleetKpisSeriesPoint {
  final DateTime date;
  final int loads;
  final double miles;
  final double avgPpm;
  final double onTimePct;
  const FleetKpisSeriesPoint({
    required this.date,
    required this.loads,
    required this.miles,
    required this.avgPpm,
    required this.onTimePct,
  });
}

class FleetAnalytics {
  final int loads;
  final double miles;
  final double revenue;
  final double cost;
  final double avgPpm;
  final double onTimePct;
  final List<FleetKpisSeriesPoint> series;
  const FleetAnalytics({
    required this.loads,
    required this.miles,
    required this.revenue,
    required this.cost,
    required this.avgPpm,
    required this.onTimePct,
    required this.series,
  });
}

class AnalyticsService {
  AnalyticsService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<FleetAnalytics> getFleet({
    required DateTime from,
    required DateTime to,
    String scope = 'fleet',
  }) async {
    final c = _maybe();
    if (c == null) {
      return const FleetAnalytics(
        loads: 0,
        miles: 0,
        revenue: 0,
        cost: 0,
        avgPpm: 0,
        onTimePct: 0,
        series: [],
      );
    }
    final rowsDyn = await c
        .from('analytics_snapshots')
        .select()
        .gte('date_bucket', _isoDate(from))
        .lte('date_bucket', _isoDate(to))
        .eq('scope', scope)
        .order('date_bucket');
    final rows = (rowsDyn as List).cast<Map<String, dynamic>>();
    int loads = 0;
    double miles = 0;
    double revenue = 0;
    double cost = 0;
    double ppmSum = 0;
    double onTimeSum = 0;
    final pts = <FleetKpisSeriesPoint>[];
    for (final r in rows) {
      final l = (r['total_loads'] as int?) ?? 0;
      final m = ((r['total_miles'] as num?) ?? 0).toDouble();
      final rev = ((r['revenue_usd'] as num?) ?? 0).toDouble();
      final cst = ((r['cost_usd'] as num?) ?? 0).toDouble();
      final ppm = ((r['avg_ppm'] as num?) ?? 0).toDouble();
      final otp = ((r['on_time_pct'] as num?) ?? 0).toDouble();
      loads += l;
      miles += m;
      revenue += rev;
      cost += cst;
      ppmSum += ppm;
      onTimeSum += otp;
      pts.add(
        FleetKpisSeriesPoint(
          date: DateTime.parse(r['date_bucket'] as String),
          loads: l,
          miles: m,
          avgPpm: ppm,
          onTimePct: otp,
        ),
      );
    }
    final n = rows.isEmpty ? 1 : rows.length;
    return FleetAnalytics(
      loads: loads,
      miles: miles,
      revenue: revenue,
      cost: cost,
      avgPpm: n == 0 ? 0 : ppmSum / n,
      onTimePct: n == 0 ? 0 : onTimeSum / n,
      series: pts,
    );
  }

  Future<String> exportCsv({
    required DateTime from,
    required DateTime to,
    String scope = 'fleet',
  }) async {
    final a = await getFleet(from: from, to: to, scope: scope);
    final header = 'Date,Loads,Miles,Avg PPM,On-time %';
    final lines = <String>[header];
    for (final p in a.series) {
      lines.add(
        '${_isoDate(p.date)},${p.loads},${p.miles.toStringAsFixed(1)},${p.avgPpm.toStringAsFixed(4)},${p.onTimePct.toStringAsFixed(2)}',
      );
    }
    return const LineSplitter().convert(lines.join('\n')).join('\n');
  }

  String _isoDate(DateTime d) => d.toUtc().toIso8601String().split('T').first;
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref),
);
