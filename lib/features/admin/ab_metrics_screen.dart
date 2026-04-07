// lib/features/admin/ab_metrics_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class AbMetric {
  final DateTime day;
  final String experiment;
  final String variant;
  final int views;
  final int requests;
  final double p95LatencyMs;
  AbMetric({required this.day, required this.experiment, required this.variant, required this.views, required this.requests, required this.p95LatencyMs});
}

class AbMetricsService {
  final AppConfig cfg;
  const AbMetricsService(this.cfg);
  Future<List<AbMetric>> listDaily({int days = 14}) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return const [];
    final c = Supabase.instance.client;
    try {
      final rows = await c.from('ab_metrics_daily').select().order('day', ascending: false).limit(60);
      final list = (rows as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => AbMetric(
                day: DateTime.tryParse(m['day']?.toString() ?? '') ?? DateTime.now(),
                experiment: (m['experiment_key'] ?? '').toString(),
                variant: (m['variant_key'] ?? '').toString(),
                views: (m['views'] as int?) ?? 0,
                requests: (m['requests'] as int?) ?? 0,
                p95LatencyMs: (m['p95_latency_ms'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
      return list;
    } catch (_) {
      return const [];
    }
  }
}

final abMetricsServiceProvider = Provider<AbMetricsService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return AbMetricsService(cfg);
});

class AbMetricsScreen extends ConsumerWidget {
  const AbMetricsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(abMetricsServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('A/B Metrics (ranker_v1)')),
      body: SafeArea(
        child: FutureBuilder<List<AbMetric>>(
          future: svc.listDaily(),
          builder: (ctx, snap) {
            final list = snap.data ?? const <AbMetric>[];
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (list.isEmpty) return const Center(child: Text('No metrics'));
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = list[i];
                final rr = m.views == 0 ? 0 : (m.requests / m.views) * 100;
                return ListTile(
                  title: Text('${m.experiment} • ${m.variant} • ${m.day.toLocal().toString().substring(0,10)}'),
                  subtitle: Text('views=${m.views} • requests=${m.requests} • req_rate=${rr.toStringAsFixed(1)}% • p95=${m.p95LatencyMs.toStringAsFixed(0)} ms'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
