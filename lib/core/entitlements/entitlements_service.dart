import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppRole { driver, ownerOperator, unknown }
enum AppTier { basic, standard, premium, enterprise }

class Entitlements with ChangeNotifier {
  AppRole role = AppRole.unknown;
  AppTier tier = AppTier.basic;
  bool isPremium = false;
  bool legalVerified = false;

  void set({
    AppRole? role,
    AppTier? tier,
    bool? isPremium,
    bool? legalVerified,
  }) {
    if (role != null) this.role = role;
    if (tier != null) this.tier = tier;
    if (isPremium != null) this.isPremium = isPremium;
    if (legalVerified != null) this.legalVerified = legalVerified;
    notifyListeners();
  }
}

class EntitlementsService {
  final SupabaseClient _sb;
  final entitlements = Entitlements();
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  EntitlementsService(this._sb);

  Future<void> init() async {
    await _loadOnce();
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    _sub = _sb
        .from('driver_profiles')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .listen((rows) {
      if (rows.isNotEmpty) _hydrate(rows.first);
    });
  }

  Future<void> _loadOnce() async {
    final uid = _sb.auth.currentUser?.id;
    if (uid == null) return;
    final resp = await _sb
        .from('driver_profiles')
        .select('premium')
        .eq('user_id', uid)
        .maybeSingle();
    final user = _sb.auth.currentUser;
    final meta = user?.userMetadata ?? <String, dynamic>{};
    final roleClaim = (meta['primary_role'] ?? meta['app_role'] ?? '') as String? ?? '';
    final tierClaim = (meta['app_tier'] ?? '') as String? ?? '';
    final legal = (meta['legal_verified'] == true) || (meta['dot_verified'] == true);

    final role = switch (roleClaim) {
      'driver' => AppRole.driver,
      'owner_operator' => AppRole.ownerOperator,
      _ => AppRole.unknown
    };
    final tier = switch (tierClaim) {
      'standard' => AppTier.standard,
      'premium' => AppTier.premium,
      'enterprise' => AppTier.enterprise,
      _ => AppTier.basic
    };
    final isPremium = (resp?['premium'] == true) || tier == AppTier.premium || tier == AppTier.enterprise;

    entitlements.set(role: role, tier: tier, isPremium: isPremium, legalVerified: legal);
  }

  void _hydrate(Map<String, dynamic> row) {
    final user = _sb.auth.currentUser;
    final meta = user?.userMetadata ?? <String, dynamic>{};
    final roleClaim = (meta['primary_role'] ?? meta['app_role'] ?? '') as String? ?? '';
    final tierClaim = (meta['app_tier'] ?? '') as String? ?? '';
    final role = switch (roleClaim) {
      'driver' => AppRole.driver,
      'owner_operator' => AppRole.ownerOperator,
      _ => AppRole.unknown
    };
    final tier = switch (tierClaim) {
      'standard' => AppTier.standard,
      'premium' => AppTier.premium,
      'enterprise' => AppTier.enterprise,
      _ => AppTier.basic
    };
    final isPremium = (row['premium'] == true) || tier == AppTier.premium || tier == AppTier.enterprise;
    final legal = (meta['legal_verified'] == true) || (meta['dot_verified'] == true);

    entitlements.set(role: role, tier: tier, isPremium: isPremium, legalVerified: legal);
  }

  void dispose() => _sub?.cancel();
}
