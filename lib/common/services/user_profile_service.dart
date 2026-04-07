import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/app_role.dart';

class UserProfile {
  final String id; // auth user id
  final AppRole role;
  final bool isPremium;

  const UserProfile({
    required this.id,
    required this.role,
    required this.isPremium,
  });

  static AppRole _fromString(String v) {
    final s = v.trim();
    final lower = s.toLowerCase();
    switch (lower) {
      case 'driver':
        return AppRole.driver;
      case 'fleetmanager':
      case 'fleet_manager':
        return AppRole.fleetManager;
      case 'owneroperator':
      case 'owner_operator':
        return AppRole.ownerOperator;
      case 'broker':
        return AppRole.broker;
      default:
        // Try exact camelCase fallbacks just in case
        switch (s) {
          case 'fleetManager':
            return AppRole.fleetManager;
          case 'ownerOperator':
            return AppRole.ownerOperator;
          default:
            return AppRole.driver;
        }
    }
  }

  static String _toString(AppRole r) {
    switch (r) {
      case AppRole.driver:
        return 'driver';
      case AppRole.fleetManager:
        return 'fleetManager';
      case AppRole.ownerOperator:
        return 'ownerOperator';
      case AppRole.broker:
        return 'broker';
    }
  }

  static UserProfile fromMap(Map<String, dynamic> row) {
    return UserProfile(
      id: row['id'] as String,
      role: _fromString(row['role'] as String),
      isPremium: (row['is_premium'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toInsert() {
    return {
      'id': id,
      'role': _toString(role),
      'is_premium': isPremium,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class UserProfileService {
  UserProfileService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybeClient() {
    final cfg = _ref.read(appConfigProvider);
    final configured =
        !cfg.useMockData &&
        cfg.supabaseUrl.isNotEmpty &&
        cfg.supabaseAnonKey.isNotEmpty;
    if (!configured) return null;
    return Supabase.instance.client;
  }

  Future<UserProfile?> fetchMyProfile() async {
    final client = _maybeClient();
    if (client == null) return null; // no backend configured
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    final rowDyn = await client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (rowDyn == null) return null;
    final row = Map<String, dynamic>.from(rowDyn as Map);
    return UserProfile.fromMap(row);
  }

  /// Upsert (insert or update) the current user's profile.
  Future<void> upsertMyProfile({
    required AppRole role,
    required bool isPremium,
  }) async {
    final client = _maybeClient();
    if (client == null) return; // simulate success when not configured
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final profile = UserProfile(id: uid, role: role, isPremium: isPremium);
    await client.from('profiles').upsert(profile.toInsert());
  }
}

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(ref);
});
