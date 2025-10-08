// lib/common/config/app_env.dart
// Public app environment sourced from --dart-define or JSON via --dart-define-from-file.
// Only public values belong here (no secrets). Use Edge Functions for anything sensitive.

import 'dart:developer' as developer;

class EnvProvider {
  final String Function(String key) read;
  const EnvProvider({required this.read});

  static final compileTime = const EnvProvider(read: _readCompileTime);
  static String _readCompileTime(String key) {
    switch (key) {
      case 'SUPABASE_URL':
        return const String.fromEnvironment('SUPABASE_URL');
      case 'SUPABASE_ANON':
        return const String.fromEnvironment('SUPABASE_ANON');
      case 'SUPABASE_ANON_KEY':
        return const String.fromEnvironment('SUPABASE_ANON_KEY');
      case 'ENV_NAME':
        return const String.fromEnvironment('ENV_NAME');
      default:
        // Unknown key: cannot use a variable for fromEnvironment in const context
        // Return empty string to indicate not provided at compile-time.
        return '';
    }
  }
}

class AppEnv {
  static EnvProvider _provider = EnvProvider.compileTime;

  // For tests only: override the provider. Do not use in production.
  static void setProviderForTests(EnvProvider provider) {
    _provider = provider;
  }

  static String get supabaseUrl => _provider.read('SUPABASE_URL');

  // Prefer new standardized name SUPABASE_ANON; fall back to legacy SUPABASE_ANON_KEY for compatibility
  static String get supabaseAnonKey {
    final preferred = _provider.read('SUPABASE_ANON');
    if (preferred.isNotEmpty) return preferred;
    final legacy = _provider.read('SUPABASE_ANON_KEY');
    if (legacy.isNotEmpty) return legacy;
    return '';
  }

  static String get envName => _provider.read('ENV_NAME');

  /// Default role for this app instance (owner_operator or fleet_manager)
  static String get defaultRole => const String.fromEnvironment('DEFAULT_ROLE', defaultValue: '');

  // Emit a single deprecation warning when legacy is used.
  static void maybeWarnLegacy() {
    final preferred = _provider.read('SUPABASE_ANON');
    final legacy = _provider.read('SUPABASE_ANON_KEY');
    if (preferred.isEmpty && legacy.isNotEmpty) {
      developer.log(
        'Deprecation: SUPABASE_ANON_KEY is deprecated. Prefer SUPABASE_ANON. Support will be removed in a future release.',
        name: 'env',
      );
    }
  }

  static void validateOrThrow() {
    assert(supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty,
        'Missing SUPABASE_URL or SUPABASE_ANON (legacy SUPABASE_ANON_KEY also supported). Use --dart-define or --dart-define-from-file.');
  }
}
