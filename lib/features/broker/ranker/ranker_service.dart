// lib/features/broker/ranker/ranker_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/config/app_config.dart';
import '../../../common/telemetry/perf_tracing.dart';
import '../../../core/analytics/kpi_analytics.dart';

class RankerItem {
  final String loadId;
  final double score;
  final Map<String, dynamic> features;
  final List<Map<String, String>> explain;
  final bool lowConfidence;
  const RankerItem({
    required this.loadId,
    required this.score,
    required this.features,
    required this.explain,
    required this.lowConfidence,
  });
}

class RankerResponse {
  final String version;
  final int tookMs;
  final bool personalized;
  final List<RankerItem> items;
  const RankerResponse({required this.version, required this.tookMs, required this.personalized, required this.items});
}

class RankerService {
  final AppConfig cfg;
  RankerService(this.cfg);

  Future<RankerResponse> rank({
    required String userId,
    Map<String, dynamic>? query,
    Map<String, dynamic>? filters,
    Map<String, dynamic>? context,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (cfg.useMockData) {
      // Minimal mock: one item with canned features
      final item = const RankerItem(
        loadId: 'mock-load-1',
        score: 0.83,
        features: {
          'cpm_est': 2.45,
          'deadhead_mi': 42,
          'duration_hr': 8.3,
          'cph_est': 78.6,
          'market_cpm_delta': 0.18,
          'on_time_prob': 0.86,
          'facility_dwell_risk': 0.22,
          'broker_trust_score': 82,
          'confidence': 0.78,
        },
        explain: [
          {'kind': 'market_delta', 'label': '+18% vs market'},
          {'kind': 'deadhead', 'label': '42 mi deadhead'},
          {'kind': 'trust', 'label': 'Broker trust 82'},
        ],
        lowConfidence: false,
      );
      return RankerResponse(version: 'v1', tookMs: 12, personalized: true, items: [item]);
    }

    final client = Supabase.instance.client;
    final payload = {
      'user_id': userId,
      if (query != null) 'query': query,
      if (filters != null) 'filters': filters,
      if (context != null) 'context': context,
    };
    final t0 = DateTime.now();
    final resp = await client.functions.invokeWithTrace('ranker_v1', action: 'ranker.search', body: payload);
    final data = Map<String, dynamic>.from(resp.data as Map);
    final tookMs = DateTime.now().difference(t0).inMilliseconds;
    final items = (data['items'] as List?)?.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final explain = (m['explain'] as List?)
              ?.map((x) => {'kind': x['kind'].toString(), 'label': x['label'].toString()})
              .toList() ??
          const <Map<String, String>>[];
      return RankerItem(
        loadId: m['load_id'].toString(),
        score: (m['score'] as num).toDouble(),
        features: Map<String, dynamic>.from(m['features'] as Map),
        explain: explain,
        lowConfidence: (m['low_confidence'] as bool?) ?? false,
      );
    }).toList() ??
        const <RankerItem>[];
    // Emit latency KPI
    try {
      final ref = _kpiRef; // see static hook below
      ref?.read(kpiAnalyticsProvider).emit('latency', {
        'component': 'ranker_v1',
        'value_ms': tookMs,
      });
    } catch (_) {}
    return RankerResponse(
      version: data['version']?.toString() ?? 'v1',
      tookMs: (data['took_ms'] as num? ?? tookMs).toInt(),
      personalized: data['personalized'] as bool? ?? false,
      items: items,
    );
  }
}

// Provide a backdoor to access ref for analytics without threading through API
// Warning: this is a minimal hook for this sprint; consider refactoring later.
WidgetRef? _kpiRef;
void rankerBindRef(WidgetRef ref) { _kpiRef = ref; }

final rankerServiceProvider = Provider<RankerService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return RankerService(cfg);
});
