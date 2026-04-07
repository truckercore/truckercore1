import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/common/config/app_env.dart';

void main() {
  tearDown(() {
    // Reset provider between tests
    AppEnv.setProviderForTests(EnvProvider.compileTime);
  });

  test('prefers SUPABASE_ANON when present', () {
    AppEnv.setProviderForTests(EnvProvider(read: (k) {
      if (k == 'SUPABASE_ANON') return 'anon-preferred';
      if (k == 'SUPABASE_ANON_KEY') return 'legacy-key';
      if (k == 'SUPABASE_URL') return 'https://example.supabase.co';
      return '';
    }));
    expect(AppEnv.supabaseAnonKey, 'anon-preferred');
  });

  test('falls back to SUPABASE_ANON_KEY when SUPABASE_ANON missing', () {
    AppEnv.setProviderForTests(EnvProvider(read: (k) {
      if (k == 'SUPABASE_ANON') return '';
      if (k == 'SUPABASE_ANON_KEY') return 'legacy-key';
      if (k == 'SUPABASE_URL') return 'https://example.supabase.co';
      return '';
    }));
    expect(AppEnv.supabaseAnonKey, 'legacy-key');
  });

  test('returns empty when both missing', () {
    AppEnv.setProviderForTests(EnvProvider(read: (_) => ''));
    expect(AppEnv.supabaseAnonKey, '');
  });
}
