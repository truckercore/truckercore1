import 'package:flutter_test/flutter_test.dart';
import 'package:truckercore1/common/config/app_env.dart';

void main() {
  tearDown(() {
    AppEnv.setProviderForTests(EnvProvider.compileTime);
  });

  test('no legacy fallback when SUPABASE_ANON is present', () {
    AppEnv.setProviderForTests(EnvProvider(read: (k) {
      if (k == 'SUPABASE_ANON') return 'anon-preferred';
      if (k == 'SUPABASE_ANON_KEY') return 'legacy-key-should-not-be-used';
      return '';
    }));
    expect(AppEnv.supabaseAnonKey, 'anon-preferred');
  });
}
