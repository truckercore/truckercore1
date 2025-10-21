// lib/core/analytics/kpi_analytics.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';
import '../ab/experiment_service.dart';

class KpiAnalytics {
  final AppConfig cfg;
  final Ref ref;
  KpiAnalytics(this.cfg, this.ref);

  Future<void> emit(String name, Map<String, dynamic> props) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[kpi] $name ${props.toString()}');
      }
      return;
    }
    try {
      final client = Supabase.instance.client;
      final a = ref.read(experimentControllerProvider).map['ranker_v1'];
      final payload = {
        'event': name,
        'props': {
          ...props,
          if (a != null) 'experiment_key': a.experimentKey,
          if (a != null) 'variant_key': a.variantKey,
        },
      };
      // Prefer an insert into a kpi_events table if present; otherwise try an RPC if you have one.
      await client.from('kpi_events').insert(payload);
    } catch (_) {
      // best-effort; ignore
    }
  }
}

final kpiAnalyticsProvider = Provider<KpiAnalytics>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return KpiAnalytics(cfg, ref);
});

/// In-memory throttle for suggestion_view events per session
final _seenSuggestions = <String>{};
void kpiMaybeEmitSuggestionView(WidgetRef ref, String loadId) {
  if (_seenSuggestions.contains(loadId)) return;
  _seenSuggestions.add(loadId);
  ref.read(kpiAnalyticsProvider).emit('suggestion_view', {'load_id': loadId});
}
