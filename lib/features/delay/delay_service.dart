// lib/features/delay/delay_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class DelayResult {
  final double onTimeProb;
  final List<String> lateRiskReasons;
  final List<String> mitigations;
  const DelayResult({required this.onTimeProb, required this.lateRiskReasons, required this.mitigations});
}

class DelayService {
  final AppConfig cfg;
  const DelayService(this.cfg);

  Future<DelayResult> predict({
    required Map<String, double> origin,
    required Map<String, double> dest,
    required DateTime etaPlan,
    String? equipment,
    Map<String, dynamic>? context,
  }) async {
    if (cfg.useMockData) {
      return const DelayResult(onTimeProb: 0.71, lateRiskReasons: ['I-80 congestion','Facility dwell P80 78m'], mitigations: ['Leave 45m earlier','Request alternate dock window']);
    }
    final client = Supabase.instance.client;
    final body = {
      'route': {
        'origin': origin,
        'dest': dest,
      },
      'eta_plan': etaPlan.toUtc().toIso8601String(),
      if (equipment != null) 'equipment': equipment,
      if (context != null) 'context': context,
    };
    final resp = await client.functions.invoke('delay_predictor', body: body);
    final data = Map<String, dynamic>.from(resp.data as Map);
    return DelayResult(
      onTimeProb: (data['on_time_prob'] as num).toDouble(),
      lateRiskReasons: (data['late_risk_reason'] as List? ?? const []).map((e) => e.toString()).toList(),
      mitigations: (data['mitigations'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

final delayServiceProvider = Provider<DelayService>((ref){
  final cfg = ref.watch(appConfigProvider);
  return DelayService(cfg);
});
