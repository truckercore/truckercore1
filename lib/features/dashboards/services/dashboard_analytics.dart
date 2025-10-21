import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardAnalytics {
  static Future<void> trackOpen(String dashboardId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': dashboardId,
        'action': 'open',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort; ignore failures
    }
  }

  static Future<void> trackFavorite(String dashboardId, {required bool enabled}) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': dashboardId,
        'action': enabled ? 'favorite' : 'unfavorite',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> trackPreview(String dashboardId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': dashboardId,
        'action': 'preview',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// When a user opens from a preview dialog
  static Future<void> trackPreviewOpen(String dashboardId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': dashboardId,
        'action': 'preview_open',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> trackShare(String dashboardId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': dashboardId,
        'action': 'share',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// When a user imports a shared configuration
  static Future<void> trackShareImport(String dashboardId) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': dashboardId,
        'action': 'share_import',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Track filter usage in marketplace (search/category)
  static Future<void> trackFilterUsed({String? query, String? category}) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': null,
        'action': 'filter_used',
        'timestamp': DateTime.now().toIso8601String(),
        'meta': {
          if (query != null && query.isNotEmpty) 'query': query,
          if (category != null && category.isNotEmpty) 'category': category,
        }
      });
    } catch (_) {}
  }

  static Future<void> trackCategoryCreated(String name) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': null,
        'action': 'category_created',
        'timestamp': DateTime.now().toIso8601String(),
        'meta': {'name': name},
      });
    } catch (_) {}
  }

  static Future<void> trackCategoryDeleted(String name) async {
    try {
      final client = Supabase.instance.client;
      await client.from('dashboard_usage').insert({
        'dashboard_id': null,
        'action': 'category_deleted',
        'timestamp': DateTime.now().toIso8601String(),
        'meta': {'name': name},
      });
    } catch (_) {}
  }

  static Future<Map<String, int>> getMostUsed() async {
    final counts = <String, int>{};
    try {
      final client = Supabase.instance.client;
      final since = DateTime.now().subtract(const Duration(days: 30));
      final response = await client
          .from('dashboard_usage')
          .select('dashboard_id, timestamp')
          .gte('timestamp', since.toIso8601String());
      for (final row in response) {
        final id = row['dashboard_id'] as String?;
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
    } catch (_) {
      // ignore
    }
    return counts;
  }

  /// Aggregate counts by action type for the last 30 days
  static Future<Map<String, int>> getCountsByAction() async {
    final counts = <String, int>{};
    try {
      final client = Supabase.instance.client;
      final since = DateTime.now().subtract(const Duration(days: 30));
      final response = await client
          .from('dashboard_usage')
          .select('action, timestamp')
          .gte('timestamp', since.toIso8601String());
      for (final row in response) {
        final action = row['action'] as String?;
        if (action == null || action.isEmpty) continue;
        counts[action] = (counts[action] ?? 0) + 1;
      }
    } catch (_) {}
    return counts;
  }
}
