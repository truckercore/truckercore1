// lib/services/feature_flags.dart
// Helper for toggling feature flags directly by flag_key or via compatibility view.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Toggle the ranker freshness penalties via direct upsert to feature_flags
Future<void> setRankerPenaltiesEnabled(bool enabled) async {
  await Supabase.instance.client
      .from('feature_flags')
      .upsert({'flag_key': 'ranker_freshness_penalties', 'enabled': enabled});
}

/// Optional compatibility read via a view that exposes key,enabled
Future<List<Map<String, dynamic>>> readFlagsFromView() async {
  final rows = await Supabase.instance.client
      .from('v_feature_flags') // SELECT flag_key AS key, enabled
      .select('key, enabled');
  return (rows as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}
