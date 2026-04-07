import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/config/app_config.dart';
import '../../../services/supa_client.dart';

class BidAssistRequest {
  final String origin;
  final String destination;
  final String equipment;
  final String pickupAt; // ISO8601 UTC
  final double? deadheadMiles;
  final List<String>? driverIds;
  final String? loadId;
  final Map<String, dynamic>? context;
  const BidAssistRequest({
    required this.origin,
    required this.destination,
    required this.equipment,
    required this.pickupAt,
    this.deadheadMiles,
    this.driverIds,
    this.loadId,
    this.context,
  });
  Map<String, dynamic> toJson() => {
    'origin': origin,
    'destination': destination,
    'equipment': equipment,
    'pickupAt': pickupAt,
    if (deadheadMiles != null) 'deadheadMiles': deadheadMiles,
    if (driverIds != null) 'driverIds': driverIds,
    if (loadId != null) 'loadId': loadId,
    if (context != null) 'context': context,
  };
}

class BidAssistResult {
  final Map<String, dynamic> band; // {p50Usd, p80Usd, confidence, isStale, asOf}
  final Map<String, dynamic> feasibility; // {eta, onTime, blockingReason?}
  final double suggestedBidUsd;
  final List<String> explanations;
  final String auditId;
  const BidAssistResult({
    required this.band,
    required this.feasibility,
    required this.suggestedBidUsd,
    required this.explanations,
    required this.auditId,
  });
}

class BidAssistService {
  final AppConfig config;
  final SupaClient? http;
  const BidAssistService({required this.config, this.http});

  Future<BidAssistResult> suggest(BidAssistRequest req) async {
    if (config.useMockData || http == null) {
      final now = DateTime.now().toUtc();
      final p50 = 1200.0;
      final p80 = 1400.0;
      return BidAssistResult(
        band: {
          'p50Usd': p50,
          'p80Usd': p80,
          'confidence': 'low',
          'isStale': true,
          'asOf': now.toIso8601String(),
        },
        feasibility: {
          'eta': now.add(const Duration(hours: 12)).toIso8601String(),
          'onTime': true,
        },
        suggestedBidUsd: 1300.0,
        explanations: const [
          'Mock: lane baseline (p50) + adjustments',
          'Mock: service window feasible',
        ],
        auditId: 'mock-audit',
      );
    }
    final body = req.toJson();
    final res = await http!.postJson('/functions/v1/bid_assist', body, maxRetries: 2);
    final band = Map<String, dynamic>.from(res['band'] as Map);
    final feas = Map<String, dynamic>.from(res['feasibility'] as Map);
    final expl = (res['explanations'] as List).cast<String>();
    final suggested = (res['suggestedBidUsd'] as num).toDouble();
    final auditId = (res['auditId'] ?? '') as String;
    return BidAssistResult(
      band: band,
      feasibility: feas,
      suggestedBidUsd: suggested,
      explanations: expl,
      auditId: auditId,
    );
  }

  Future<void> publishBidAssistEvent(Map<String, dynamic> payload) async {
    if (config.useMockData || http == null) return; // no-op in mock
    await http!.postJson('/api/bid-assist-log', payload, maxRetries: 2);
  }

  Future<void> logApply({required String auditId, required String? loadId, required double acceptedBidUsd}) async {
    await publishBidAssistEvent({
      'auditId': auditId,
      'loadId': loadId,
      'acceptedBidUsd': acceptedBidUsd,
      'action': 'apply',
    });
  }
}

final bidAssistServiceProvider = Provider<BidAssistService>((ref){
  final cfg = ref.watch(appConfigProvider);
  if (cfg.useMockData || cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
    return BidAssistService(config: cfg);
  }
  final http = SupaClient(supabaseUrl: cfg.supabaseUrl, anonKey: cfg.supabaseAnonKey);
  return BidAssistService(config: cfg, http: http);
});
