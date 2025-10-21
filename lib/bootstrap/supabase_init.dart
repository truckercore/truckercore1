import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}

Future<void> initSupabase() async {
  assert(Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty,
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY');

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  try {
    final res = await Supabase.instance.client
        .from('health_ping_view')
        .select('now')
        .limit(1);
    dev.log('Supabase OK. health_ping_view: $res', name: 'bootstrap');
  } catch (e, st) {
    dev.log('Supabase init health check failed', name: 'bootstrap', error: e, stackTrace: st);
  }
}
