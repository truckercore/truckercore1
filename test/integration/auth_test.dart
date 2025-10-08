import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication & Authorization', () {
    setUpAll(() async {
      // Initialize Supabase
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON'),
      );
    });

    test('Can access Supabase client', () {
      expect(Supabase.instance.client, isNotNull);
    });

    test('Auth state is accessible', () {
      final auth = Supabase.instance.client.auth;
      expect(auth, isNotNull);
    });

    // Add more auth tests as needed
  });
}
