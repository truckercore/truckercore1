import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/entitlements/entitlements_service.dart';

class FeatureGate extends StatelessWidget {
  final Entitlements entitlements;
  final AppTier minTier;
  final Widget child;
  final VoidCallback onUpsell;

  const FeatureGate({
    super.key,
    required this.entitlements,
    required this.minTier,
    required this.child,
    required this.onUpsell,
  });

  // Minimal static API to satisfy legacy call sites
  // Returns true if the current user is entitled to the given feature.
  // For now, we gate known features by premium tier (or enterprise).
  static Future<bool> has(String feature) async {
    try {
      final sb = Supabase.instance.client;
      final user = sb.auth.currentUser;
      final meta = user?.userMetadata ?? <String, dynamic>{};
      final tierClaim = (meta['app_tier'] ?? meta['tier'] ?? meta['app_plan'] ?? '') as String? ?? '';
      final isPremiumClaim = meta['app_is_premium'] == true || meta['is_premium'] == true;

      final tier = switch (tierClaim.toString().toLowerCase()) {
        'standard' => AppTier.standard,
        'pro' => AppTier.premium,
        'premium' => AppTier.premium,
        'enterprise' => AppTier.enterprise,
        _ => AppTier.basic,
      };

      final isPremium = isPremiumClaim || tier == AppTier.premium || tier == AppTier.enterprise;

      // Map features to minimum tier. Adjust as needed.
      final String f = feature.toLowerCase();
      final AppTier min = switch (f) {
        'ai_match' => AppTier.premium,
        'roi' => AppTier.premium,
        _ => AppTier.basic,
      };

      const rank = {
        AppTier.basic: 0,
        AppTier.standard: 1,
        AppTier.premium: 2,
        AppTier.enterprise: 3,
      };

      final userRank = isPremium ? rank[AppTier.premium]! : rank[tier]!;
      final needRank = rank[min]!;
      return userRank >= needRank;
    } catch (_) {
      // On any error, be safe and return false (feature locked)
      return false;
    }
  }

  // Minimal logging hook for paywall impressions.
  static void logPaywall(String feature) {
    // Keep it lightweight to avoid introducing analytics deps.
    // Developers can wire this up to Sentry or their analytics later.
    // ignore: avoid_print
    debugPrint('[paywall] feature="$feature"');
  }

  bool _allowed() {
    const rank = {
      AppTier.basic: 0,
      AppTier.standard: 1,
      AppTier.premium: 2,
      AppTier.enterprise: 3,
    };
    return rank[entitlements.tier]! >= rank[minTier]!;
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed()) return child;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('This feature requires a higher plan.'),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onUpsell, child: const Text('Upgrade')),
      ]),
    );
  }
}
