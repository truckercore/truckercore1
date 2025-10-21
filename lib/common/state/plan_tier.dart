import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum PlanTier { free, pro, premium }

PlanTier _parseTier(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'pro':
      return PlanTier.pro;
    case 'premium':
      return PlanTier.premium;
    default:
      return PlanTier.free;
  }
}

final planTierProvider = Provider<PlanTier>((ref) {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    // Try claims from appMetadata or decode token payload
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    Map<String, dynamic>? claims;
    final meta = user?.appMetadata;
    if (meta is Map) {
      final m = meta as Map;
      if (m['claims'] is Map) {
        claims = Map<String, dynamic>.from(m['claims'] as Map);
      }
    }
    if (claims == null && token is String && token.split('.').length == 3) {
      final payload = token.split('.')[1];
      final decoded = utf8.decode(base64.decode(base64.normalize(payload)));
      claims = jsonDecode(decoded) as Map<String, dynamic>;
    }
    final tier = _parseTier(claims?['plan_tier']?.toString());
    return tier;
  } catch (_) {
    return PlanTier.free;
  }
});
