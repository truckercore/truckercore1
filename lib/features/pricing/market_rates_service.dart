import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';
import '../../common/state/phase2_flags.dart';
import '../../common/state/plan_tier.dart';

class LaneRatePoint {
  final DateTime t;
  final double spot;
  final double contract;
  const LaneRatePoint(this.t, this.spot, this.contract);
}

class LaneRateSeries {
  final String laneKey; // zip->zip
  final double latestSpot;
  final double latestContract;
  final int sampleSize;
  final List<LaneRatePoint> series; // normalized to daily points within window
  final double? yourAvg; // optional (org private)
  const LaneRateSeries({
    required this.laneKey,
    required this.latestSpot,
    required this.latestContract,
    required this.sampleSize,
    required this.series,
    this.yourAvg,
  });
}

class MarketRatesService {
  MarketRatesService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  String _laneKey(String originZip, String destZip) =>
      '${originZip.trim()}->${destZip.trim()}';

  // windowDays e.g., 90
  Future<LaneRateSeries> getLaneRates({
    required String originZip,
    required String destZip,
    int windowDays = 90,
  }) async {
    // Phase 2 mock and gating
    final flags = _ref.read(phase2FlagsProvider);
    if (flags.mock) {
      // Feature flag off? Return 404-like by throwing
      if (!flags.marketRates) {
        throw Exception('404: Market rates API disabled');
      }
      // Validate zips (5 digits)
      bool validZip(String z) {
        if (z.length != 5) return false;
        for (int i = 0; i < 5; i++) {
          final c = z.codeUnitAt(i);
          if (c < 48 || c > 57) return false;
        }
        return true;
      }

      if (!validZip(originZip) || !validZip(destZip)) {
        throw Exception('400: Invalid ZIPs');
      }
      // Plan gating
      final plan = _ref.read(planTierProvider);
      if (plan == PlanTier.free) {
        throw Exception('403: plan_tier < pro');
      }
      // Return static payload as series of 3 points with the specified current values
      final laneKey = _laneKey(originZip, destZip);
      final series = <LaneRatePoint>[
        LaneRatePoint(DateTime.parse('2025-06-01T00:00:00Z'), 2.18, 1.98),
        LaneRatePoint(DateTime.parse('2025-07-01T00:00:00Z'), 2.21, 1.99),
        LaneRatePoint(DateTime.parse('2025-08-01T00:00:00Z'), 2.25, 2.00),
      ];
      return LaneRateSeries(
        laneKey: laneKey,
        latestSpot: 2.25,
        latestContract: 2.00,
        sampleSize: 184,
        series: series,
      );
    }
    final c = _maybe();
    if (c == null) {
      // offline/demo fallback: generate a plausible series
      return _demoSeries(originZip, destZip, windowDays);
    }
    final laneKey = _laneKey(originZip, destZip);
    final since = DateTime.now().toUtc().subtract(Duration(days: windowDays));
    final rows = await c
        .from('market_rates')
        .select(
          'spot_rate_usd_per_mi, contract_rate_usd_per_mi, sample_size, collected_at, source',
        )
        .eq('lane_key', laneKey)
        .gte('collected_at', since.toIso8601String())
        .order('collected_at', ascending: true);
    final list = (rows as List?) ?? const [];
    if (list.isEmpty) {
      return _demoSeries(originZip, destZip, windowDays);
    }
    final points = <LaneRatePoint>[];
    int sample = 0;
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      final t =
          DateTime.tryParse(m['collected_at']?.toString() ?? '') ??
          DateTime.now().toUtc();
      final spot = (m['spot_rate_usd_per_mi'] as num?)?.toDouble() ?? 0.0;
      final contract =
          (m['contract_rate_usd_per_mi'] as num?)?.toDouble() ?? 0.0;
      sample = max(sample, (m['sample_size'] as int?) ?? 0);
      points.add(LaneRatePoint(t, spot, contract));
    }
    final latest = points.isNotEmpty
        ? points.last
        : LaneRatePoint(DateTime.now().toUtc(), 0, 0);
    // Optionally fetch org private "your avg" via RPC if available
    double? yourAvg;
    try {
      final rpc = await c.rpc(
        'fn_org_lane_avg_rate',
        params: {'p_lane_key': laneKey},
      );
      if (rpc is List && rpc.isNotEmpty) {
        final mm = Map<String, dynamic>.from(rpc.first as Map);
        yourAvg = (mm['your_avg'] as num?)?.toDouble();
      }
    } catch (_) {}
    return LaneRateSeries(
      laneKey: laneKey,
      latestSpot: latest.spot,
      latestContract: latest.contract,
      sampleSize: sample,
      series: points,
      yourAvg: yourAvg,
    );
  }

  LaneRateSeries _demoSeries(String oz, String dz, int days) {
    final laneKey = _laneKey(oz, dz);
    final rnd = Random(laneKey.hashCode);
    final base = 2.2 + rnd.nextDouble() * 0.6; // $/mi
    final contract = base - 0.2 + rnd.nextDouble() * 0.2;
    final points = <LaneRatePoint>[];
    double curS = base;
    double curC = contract;
    for (int i = days; i >= 0; i--) {
      final t = DateTime.now().toUtc().subtract(Duration(days: i));
      // random walk
      curS += (rnd.nextDouble() - 0.5) * 0.04;
      curC += (rnd.nextDouble() - 0.5) * 0.02;
      curS = curS.clamp(1.5, 3.5);
      curC = curC.clamp(1.3, 3.0);
      points.add(LaneRatePoint(t, curS, curC));
    }
    final latest = points.last;
    return LaneRateSeries(
      laneKey: laneKey,
      latestSpot: latest.spot,
      latestContract: latest.contract,
      sampleSize: 120 + rnd.nextInt(200),
      series: points,
    );
  }
}

final marketRatesServiceProvider = Provider<MarketRatesService>(
  (ref) => MarketRatesService(ref),
);
