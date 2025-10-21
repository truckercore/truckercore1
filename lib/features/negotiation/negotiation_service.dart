// lib/features/negotiation/negotiation_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class NegotiationAdvice {
  final double recommendedCpm;
  final double likelihood;
  final double min;
  final double max;
  final List<String> rationale;
  final String template;
  const NegotiationAdvice({required this.recommendedCpm, required this.likelihood, required this.min, required this.max, required this.rationale, required this.template});
}

class NegotiationService {
  final AppConfig cfg;
  const NegotiationService(this.cfg);

  Future<NegotiationAdvice> recommend({
    required String loadId,
    required String origin,
    required String dest,
    required String equipment,
    required double currentOfferCpm,
    required String brokerId,
    required String userId,
    required Map<String, dynamic> context,
  }) async {
    if (cfg.useMockData) {
      return const NegotiationAdvice(recommendedCpm: 2.55, likelihood: 0.62, min: 2.3, max: 2.85, rationale: ['+18% vs market OK', 'Broker trust high', 'Seasonality peak'], template: 'Hi {{broker}}, we can do {{rate}} CPM with pickup {{window}}. On-time {{on_time_prob}}%. Thanks!');
    }
    final client = Supabase.instance.client;
    final body = {
      'load_id': loadId,
      'lane': {'origin': origin, 'dest': dest},
      'equipment': equipment,
      'current_offer_cpm': currentOfferCpm,
      'broker_id': brokerId,
      'user_id': userId,
      'context': context,
    };
    final resp = await client.functions.invoke('negotiation_assistant', body: body);
    final data = Map<String, dynamic>.from(resp.data as Map);
    final bounds = Map<String, dynamic>.from((data['bounds'] as Map?) ?? const {});
    return NegotiationAdvice(
      recommendedCpm: (data['recommended_cpm'] as num).toDouble(),
      likelihood: (data['likelihood'] as num).toDouble(),
      min: (bounds['min'] as num?)?.toDouble() ?? 0,
      max: (bounds['max'] as num?)?.toDouble() ?? 0,
      rationale: (data['rationale'] as List? ?? const []).map((e) => e.toString()).toList(),
      template: data['template']?.toString() ?? '',
    );
  }
}

final negotiationServiceProvider = Provider<NegotiationService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return NegotiationService(cfg);
});
