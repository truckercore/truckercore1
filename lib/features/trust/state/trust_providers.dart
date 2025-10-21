// lib/features/trust/state/trust_providers.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/flags/rollout_flags.dart';
import '../../../core/supabase/supabase_factory.dart';

final brokerTrustProvider = FutureProvider.family<int?, String>((ref, brokerId) async {
  final flags = ref.watch(rolloutFlagsProvider);
  if (!flags.explainabilityChipsEnabled) {
    // Trust chip is gated by broker_trust_v1 ideally, but reuse explainability if broker flag missing
    return null;
  }
  final factory = ref.read(supabaseFactoryProvider);
  final client = factory.maybeClient;
  if (client == null) return null;
  try {
    final res = await client.functions.invoke('broker_trust_v1', body: jsonEncode({'broker_id': brokerId}), headers: {'Content-Type': 'application/json'});
    final data = res.data;
    if (data is Map && data['trust'] is num) return (data['trust'] as num).toInt();
    if (data is String) {
      final j = jsonDecode(data);
      if (j is Map && j['trust'] is num) return (j['trust'] as num).toInt();
    }
  } catch (_) {}
  return null;
});
