// lib/features/integrations/integrations_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';
import '../../core/outbox/outbox_client.dart';

class IntegrationItem {
  final String id;
  final String provider;
  final String status;
  final DateTime? lastSyncAt;
  const IntegrationItem({required this.id, required this.provider, required this.status, this.lastSyncAt});
  static IntegrationItem fromMap(Map<String, dynamic> m) => IntegrationItem(
    id: m['id'].toString(),
    provider: (m['provider'] ?? '').toString(),
    status: (m['status'] ?? 'disconnected').toString(),
    lastSyncAt: m['last_sync_at'] != null ? DateTime.tryParse(m['last_sync_at'].toString()) : null,
  );
}

class IntegrationsService {
  final AppConfig cfg;
  IntegrationsService(this.cfg);

  SupabaseClient? _maybe() {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<IntegrationItem>> list() async {
    final c = _maybe();
    if (c == null) return const [];
    final rows = await c.from('integrations').select().order('provider');
    final list = (rows as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(IntegrationItem.fromMap)
        .toList();
    return list;
    }

  Future<String> connect({required String provider}) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final outbox = OutboxClient(c);
    return outbox.enqueue(scope: 'integration_connect', payload: { 'provider': provider });
  }

  Future<String> disconnect({required String provider}) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final outbox = OutboxClient(c);
    return outbox.enqueue(scope: 'integration_disconnect', payload: { 'provider': provider });
  }

  Future<String> triggerExport({required String format}) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final outbox = OutboxClient(c);
    return outbox.enqueue(scope: 'accounting_export', payload: { 'format': format });
  }

  Future<String> addCalendarEvent({required String title, required DateTime start, DateTime? end}) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final outbox = OutboxClient(c);
    return outbox.enqueue(scope: 'calendar_event', payload: {
      'title': title,
      'starts_at': start.toUtc().toIso8601String(),
      if (end != null) 'ends_at': end.toUtc().toIso8601String(),
    });
  }
}

final integrationsServiceProvider = Provider<IntegrationsService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return IntegrationsService(cfg);
});
