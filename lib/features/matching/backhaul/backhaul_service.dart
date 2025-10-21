// lib/features/matching/backhaul/backhaul_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/config/app_config.dart';

class BackhaulItem {
  final String loadId;
  final String origin;
  final String dest;
  final double cpmEst;
  final double deadheadMi;
  final bool etaFit;
  final double incrementalCph;
  final List<String> explain;
  const BackhaulItem({
    required this.loadId,
    required this.origin,
    required this.dest,
    required this.cpmEst,
    required this.deadheadMi,
    required this.etaFit,
    required this.incrementalCph,
    required this.explain,
  });
}

class BackhaulService {
  final AppConfig cfg;
  const BackhaulService(this.cfg);

  Future<List<BackhaulItem>> suggest({
    required String userId,
    required String currentLoadId,
    required double dropoffLat,
    required double dropoffLng,
    required DateTime dropoffEta,
    String? equipment,
    int timeWindowHr = 24,
    int searchRadiusMi = 100,
  }) async {
    if (cfg.useMockData || cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
      return const [
        BackhaulItem(
          loadId: 'mock-next-1', origin: 'Nearby, IL', dest: 'Columbus, OH', cpmEst: 2.35, deadheadMi: 28, etaFit: true, incrementalCph: 76, explain: ['28 mi deadhead','~\$2.35/mi','Incremental CPH ~\$76']
        ),
        BackhaulItem(
          loadId: 'mock-next-2', origin: 'Nearfield, IN', dest: 'Pittsburgh, PA', cpmEst: 2.15, deadheadMi: 40, etaFit: true, incrementalCph: 65, explain: ['40 mi deadhead','~\$2.15/mi','Incremental CPH ~\$65']
        ),
      ];
    }
    final client = Supabase.instance.client;
    final payload = {
      'current_load_id': currentLoadId,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'dropoff_eta': dropoffEta.toUtc().toIso8601String(),
      'equipment': equipment,
      'time_window_hr': timeWindowHr,
      'search_radius_mi': searchRadiusMi,
      'user_id': userId,
    };
    final resp = await client.functions.invoke('backhaul_recs', body: payload);
    final data = Map<String, dynamic>.from(resp.data as Map);
    final items = (data['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) => BackhaulItem(
              loadId: (m['load_id'] ?? '').toString(),
              origin: (m['origin'] ?? '').toString(),
              dest: (m['dest'] ?? '').toString(),
              cpmEst: (m['cpm_est'] as num? ?? 0).toDouble(),
              deadheadMi: (m['deadhead_mi'] as num? ?? 0).toDouble(),
              etaFit: m['eta_fit'] as bool? ?? false,
              incrementalCph: (m['incremental_cph'] as num? ?? 0).toDouble(),
              explain: (m['explain'] as List? ?? const []).map((x) => x.toString()).toList(),
            ))
        .toList();
    return items;
  }
}

final backhaulServiceProvider = Provider<BackhaulService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return BackhaulService(cfg);
});
