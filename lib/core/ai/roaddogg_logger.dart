import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';
import '../../services/supa_client.dart';

class RoaddoggLogger {
  final AppConfig config;
  final SupaClient? http; // null in mock or when not configured
  RoaddoggLogger(this.config, this.http);

  Future<void> log({required String action, required Map<String, dynamic> payload}) async {
    try {
      if (config.useMockData || http == null) {
        dev.log('[AI_LOG][$action] $payload');
        return;
      }
      // 1) Write to ai_audit_log (existing path)
      await http!.postJson('/rest/v1/ai_audit_log', {
        'action': action,
        'payload': payload,
      }, maxRetries: 2);
      // 2) Also enqueue into action_outbox for unified audit trail
      try {
        // Direct REST insert into action_outbox using service role is not available here, so prefer client SDK if present.
        final client = Supabase.instance.client;
        await client.from('action_outbox').insert({
          'scope': 'ai_audit',
          'idempotency_key': '$action-${DateTime.now().millisecondsSinceEpoch}',
          'payload': {
            'action': action,
            'payload': payload,
          },
          'status': 'pending',
        });
      } catch (_) {
        // best-effort; ignore if not configured
      }
    } catch (e) {
      // no-op
    }
  }
}

final roaddoggLoggerProvider = Provider<RoaddoggLogger>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (cfg.useMockData || cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
    return RoaddoggLogger(cfg, null);
  }
  final http = SupaClient(supabaseUrl: cfg.supabaseUrl, anonKey: cfg.supabaseAnonKey);
  return RoaddoggLogger(cfg, http);
});
