// lib/core/outbox/outbox_client.dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class OutboxClient {
  final SupabaseClient _sb;
  static const _uuid = Uuid();

  OutboxClient(this._sb);

  Future<String> enqueue({
    required String scope,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final row = {
      'scope': scope,
      'idempotency_key': key,
      'payload': jsonDecode(jsonEncode(payload)), // ensure json-safe
    };
    final res = await _sb.from('action_outbox').insert(row).select('id').single();
    return res['id'] as String;
  }
}
