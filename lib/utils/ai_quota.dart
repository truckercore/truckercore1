// AI quota helper
// Provides a client-side check via RPC before invoking AI-heavy operations.

import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool> aiCheckAndConsume({
  required String orgId,
  required int reqInc,
  required int costIncCents,
}) async {
  final c = Supabase.instance.client;
  final now = DateTime.now();
  final periodStart = DateTime(now.year, now.month)
      .toIso8601String()
      .split('T')
      .first; // yyyy-mm-dd
  final res = await c.rpc('fn_ai_check_and_consume', params: {
    'p_org_id': orgId,
    'p_period_start': periodStart,
    'p_req_inc': reqInc,
    'p_cost_inc_cents': costIncCents,
  });
  if (res.error != null) throw Exception(res.error!.message);
  final rows = res.data as List<dynamic>? ?? const [];
  if (rows.isEmpty) return false;
  final exceeded = rows[0]['exceeded'] as bool? ?? false;
  return !exceeded;
}
