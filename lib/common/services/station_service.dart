import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Simple service for managing weigh/inspection stations in Supabase.
///
/// Expected schema (Postgres):
///   table public.stations (
///     id uuid primary key default gen_random_uuid(),
///     name text not null,
///     lat double precision not null,
///     lng double precision not null,
///     open boolean not null default false,
///     created_at timestamp with time zone default now()
///   )
/// and the table is added to the `supabase_realtime` publication.
class StationService {
  StationService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    final ok = cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
    return ok ? Supabase.instance.client : null;
  }

  /// Insert a new weigh/inspection station row.
  /// Returns the inserted row id (as String).
  Future<String> insertStation({
    required String name,
    required double lat,
    required double lng,
    bool open = false,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final row = await c
        .from('stations')
        .insert({'name': name, 'lat': lat, 'lng': lng, 'open': open})
        .select('id')
        .single();
    return '${row['id']}';
  }

  /// Upsert by id (if you already know station id). If [id] is null, creates a new row.
  /// Returns id of the upserted row.
  Future<String> upsertStation({
    String? id,
    required String name,
    required double lat,
    required double lng,
    bool open = false,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final payload = {'name': name, 'lat': lat, 'lng': lng, 'open': open};
    if (id != null) {
      final row = await c
          .from('stations')
          .update(payload)
          .eq('id', id)
          .select('id')
          .maybeSingle();
      // If not found, insert a new one
      if (row == null) {
        final inserted = await c
            .from('stations')
            .insert({...payload, 'id': id})
            .select('id')
            .single();
        return '${inserted['id']}';
      }
      return id;
    } else {
      final inserted = await c
          .from('stations')
          .insert(payload)
          .select('id')
          .single();
      return '${inserted['id']}';
    }
  }

  /// Set station open/closed by id.
  Future<void> setOpen({required String id, required bool open}) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    await c.from('stations').update({'open': open}).eq('id', id);
  }

  /// Quick fetch: returns current open stations (id + minimal fields)
  Future<List<Map<String, dynamic>>> fetchOpenStations({
    int limit = 200,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    final rows = await c
        .from('stations')
        .select('id,name,lat,lng,open')
        .eq('open', true)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }
}

final stationServiceProvider = Provider<StationService>(
  (ref) => StationService(ref),
);
