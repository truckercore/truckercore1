// lib/supabase_config.dart
// Simple adapter to centralize Supabase URL and anon key configuration.
// Prefer passing values via --dart-define to keep secrets out of source.
// Falls back to existing AppEnv values to remain compatible with current app wiring.

import 'common/config/app_env.dart';

class SupabaseConfig {
  // Prefer standardized dart-defines; provide a friendly default URL only for local demos.
  static const String _urlFromEnv = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );

  // New preferred name
  static const String _anonPref = String.fromEnvironment('SUPABASE_ANON');
  // Legacy name accepted as fallback
  static const String _anonLegacy = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Public getters used by sample code or simple apps
  static String get url {
    // If dart-define provided, use it; otherwise defer to existing AppEnv which already merges
    // dart-defines, .env, and defaults across the app.
    if (_urlFromEnv.isNotEmpty && _urlFromEnv != 'https://YOUR_PROJECT.supabase.co') {
      return _urlFromEnv;
    }
    return AppEnv.supabaseUrl;
  }

  static String get anonKey {
    if (_anonPref.isNotEmpty) return _anonPref;
    if (_anonLegacy.isNotEmpty) return _anonLegacy;
    return AppEnv.supabaseAnonKey;
  }
}
