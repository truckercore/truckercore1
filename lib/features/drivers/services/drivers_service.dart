import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class Driver {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String status; // driving | resting | off_duty
  final double hosHoursLeft; // hours left today
  final String? terminalCode;

  const Driver({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.status,
    required this.hosHoursLeft,
    this.terminalCode,
  });

  static Driver fromMap(Map<String, dynamic> r) => Driver(
    id: r['id'] as String,
    name: r['name'] as String,
    phone: r['phone'] as String?,
    email: r['email'] as String?,
    status: (r['status'] as String?) ?? 'off_duty',
    hosHoursLeft: (r['hos_hours_left'] as num?)?.toDouble() ?? 0,
    terminalCode: r['terminal_code'] as String?,
  );
}

class DriversService {
  DriversService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
      return null;
    }
    return Supabase.instance.client;
  }

  Future<List<Driver>> list({String? terminalCode, String? q}) async {
    final c = _maybe();
    if (c == null) {
      return const [];
    }
    dynamic sel = c.from('drivers').select();
    if (terminalCode != null) {
      sel = sel.eq('terminal_code', terminalCode);
    }
    if (q != null && q.trim().isNotEmpty) {
      final s = q.trim();
      sel = sel.or('name.ilike.%$s%,email.ilike.%$s%,phone.ilike.%$s%');
    }
    final rows = await sel.order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Driver.fromMap)
        .toList();
  }
}

final driversServiceProvider = Provider<DriversService>(
  (ref) => DriversService(ref),
);
