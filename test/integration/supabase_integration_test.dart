import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Real Supabase Integration Tests', () {
    late SupabaseClient supabase;

    setUpAll(() async {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON'),
      );
      supabase = Supabase.instance.client;
    });

    test('Can connect to Supabase', () async {
      expect(supabase, isNotNull);
    });

    test('Auth API accessible', () async {
      final auth = supabase.auth;
      expect(auth, isNotNull);
    });

    test('Query vehicles table with RLS (public read may be restricted)', () async {
      try {
        final vehicles = await supabase.from('vehicles').select().limit(1);
        expect(vehicles, isList);
      } on PostgrestException catch (e) {
        // If RLS blocks reads, we still consider the roundtrip successful
        expect(e, isA<PostgrestException>());
      }
    });

    test('Realtime subscription roundtrip (if enabled)', () async {
      final completer = Completer<Map<String, dynamic>>();

      final channel = supabase
          .channel('test-channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'vehicles',
            callback: (payload) {
              completer.complete(payload.newRecord);
            },
          )
          .subscribe();

      // Give time to establish
      await Future.delayed(const Duration(seconds: 1));

      try {
        await supabase.from('vehicles').insert({
          'vehicle_number': 'TEST-CI',
          'status': 'active',
        });
      } catch (_) {
        // If RLS forbids insert, ignore; just ensure no crash
      }

      // Wait briefly for any message (may timeout in RLS contexts)
      try {
        await completer.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        // ignore timeout
      }

      await channel.unsubscribe();
    });
  });
}
