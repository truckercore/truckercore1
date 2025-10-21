import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

// Slugs per spec
const defaultOrgKpiOrder = <String>[
  'exceptions_now',
  'on_time_today',
  'assigned_ratio_today',
  'hos_approaching',
  'deadhead_7d',
  'vehicles_attention',
];

class KpiOrderService {
  KpiOrderService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<String>> loadOrgOrder(String orgId) async {
    try {
      final c = _maybe();
      if (c != null) {
        final row = await c
            .from('org_settings')
            .select('kpi_order')
            .eq('org_id', orgId)
            .maybeSingle();
        if (row != null && row['kpi_order'] != null) {
          final list = List<String>.from(row['kpi_order'] as List);
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {}
    // Local fallback
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('org:$orgId:kpi_order');
      if (raw != null) {
        final list = List<String>.from(jsonDecode(raw) as List);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return defaultOrgKpiOrder;
  }

  Future<void> saveOrgOrder(String orgId, List<String> order) async {
    try {
      final c = _maybe();
      if (c != null) {
        await c.from('org_settings').upsert({
          'org_id': orgId,
          'kpi_order': order,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {}
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('org:$orgId:kpi_order', jsonEncode(order));
    } catch (_) {}
  }

  Future<List<String>> loadUserOverride(String userId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('user:$userId:kpi_order_override');
      if (raw != null) {
        return List<String>.from(jsonDecode(raw) as List);
      }
    } catch (_) {}
    return const [];
  }

  Future<void> saveUserOverride(String userId, List<String> order) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('user:$userId:kpi_order_override', jsonEncode(order));
    } catch (_) {}
  }
}

final kpiOrderServiceProvider = Provider<KpiOrderService>(
  (ref) => KpiOrderService(ref),
);

class KpiCardData {
  final String slug;
  final String title;
  final String value;
  final Color? badgeColor;
  final IconData? icon; // e.g., warning icon when critical
  final String? trend; // up/down for deadhead
  const KpiCardData({
    required this.slug,
    required this.title,
    required this.value,
    this.badgeColor,
    this.icon,
    this.trend,
  });
}

// Minimal combined provider that yields ordered KPI list ready for UI
final orderedKpisProvider = FutureProvider.autoDispose<List<KpiCardData>>((
  ref,
) async {
  final orderSvc = ref.read(kpiOrderServiceProvider);
  final String orgId = 'demo_org';
  final String userId = Supabase.instance.client.auth.currentUser?.id ?? 'local_user';

  final orgOrder = await orderSvc.loadOrgOrder(orgId);
  final override = await orderSvc.loadUserOverride(userId);
  final order = override.isNotEmpty ? override : orgOrder;

  // Compute data quickly (stub values, but replace with real queries if configured)
  // For now, neutral values with appropriate badge colors per spec.
  final int exceptions = 0;
  final double onTime = 0.96; // 96%
  final int assigned = 28;
  final int total = 32;
  final int hosApproaching = 2;
  final double deadhead = 0.18; // 18%
  final double deadheadPrior = 0.22; // 22%
  final int vehiclesAttention = 1;

  final Color grey = const Color(0xFF7D8590);
  final Color amber = const Color(0xFFFFC107);
  final Color red = const Color(0xFFE53935);

  Color badgeForExceptions(int n) {
    if (n == 0) return grey;
    if (n <= 5) return amber;
    return red;
  }

  String pct(double x) => '${(x * 100).toStringAsFixed(0)}%';

  final all = <String, KpiCardData>{
    'exceptions_now': KpiCardData(
      slug: 'exceptions_now',
      title: 'Exceptions Now',
      value: '$exceptions',
      badgeColor: badgeForExceptions(exceptions),
      icon: exceptions > 0 ? Icons.warning_amber_rounded : null,
    ),
    'on_time_today': KpiCardData(
      slug: 'on_time_today',
      title: 'On-Time (Today)',
      value: pct(onTime),
      badgeColor: onTime >= 0.95 ? null : amber,
    ),
    'assigned_ratio_today': KpiCardData(
      slug: 'assigned_ratio_today',
      title: 'Assigned (24h)',
      value: '$assigned/$total',
    ),
    'hos_approaching': KpiCardData(
      slug: 'hos_approaching',
      title: 'HOS Approaching (2h)',
      value: '$hosApproaching',
      badgeColor: hosApproaching == 0 ? grey : amber,
      icon: hosApproaching > 0 ? Icons.access_time_filled : null,
    ),
    'deadhead_7d': KpiCardData(
      slug: 'deadhead_7d',
      title: 'Deadhead (7d)',
      value: pct(deadhead),
      trend: deadhead <= deadheadPrior ? 'down' : 'up',
    ),
    'vehicles_attention': KpiCardData(
      slug: 'vehicles_attention',
      title: 'Vehicles Attention',
      value: '$vehiclesAttention',
      badgeColor: vehiclesAttention == 0 ? grey : amber,
      icon: vehiclesAttention > 0 ? Icons.build_circle_outlined : null,
    ),
  };

  // Feature fallback: if maintenance module disabled, replace vehicles_attention with Fuel Spend (30d)
  // We cannot easily read feature flags here without BuildContext; use a loose dependency by reading another provider at call site if needed.

  return order
      .map((s) => all[s])
      .whereType<KpiCardData>()
      .toList(growable: false);
});
