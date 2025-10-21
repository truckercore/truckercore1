import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final secureStorage = const FlutterSecureStorage();

Future<void> bootstrapSupabase() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://YOUR-PROJECT.supabase.co'),
    // Prefer SUPABASE_ANON; fall back to SUPABASE_ANON_KEY for backward compatibility
    anonKey: const String.fromEnvironment('SUPABASE_ANON') != ''
        ? const String.fromEnvironment('SUPABASE_ANON')
        : const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'YOUR-ANON-KEY'),
    debug: false,
  );
  // TODO: restore session from secure storage if desired
}
