import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';

class TruckPosition {
  final String truckId;
  final double lat;
  final double lng;
  final double? speedKph;
  final double? headingDeg;
  final DateTime gpsTs;
  final String health; // moving | idle | offline

  const TruckPosition({
    required this.truckId,
    required this.lat,
    required this.lng,
    required this.gpsTs,
    this.speedKph,
    this.headingDeg,
    required this.health,
  });

  factory TruckPosition.fromRow(Map<String, dynamic> r) {
    final speed = (r['speed_kph'] as num?)?.toDouble();
    final ts = DateTime.parse(r['gps_ts'] as String);
    final health = _deriveHealth(speed, ts);
    return TruckPosition(
      truckId: r['truck_id'] as String,
      lat: (r['lat'] as num).toDouble(),
      lng: (r['lng'] as num).toDouble(),
      speedKph: speed,
      headingDeg: (r['heading_deg'] as num?)?.toDouble(),
      gpsTs: ts,
      health: health,
    );
  }

  static String _deriveHealth(double? speedKph, DateTime ts) {
    final now = DateTime.now().toUtc();
    final age = now.difference(ts).inMinutes;
    if (age > 15) return 'offline';
    if ((speedKph ?? 0) > 2) return 'moving';
    return 'idle';
  }
}

class TelemetryService {
  TelemetryService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<TruckPosition>> listCurrentPositions() async {
    final c = _maybe();
    if (c == null) return const [];
    final rows = await c
        .from('truck_current_positions')
        .select('truck_id, lat, lng, speed_kph, heading_deg, gps_ts')
        .order('gps_ts', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(TruckPosition.fromRow)
        .toList();
  }

  Stream<TruckPosition> streamCurrentPositions() {
    final c = _maybe();
    if (c == null) return const Stream.empty();
    final chan = c.channel('realtime:truck_current_positions');
    final controller = StreamController<TruckPosition>.broadcast();

    void onPayload(PostgresChangePayload payload) {
      final r = payload.newRecord;
      // Convert to a typed map and guard against empties
      final map = Map<String, dynamic>.from(r as Map);
      if (map.isEmpty) return;
      controller.add(TruckPosition.fromRow(map));
    }

    chan
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'truck_current_positions',
          callback: onPayload,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'truck_current_positions',
          callback: onPayload,
        )
        .subscribe();

    controller.onCancel = () async {
      await c.removeChannel(chan);
      await controller.close();
    };

    return controller.stream;
  }

  Future<void> ingestPositionRpc({
    required String truckId,
    required double lat,
    required double lng,
    double? speedKph,
    double? headingDeg,
    double? odometerKm,
    DateTime? gpsTs,
    String? source,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    await c.rpc(
      'fn_ingest_truck_position',
      params: {
        'p_truck_id': truckId,
        'p_lat': lat,
        'p_lng': lng,
        'p_speed_kph': speedKph,
        'p_heading_deg': headingDeg,
        'p_odometer_km': odometerKm,
        'p_gps_ts': (gpsTs ?? DateTime.now().toUtc()).toIso8601String(),
        'p_source': source ?? 'app',
      },
    );
  }

  Future<void> ingestPosition({
    required String truckId,
    required double lat,
    required double lng,
    double? speedKph,
    double? headingDeg,
    double? odometerKm,
    double? accuracyM,
    DateTime? gpsTs,
    String? source,
    String? tripId,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    // Write into history; trigger will update current table. This should ideally go through an Edge Function/RPC.
    await c.from('truck_positions').insert({
      'truck_id': truckId,
      'lat': lat,
      'lng': lng,
      'speed_kph': speedKph,
      'heading_deg': headingDeg,
      'odometer_km': odometerKm,
      'accuracy_m': accuracyM,
      'gps_ts': (gpsTs ?? DateTime.now().toUtc()).toIso8601String(),
      'source': source ?? 'app',
      'trip_id': tripId,
    });
  }
}

final telemetryServiceProvider = Provider<TelemetryService>(
  (ref) => TelemetryService(ref),
);
