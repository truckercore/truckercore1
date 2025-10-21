import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class AlertEvent {
  final String id;
  final String code;
  final String severity; // info | warning | critical
  final Map<String, dynamic> payload;
  final DateTime triggeredAt;
  final bool acknowledged;
  const AlertEvent({
    required this.id,
    required this.code,
    required this.severity,
    required this.payload,
    required this.triggeredAt,
    required this.acknowledged,
  });

  static AlertEvent fromRow(Map<String, dynamic> r) => AlertEvent(
    id: r['id'] as String,
    code: r['code'] as String,
    severity: r['severity'] as String,
    payload: Map<String, dynamic>.from(r['payload'] as Map),
    triggeredAt: DateTime.parse(r['triggered_at'] as String),
    acknowledged: (r['acknowledged'] as bool?) ?? false,
  );
}

class AlertsService {
  AlertsService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<AlertEvent>> list({int limit = 25, String? code}) async {
    final c = _maybe();
    if (c == null) return const [];
    dynamic rows;
    if (code != null) {
      rows = await c
          .from('alerts_events')
          .select()
          .eq('code', code)
          .order('triggered_at', ascending: false)
          .limit(limit);
    } else {
      rows = await c
          .from('alerts_events')
          .select()
          .order('triggered_at', ascending: false)
          .limit(limit);
    }
    return (rows as List)
        .map((e) => AlertEvent.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> acknowledge(String id) async {
    final c = _maybe();
    if (c == null) return;
    try {
      await c
          .from('alerts_events')
          .update({
            'acknowledged': true,
            'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (_) {
      // Offline-safe: enqueue to outbox for later reconcile
      try {
        // lazy import to avoid cycle
        final outbox = Supabase.instance.client; // same client
        // Insert into action_outbox with a scoped payload
        await outbox.from('action_outbox').insert({
          'scope': 'alerts.ack',
          'payload': {
            'id': id,
            'acknowledged': true,
            'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
          },
        });
      } catch (_) {}
    }
  }
}

final alertsServiceProvider = Provider<AlertsService>(
  (ref) => AlertsService(ref),
);
