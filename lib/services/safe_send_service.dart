// lib/services/safe_send_service.dart
// Helper for staging and undoing sensitive actions using Supabase RPCs.
// Handles mixed PostgREST return shapes (List row vs Map row).

import 'package:supabase_flutter/supabase_flutter.dart';

class SafeSendService {
  final SupabaseClient _sb;
  SafeSendService({SupabaseClient? client}) : _sb = client ?? Supabase.instance.client;

  /// Calls stage_safe_send and returns confirm token + expiry.
  /// Maps mixed response shapes where PostgREST may return a List or a Map.
  Future<({String token, DateTime expiresAt})> stageSafeSend({
    required String actionId,
    int ttlMinutes = 10,
  }) async {
    final resp = await _sb.rpc('stage_safe_send', params: {
      'p_action_id': actionId,
      'p_ttl_minutes': ttlMinutes,
    });

    // The RPC might return SETOF or a single row depending on definition.
    final data = resp;
    String? token;
    String? expiresAtStr;
    if (data is List && data.isNotEmpty) {
      final row = data.first as Map;
      token = row['confirm_token'] as String?;
      expiresAtStr = row['expires_at'] as String?;
    } else if (data is Map) {
      token = data['confirm_token'] as String?;
      expiresAtStr = data['expires_at'] as String?;
    }
    if (token == null || expiresAtStr == null) {
      throw Exception('Invalid stage response');
    }
    return (token: token, expiresAt: DateTime.parse(expiresAtStr));
  }

  /// Calls undo_action and returns true on success; throws on error so caller can show friendly text.
  Future<bool> undoAction({required String actionId}) async {
    await _sb.rpc('undo_action', params: {'p_action_id': actionId});
    // If PostgREST returns error, Supabase SDK throws PostgrestException; reaching here implies 200.
    // Some RPCs return a boolean or row; we don't need it here.
    return true;
  }
}
