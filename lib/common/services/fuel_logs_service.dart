import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class FuelLog {
  final String id;
  final String truckId;
  final String? driverUserId;
  final DateTime ts;
  final double gallons;
  final int priceCents;
  final double? odometerKm;
  final String? location;
  final String source;
  final String? notes;

  const FuelLog({
    required this.id,
    required this.truckId,
    required this.driverUserId,
    required this.ts,
    required this.gallons,
    required this.priceCents,
    required this.odometerKm,
    required this.location,
    required this.source,
    required this.notes,
  });

  static FuelLog fromMap(Map<String, dynamic> r) => FuelLog(
    id: r['id'] as String,
    truckId: r['truck_id'] as String,
    driverUserId: r['driver_user_id'] as String?,
    ts: DateTime.parse(r['ts'] as String),
    gallons: (r['gallons'] as num).toDouble(),
    priceCents: (r['price_cents'] as num).toInt(),
    odometerKm: (r['odometer_km'] as num?)?.toDouble(),
    location: r['location'] as String?,
    source: r['source'] as String? ?? 'card',
    notes: r['notes'] as String?,
  );
}

class FuelLogsService {
  FuelLogsService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<FuelLog>> list({int limit = 100}) async {
    final c = _maybe();
    if (c == null) return const [];
    final rows = await c
        .from('fuel_logs')
        .select()
        .order('ts', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FuelLog.fromMap)
        .toList();
  }

  Future<void> add({
    required String truckId,
    double? gallons,
    int? priceCents,
    double? odometerKm,
    String? location,
    String source = 'card',
    String? notes,
    DateTime? ts,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final payload = {
      'truck_id': truckId,
      'gallons': gallons ?? 0,
      'price_cents': priceCents ?? 0,
      'odometer_km': odometerKm,
      'location': location,
      'source': source,
      'notes': notes,
      'ts': (ts ?? DateTime.now()).toUtc().toIso8601String(),
    };
    await c.from('fuel_logs').insert(payload);
  }
}

final fuelLogsServiceProvider = Provider<FuelLogsService>(
  (ref) => FuelLogsService(ref),
);
