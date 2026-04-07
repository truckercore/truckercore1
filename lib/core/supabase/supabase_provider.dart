import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/app_env.dart';

final appEnvProvider = Provider<AppEnv>((ref) => const AppEnv(
      useMockData: bool.fromEnvironment('USE_MOCK', defaultValue: true),
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON'),
    ));

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final env = ref.watch(appEnvProvider);
  if (!env.supabaseEnabled) return null;
  return SupabaseClient(env.supabaseUrl!, env.supabaseAnonKey!);
});

// Convenience helper
T requireSupabase<T>(WidgetRef ref, T Function(SupabaseClient c) build, {T Function()? whenDisabled}) {
  final c = ref.read(supabaseClientProvider);
  if (c == null) return (whenDisabled ?? () => throw StateError('Supabase disabled'))();
  return build(c);
}
