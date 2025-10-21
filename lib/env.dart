// lib/env.dart
// Simple Env adapter so sample/main snippets can import 'env.dart'.
// It delegates to SupabaseConfig which reads from --dart-define and AppEnv.

import 'supabase_config.dart';

class Env {
  // Use getters instead of consts to avoid hardcoding secrets in source.
  static String get supabaseUrl => SupabaseConfig.url;
  static String get supabaseAnonKey => SupabaseConfig.anonKey;
}
