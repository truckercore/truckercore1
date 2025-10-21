// lib/features/activity/activity_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class ActivityItem {
  final String id;
  final String action;
  final DateTime at;
  final Map<String, dynamic> details;
  final String? userId;
  const ActivityItem({required this.id, required this.action, required this.at, required this.details, this.userId});
}

class ActivityService {
  final AppConfig cfg;
  const ActivityService(this.cfg);

  Future<List<ActivityItem>> list({String? userId, String? action, DateTime? since}) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return const [];
    final c = Supabase.instance.client;
    final rows = await c.from('v_enterprise_activity').select().order('occurred_at', ascending: false).limit(200);
    var list = (rows as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).map((m) => ActivityItem(
      id: m['id'].toString(), action: m['action'].toString(), at: DateTime.parse(m['occurred_at'].toString()), details: Map<String, dynamic>.from((m['details'] as Map?) ?? {}), userId: m['actor_user_id']?.toString(),
    )).toList();
    if (userId != null && userId.isNotEmpty) {
      list = list.where((e) => e.userId == userId).toList();
    }
    if (action != null && action.isNotEmpty) {
      list = list.where((e) => e.action == action).toList();
    }
    if (since != null) {
      list = list.where((e) => e.at.isAfter(since)).toList();
    }
    return list;
  }

  Future<void> log({required String action, Map<String, dynamic>? details, String? entityType, String? entityId, String? description, String? traceId}) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return;
    final c = Supabase.instance.client;
    final user = c.auth.currentUser;
    final orgId = user?.userMetadata?['org_id']?.toString();
    if (orgId == null || orgId.isEmpty) return; // cannot scope audit row
    // Feature flag gating: audit_logging
    try {
      // Merge defaults (zero UUID) with per-org override if present
      final Map<String, dynamic> flags = {};
      try {
        final defRow = await c.from('org_feature_flags').select('flags').eq('org_id', '00000000-0000-0000-0000-000000000000').maybeSingle();
        if (defRow != null && defRow['flags'] != null) {
          flags.addAll(Map<String, dynamic>.from(defRow['flags'] as Map));
        }
        final orgRow = await c.from('org_feature_flags').select('flags').eq('org_id', orgId).maybeSingle();
        if (orgRow != null && orgRow['flags'] != null) {
          flags.addAll(Map<String, dynamic>.from(orgRow['flags'] as Map));
        }
      } catch (_) {}
      final auditOn = (flags['audit_logging'] as bool?) ?? true;
      if (!auditOn) return;
      // Prepare params
      final p = {
        'p_org_id': orgId,
        'p_actor_user_id': user?.id,
        'p_action': action,
        'p_entity_type': (entityType ?? (details?['entity_type']?.toString() ?? 'ui')),
        'p_entity_id': (entityId ?? (details?['load_id']?.toString() ?? details?['entity_id']?.toString() ?? '')),
        'p_description': description ?? action,
        'p_details': details ?? const <String, dynamic>{},
        'p_trace_id': traceId ?? 'trace-${DateTime.now().microsecondsSinceEpoch}',
      };
      // Small retry on transient errors
      Future<void> attempt() async {
        await c.rpc('fn_enterprise_audit_insert', params: p);
      }
      try {
        await attempt();
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 200));
        try { await attempt(); } catch (_) {}
      }
    } catch (_) { /* swallow in UI context */ }
  }
}

final activityServiceProvider = Provider<ActivityService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  return ActivityService(cfg);
});
