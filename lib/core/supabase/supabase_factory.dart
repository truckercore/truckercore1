// lib/core/supabase/supabase_factory.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/config/app_config.dart';

/// Centralized accessor for Supabase client that is safe in mock mode.
/// UI and services must never touch Supabase.instance directly.
class SupabaseFactory {
  final AppConfig config;
  final bool initialized;

  const SupabaseFactory({required this.config, required this.initialized});

  SupabaseClient? get maybeClient {
    if (config.useMockData) return null; // mock mode → no client
    if (!initialized) return null; // not initialized yet
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Returns a SupabaseClient when available; otherwise throws a controlled error.
  SupabaseClient get client {
    final c = maybeClient;
    if (c != null) return c;
    final reason = config.useMockData
        ? 'useMockData=true (mock mode)'
        : 'Supabase not initialized';
    throw StateError('[SupabaseFactory] Supabase client not available: $reason');
  }
}

final supabaseFactoryProvider = Provider<SupabaseFactory>((ref) {
  final cfg = ref.watch(appConfigProvider);
  // We cannot reliably check initialization from Supabase SDK without try/catch; main.dart will pass the flag via provider override.
  final initialized = ref.watch(_supabaseInitializedProvider);
  return SupabaseFactory(config: cfg, initialized: initialized);
});

/// Simple internal provider to carry the initialized flag from main.dart
final _supabaseInitializedProvider = Provider<bool>((ref) => false);

/// Expose a public-ready provider so widgets/routers can read a single source of truth.
final supabaseReadyProvider = Provider<bool>((ref) {
  return ref.watch(_supabaseInitializedProvider);
});

/// Public override helper for main.dart
Override supabaseInitializedOverride(bool initialized) =>
    _supabaseInitializedProvider.overrideWithValue(initialized);
