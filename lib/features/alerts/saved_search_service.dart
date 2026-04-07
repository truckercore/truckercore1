import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class SavedSearch {
  final String id;
  final String name;
  final Map<String, dynamic> filters;
  final bool isActive;
  const SavedSearch({
    required this.id,
    required this.name,
    required this.filters,
    required this.isActive,
  });
}

class AlertItem {
  final String id;
  final String title;
  final String subtitle;
  final String deeplink;
  final DateTime triggeredAt;
  final bool seen;
  const AlertItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.deeplink,
    required this.triggeredAt,
    required this.seen,
  });
}

class SavedSearchService {
  SavedSearchService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<SavedSearch>> listMySearches() async {
    final c = _maybe();
    if (c == null) return const [];
    final uid = c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await c
        .from('saved_searches')
        .select('id,name,filters,is_active')
        .order('created_at', ascending: false);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return SavedSearch(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'Saved',
        filters: Map<String, dynamic>.from(m['filters'] as Map? ?? {}),
        isActive: (m['is_active'] as bool?) ?? true,
      );
    }).toList();
  }

  Future<String?> saveSearch({
    required String name,
    required Map<String, dynamic> filters,
  }) async {
    final c = _maybe();
    if (c == null) return null;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await c
        .from('saved_searches')
        .insert({
          'user_id': uid,
          'name': name,
          'filters': filters,
          'is_active': true,
        })
        .select('id')
        .single();
    final m = Map<String, dynamic>.from(row as Map);
    return m['id'] as String?;
  }

  Future<void> deleteSearch(String id) async {
    final c = _maybe();
    if (c == null) return;
    await c.from('saved_searches').delete().eq('id', id);
  }

  Future<void> toggleActive(String id, bool active) async {
    final c = _maybe();
    if (c == null) return;
    await c.from('saved_searches').update({'is_active': active}).eq('id', id);
  }

  Future<List<AlertItem>> listMyAlerts({
    bool unseenOnly = false,
    int limit = 50,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    final uid = c.auth.currentUser?.id;
    if (uid == null) return const [];
    final base = c
        .from('load_alerts')
        .select('id,match_payload,triggered_at,seen')
        .eq('user_id', uid);
    final filtered = unseenOnly ? base.eq('seen', false) : base;
    final rows = await filtered
        .order('triggered_at', ascending: false)
        .limit(limit);
    return (rows as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final payload = Map<String, dynamic>.from(
        m['match_payload'] as Map? ?? {},
      );
      final title =
          payload['title']?.toString() ??
          (payload['origin'] != null && payload['destination'] != null
              ? '${payload['origin']} → ${payload['destination']}'
              : 'New match');
      final subtitle = payload['rate'] != null
          ? 'Rate: ${payload['rate']}'
          : (payload['posted_by'] != null ? 'By ${payload['posted_by']}' : '');
      final deeplink = payload['deeplink']?.toString() ?? '/loads';
      return AlertItem(
        id: m['id'] as String,
        title: title,
        subtitle: subtitle,
        deeplink: deeplink,
        triggeredAt:
            DateTime.tryParse(m['triggered_at']?.toString() ?? '') ??
            DateTime.now(),
        seen: (m['seen'] as bool?) ?? false,
      );
    }).toList();
  }

  Future<void> markSeen(String id) async {
    final c = _maybe();
    if (c == null) return;
    await c.from('load_alerts').update({'seen': true}).eq('id', id);
  }

  Future<void> markAllSeen() async {
    final c = _maybe();
    if (c == null) return;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return;
    await c
        .from('load_alerts')
        .update({'seen': true})
        .eq('user_id', uid)
        .eq('seen', false);
  }
}

final savedSearchServiceProvider = Provider<SavedSearchService>(
  (ref) => SavedSearchService(ref),
);

final unseenAlertsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  // Prefer RPC for performance if available
  try {
    final cfg = ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty) {
      final c = Supabase.instance.client;
      final uid = c.auth.currentUser?.id;
      if (uid != null) {
        final rows = await c.rpc(
          'fn_unseen_alerts_count',
          params: {'p_user_id': uid},
        );
        if (rows is List && rows.isNotEmpty) {
          final m = Map<String, dynamic>.from(rows.first as Map);
          final cnt = (m['cnt'] as int?) ?? 0;
          return cnt;
        }
      }
    }
  } catch (_) {}
  // Fallback to cheap approximate fetch
  final svc = ref.read(savedSearchServiceProvider);
  final list = await svc.listMyAlerts(unseenOnly: true, limit: 1);
  return list.length;
});
