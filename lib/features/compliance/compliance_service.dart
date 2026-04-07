// lib/features/compliance/compliance_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class ComplianceCandidate {
  final String loadId;
  final DateTime? pickupAt;
  final DateTime? dropoffAt;
  final Map<String, dynamic>? origin; // {lat,lng}
  final Map<String, dynamic>? dest;   // {lat,lng}
  final String? equipment;
  final int? weightLb;
  final bool? hazmat;
  const ComplianceCandidate({required this.loadId, this.pickupAt, this.dropoffAt, this.origin, this.dest, this.equipment, this.weightLb, this.hazmat});
  Map<String, dynamic> toJson() => {
    'load_id': loadId,
    if (pickupAt != null) 'pickup_at': pickupAt!.toUtc().toIso8601String(),
    if (dropoffAt != null) 'dropoff_at': dropoffAt!.toUtc().toIso8601String(),
    if (origin != null) 'origin': origin,
    if (dest != null) 'dest': dest,
    if (equipment != null) 'equipment': equipment,
    if (weightLb != null) 'weight_lb': weightLb,
    if (hazmat != null) 'hazmat': hazmat,
  };
}

class ComplianceResult {
  final String status; // pass|adjusted|blocked
  final List<String> reasons;
  final Map<String, dynamic> adjustments;
  const ComplianceResult({required this.status, required this.reasons, required this.adjustments});
}

class ComplianceService {
  final AppConfig cfg;
  const ComplianceService(this.cfg);

  Future<ComplianceResult> validate({required ComplianceCandidate candidate, Map<String, dynamic>? context}) async {
    if (cfg.useMockData) {
      return const ComplianceResult(status: 'pass', reasons: [], adjustments: {});
    }
    final client = Supabase.instance.client;
    final body = {
      'candidate': candidate.toJson(),
      if (context != null) 'context': context,
    };
    final resp = await client.functions.invoke('compliance_validator', body: body);
    final data = Map<String, dynamic>.from(resp.data as Map);
    return ComplianceResult(
      status: data['status']?.toString() ?? 'pass',
      reasons: (data['reasons'] as List? ?? const []).map((e) => e.toString()).toList(),
      adjustments: Map<String, dynamic>.from((data['adjustments'] as Map?) ?? const {}),
    );
  }
}

final complianceServiceProvider = Provider<ComplianceService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return ComplianceService(cfg);
});
