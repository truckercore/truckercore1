// lib/services/pre_rank_validate.dart
// Robust Supabase v2 RPC usage for pre_rank_validate

import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the `pre_rank_validate` RPC.
/// The RPC returns SETOF table, so Supabase returns a List of row maps.
Future<({
  Map<String, dynamic> modified,
  bool adjustedForHos,
  List<dynamic> appliedRules,
  int auditId,
})> preRankValidate({
  required String region,
  required Map<String, dynamic> suggestion,
}) async {
  final sb = Supabase.instance.client;
  try {
    final result = await sb.rpc(
      'pre_rank_validate',
      params: {'p_region': region, 'p_suggestion': suggestion},
    );

    // pre_rank_validate returns SETOF table → Supabase returns a List
    final rows = (result as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      throw Exception('No rows returned from pre_rank_validate');
    }
    final row = rows.first;
    final modified = (row['modified'] as Map).cast<String, dynamic>();
    final adjustedForHos = row['adjusted_for_hos'] as bool? ?? false;
    final appliedRules = (row['applied_rules'] as List?) ?? const [];
    final auditId = (row['audit_id'] as num).toInt();

    return (
      modified: modified,
      adjustedForHos: adjustedForHos,
      appliedRules: appliedRules,
      auditId: auditId,
    );
  } on PostgrestException catch (e) {
    // Map to your app error layer if needed
    throw Exception('RPC error ${e.code ?? ''}: ${e.message}');
  } catch (e) {
    throw Exception('RPC failed: $e');
  }
}
