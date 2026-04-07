import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Use a simple Fake to simulate GoTrueClient and its `currentSession` property
class FakeGoTrueClient extends Fake implements GoTrueClient {
  FakeGoTrueClient();
  Session? session;
  @override
  Session? get currentSession => session;
}

Session? _makeTestSession() {
  // Minimal viable Session via fromJson to satisfy type checks.
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = jsonDecode('''
  {
    "access_token": "test_access",
    "token_type": "bearer",
    "expires_in": 3600,
    "expires_at": ${nowSec + 3600},
    "refresh_token": "test_refresh",
    "user": {
      "id": "00000000-0000-0000-0000-000000000000",
      "aud": "authenticated",
      "role": "authenticated",
      "email": "test@example.com",
      "app_metadata": {},
      "user_metadata": {},
      "identities": [],
      "created_at": "${DateTime.now().toIso8601String()}",
      "updated_at": "${DateTime.now().toIso8601String()}"
    }
  }
  ''') as Map<String, dynamic>;
  return Session.fromJson(payload);
}

void main() {
  bool hasActiveSession(GoTrueClient c) => c.currentSession != null;

  group('Authentication Guard Tests', () {
    test('returns an active session when present', () {
      final client = FakeGoTrueClient()..session = _makeTestSession();
      expect(hasActiveSession(client), isTrue);
    });

    test('returns null when no session exists', () {
      final client = FakeGoTrueClient();
      expect(hasActiveSession(client), isFalse);
    });
  });
}
