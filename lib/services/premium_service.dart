// lib/services/premium_service.dart
// Premium gating helpers: isPremium(), startTrialAndRefresh(), and a light BillingService wrapper.

import 'package:supabase_flutter/supabase_flutter.dart';

final _sb = Supabase.instance.client;

/// Returns true if the current user has premium access (trial active or paid plan).
Future<bool> isPremium() async {
  try {
    final result = await _sb.rpc('is_premium');
    // Expecting a boolean from the RPC; be defensive about types.
    if (result is bool) return result;
    if (result is num) return result != 0;
    if (result is Map && result['is_premium'] is bool) return result['is_premium'] as bool;
    return false;
  } on PostgrestException catch (_) {
    // Treat RPC failure as not premium; UI will show upsell.
    return false;
  } catch (_) {
    return false;
  }
}

/// Starts a free trial by calling start_free_trial(days int) and refreshes the session
/// so any JWT-backed UI gates can update without a full re-login.
/// Throws an Exception('TRIAL_ALREADY_USED') when back-end returns a specific error.
Future<void> startTrialAndRefresh({int days = 7}) async {
  try {
    await _sb.rpc('start_free_trial', params: {'days': days});
  } on PostgrestException catch (e) {
    final msg = e.message.toUpperCase();
    if (msg.contains('TRIAL_ALREADY_USED')) {
      throw Exception('TRIAL_ALREADY_USED');
    }
    throw Exception(e.message);
  } catch (e) {
    throw Exception(e.toString());
  }
  // Refresh session so app_metadata or DB-driven flags reflect immediately
  try {
    await _sb.auth.refreshSession();
  } catch (_) {
    // ignore
  }
}

class BillingService {
  Future<void> startTrial({int days = 7}) => startTrialAndRefresh(days: days);

  Future<void> upgradeToPro() async {
    // Wire your create_checkout_session call here if desired.
    // See lib/services/billing.dart for helpers.
    throw UnimplementedError('Wire upgrade here via create_checkout_session');
  }
}
