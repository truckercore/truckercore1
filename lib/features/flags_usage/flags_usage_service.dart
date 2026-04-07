// lib/features/flags_usage/flags_usage_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';

class OrgFlagsUsageService {
  final AppConfig cfg;
  const OrgFlagsUsageService(this.cfg);

  Future<Map<String, dynamic>> flags({String? orgId}) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return const {};
    final c = Supabase.instance.client;
    try {
      if (orgId != null) {
        final row = await c.from('org_feature_flags').select('flags').eq('org_id', orgId).maybeSingle();
        if (row == null) return const {};
        return Map<String, dynamic>.from(row['flags'] as Map);
      } else {
        final row = await c.from('org_feature_flags').select('flags').limit(1).maybeSingle();
        if (row == null) return const {};
        return Map<String, dynamic>.from(row['flags'] as Map);
      }
    } catch (_) { return const {}; }
  }

  Future<List<Map<String, dynamic>>> usage({String? orgId}) async {
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return const [];
    final c = Supabase.instance.client;
    try {
      final rows = await c.from('usage_counters').select().order('updated_at', ascending: false).limit(100);
      var list = (rows as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (orgId != null) {
        list = list.where((m) => (m['org_id']?.toString() ?? '') == orgId).toList();
      }
      return list;
    } catch (_) { return const []; }
  }
}

final flagsUsageServiceProvider = Provider<OrgFlagsUsageService>((ref){
  final cfg = ref.watch(appConfigProvider);
  return OrgFlagsUsageService(cfg);
});
