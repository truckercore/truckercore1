import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class ServiceNextDue {
  final String scheduleId;
  final String truckId;
  final double? kmToDue;
  final Duration? timeToDue;
  const ServiceNextDue({
    required this.scheduleId,
    required this.truckId,
    this.kmToDue,
    this.timeToDue,
  });

  factory ServiceNextDue.fromRow(Map<String, dynamic> r) {
    final km = (r['km_to_due'] as num?)?.toDouble();
    Duration? ttd;
    // time_to_due can come as interval/ISO; Supabase returns as string; parse best-effort
    final raw = r['time_to_due'];
    if (raw is String) {
      // Expect something like 'P0Y0M0DT-1H-2M-3S' or '00:12:00'
      try {
        if (raw.contains(':')) {
          final parts = raw.split(':');
          final h = int.tryParse(parts[0]) ?? 0;
          final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final s = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
          ttd = Duration(hours: h, minutes: m, seconds: s);
        }
      } catch (_) {}
    }
    return ServiceNextDue(
      scheduleId: r['schedule_id'] as String,
      truckId: r['truck_id'] as String,
      kmToDue: km,
      timeToDue: ttd,
    );
  }
}

class MaintenanceApi {
  MaintenanceApi(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<ServiceNextDue>> listNextDue({int limit = 20}) async {
    final c = _maybe();
    if (c == null) return const [];
    final rowsDyn = await c
        .from('v_truck_service_next_due')
        .select()
        .limit(limit);
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(ServiceNextDue.fromRow).toList();
  }

  Future<int> countOpenDVIRDefects() async {
    final c = _maybe();
    if (c == null) return 0;
    final row = await c
        .from('dvir_defects')
        .select('count(*)')
        .eq('status', 'open')
        .single();
    final cnt = row['count'];
    if (cnt is int) return cnt;
    if (cnt is String) return int.tryParse(cnt) ?? 0;
    if (cnt is num) return cnt.toInt();
    return 0;
  }
}

final maintenanceApiProvider = Provider<MaintenanceApi>(
  (ref) => MaintenanceApi(ref),
);
