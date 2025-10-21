// lib/features/auth/state/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/config/app_config.dart';
import '../../../common/models/app_role.dart';
import '../../../common/state/session_provider.dart' as session;
import '../../../core/supabase/supabase_factory.dart';

/// Centralized providers for Auth feature
/// Tokens/IDs are hidden behind providers to keep a single source of truth.

/// Supabase URL from config (throws in non-mock when missing)
final supabaseUrlProvider = Provider<String>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final url = cfg.supabaseUrl;
  if (url.isEmpty) {
    if (cfg.useMockData) return '';
    throw StateError('SUPABASE_URL is not configured');
  }
  return url;
});

/// Supabase anon key from config (throws in non-mock when missing)
final supabaseAnonKeyProvider = Provider<String>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final key = cfg.supabaseAnonKey;
  if (key.isEmpty) {
    if (cfg.useMockData) return '';
    throw StateError('SUPABASE_ANON (or legacy SUPABASE_ANON_KEY) is not configured');
  }
  return key;
});

/// Is Supabase ready for use (from factory/provider set in main.dart)?
final authReadyProvider = Provider<bool>((ref) => ref.watch(supabaseReadyProvider));

/// Re-export session provider via auth module for convenience
final authSessionProvider = Provider<UserSession>((ref) => ref.watch(session.sessionProvider));
