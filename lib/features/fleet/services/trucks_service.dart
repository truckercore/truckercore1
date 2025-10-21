import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class Truck {
  final String id;
  final String label; // was: code
  final String? terminalCode; // may be null if you don't have it yet
  final String status; // moving | idle | offline
  final double? lat;
  final double? lng;

  const Truck({
    required this.id,
    required this.label,
    required this.terminalCode,
    required this.status,
    required this.lat,
    required this.lng,
  });

  static Truck fromMap(Map<String, dynamic> r) => Truck(
    id: r['id'] as String,
    label: (r['label'] as String?) ?? 'Truck',
    terminalCode: r['terminal_code'] as String?, // null if column doesn't exist
    status: (r['status'] as String?) ?? 'idle', // safe fallback
    lat: (r['lat'] as num?)?.toDouble(), // null-safe
    lng: (r['lng'] as num?)?.toDouble(),
  );
}

class TrucksService {
  TrucksService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<Truck>> list({String? terminalCode}) async {
    final c = _maybe();
    if (c == null) return const [];

    // Select only the columns that likely exist in your table.
    // If terminal_code/status/lat/lng don't exist yet, select will ignore them.
    dynamic q = c
        .from('trucks')
        .select('id,label,terminal_code,status,lat,lng');

    if (terminalCode != null) {
      // If terminal_code column does not exist yet, skip filtering
      try {
        q = q.eq('terminal_code', terminalCode);
      } catch (_) {}
    }

    try {
      q.order('updated_at', ascending: false); // skip silently if no updated_at
    } catch (_) {}

    final rows = await q;
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Truck.fromMap)
        .toList();
  }

  Stream<Truck> streamChanges({String? terminalCode}) {
    final c = _maybe();
    if (c == null) return const Stream.empty();
    final chan = c.channel('realtime:trucks');
    final controller = StreamController<Truck>.broadcast();

    void onPayload(PostgresChangePayload payload) {
      final r = payload.newRecord;
      final t = Truck.fromMap(Map<String, dynamic>.from(r));
      if (terminalCode == null || t.terminalCode == terminalCode) {
        controller.add(t);
      }
    }

    chan
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trucks',
          callback: onPayload,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trucks',
          callback: onPayload,
        )
        .subscribe();

    controller.onCancel = () async {
      await c.removeChannel(chan);
      await controller.close();
    };

    return controller.stream;
  }

  Future<void> updateTruck({
    required String id,
    String? status, // 'moving' | 'idle' | 'offline'
    String? terminalCode, // e.g., 'TX-DAL'
    double? lat,
    double? lng,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final patch = <String, dynamic>{};
    if (status != null) patch['status'] = status;
    if (terminalCode != null) patch['terminal_code'] = terminalCode;
    if (lat != null) patch['lat'] = lat;
    if (lng != null) patch['lng'] = lng;
    patch['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (patch.length <= 1) return; // only updated_at? nothing to change
    await c.from('trucks').update(patch).eq('id', id);
  }
}

final trucksServiceProvider = Provider<TrucksService>(
  (ref) => TrucksService(ref),
);
