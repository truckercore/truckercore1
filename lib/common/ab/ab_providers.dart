// lib/common/ab/ab_providers.dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cohort assignment: simple 50/50 in staging/dev; sticky via SharedPreferences.
final abCohortProvider = FutureProvider<String>((ref) async {
  final sp = await SharedPreferences.getInstance();
  final existing = sp.getString('ab_cohort_v1');
  if (existing != null) return existing;
  final r = (math.Random().nextDouble() < 0.5) ? 'A' : 'B';
  await sp.setString('ab_cohort_v1', r);
  return r;
});

/// Minimal metrics emitter (no-PII). You can hook to Sentry or Supabase functions.
class AbMetrics {
  AbMetrics(this.ref);
  final Ref ref;

  Future<void> emit(String name, Map<String, Object?> data) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[ab_metric] $name $data');
    }
    // Optionally send to backend via functions.invoke('ab_metrics', body: {...})
  }
}

final abMetricsProvider = Provider<AbMetrics>((ref) => AbMetrics(ref));
