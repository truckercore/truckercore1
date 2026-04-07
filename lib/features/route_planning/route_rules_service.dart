// lib/features/route_planning/route_rules_service.dart
// Loads route rules for a region and aggregates provider segment IDs to avoid.

import 'package:supabase_flutter/supabase_flutter.dart';

class RouteRulesService {
  static Future<Set<String>> loadAvoidSegmentsForRegion(String region) async {
    final sb = Supabase.instance.client;
    final res = await sb.rpc('fn_load_route_rules', params: {'p_region': region});
    final rows = (res as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final set = <String>{};
    for (final r in rows) {
      final arr = (r['avoid_segments'] as List?)?.cast<dynamic>() ?? const [];
      for (final v in arr) {
        final s = v?.toString();
        if (s != null && s.isNotEmpty) set.add(s);
      }
    }
    return set;
  }
}
