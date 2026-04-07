import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';
import '../../common/state/phase2_flags.dart';
import '../../common/state/plan_tier.dart';

class BrokerCreditProfile {
  final String brokerId;
  final int score; // 0-100
  final int daysToPayAvg;
  final int disputes90d;
  BrokerCreditProfile({
    required this.brokerId,
    required this.score,
    required this.daysToPayAvg,
    required this.disputes90d,
  });
  String get letterBadge {
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 55) return 'C';
    return 'D';
  }
}

class CreditService {
  CreditService(this._ref);
  final Ref _ref;
  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<BrokerCreditProfile?> getBrokerCredit(String brokerId) async {
    final flags = _ref.read(phase2FlagsProvider);
    if (flags.mock) {
      // deterministic by last char
      int score;
      int days;
      int disputes;
      final last = brokerId.isEmpty ? 'x' : brokerId[brokerId.length - 1];
      if (last == 'a' || last == 'A') {
        score = 86;
        days = 26;
        disputes = 1;
      } else if (last == 'b' || last == 'B') {
        score = 72;
        days = 35;
        disputes = 3;
      } else {
        score = 80;
        days = 30;
        disputes = 2;
      }
      // Credit feature flag off? Return null to simulate hidden details
      if (!flags.brokerCredit) return null;
      // Gating: details require plan >= pro. Badges can exist in UI regardless.
      final plan = _ref.read(planTierProvider);
      if (plan == PlanTier.free) {
        // Return minimal badge-level data as if only badge is shown
        return BrokerCreditProfile(
          brokerId: brokerId,
          score: score,
          daysToPayAvg: days,
          disputes90d: disputes,
        );
      }
      return BrokerCreditProfile(
        brokerId: brokerId,
        score: score,
        daysToPayAvg: days,
        disputes90d: disputes,
      );
    }
    final c = _maybe();
    if (c == null) return null;
    final row = await c
        .from('broker_credit_scores')
        .select()
        .eq('broker_id', brokerId)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row as Map);
    return BrokerCreditProfile(
      brokerId: brokerId,
      score: (m['score'] as num).toInt(),
      daysToPayAvg: (m['days_to_pay_avg'] as num).toInt(),
      disputes90d: (m['disputes_90d'] as num).toInt(),
    );
  }
}

final creditServiceProvider = Provider<CreditService>(
  (ref) => CreditService(ref),
);
