import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'truck_restrictions.dart';

class TruckRestrictionsRepository {
  final SupabaseClient _client;
  TruckRestrictionsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  Future<List<TruckRestriction>> fetchByState(String stateCode, {int limit = 500}) async {
    try {
      final res = await _client
          .from('truck_restrictions')
          .select('id,state_code,category,description,location')
          .eq('state_code', stateCode)
          .limit(limit);
      return (res as List<dynamic>)
          .map((e) => TruckRestriction.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e, st) {
      dev.log('fetchByState error: $e', stackTrace: st);
      rethrow;
    }
  }

  /// Prefer calling a Postgres RPC get_state_overlays(state_code text)
  /// which returns rows compatible with TruckRestriction.
  /// We try common param names to maximize compatibility.
  Future<List<TruckRestriction>> fetchOverlaysByStateRpc(String stateCode, {int limit = 800}) async {
    final paramCandidates = [
      {'state_code': stateCode},
      {'state': stateCode},
      {'p_state': stateCode},
      {'p_state_code': stateCode},
    ];
    Object? lastErr;
    for (final params in paramCandidates) {
      try {
        final res = await _client.rpc('get_state_overlays', params: params);
        final rows = (res as List<dynamic>?) ?? const [];
        final mapped = rows
            .map((e) => TruckRestriction.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false);
        // Optionally limit client-side if RPC doesn't accept limit
        if (mapped.length > limit) return mapped.sublist(0, limit);
        return mapped;
      } catch (e, st) {
        lastErr = e;
        dev.log('fetchOverlaysByStateRpc with params=$params failed: $e', stackTrace: st);
      }
    }
    // If all param variants failed, rethrow last error
    throw lastErr ?? Exception('RPC get_state_overlays failed');
  }

  Future<List<TruckRestriction>> fetchByBbox({
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
    int limit = 1000,
  }) async {
    // This requires a PostgREST RPC or a computed index if using location json.
    // As an MVP, if 'location' has {lat,lng}, we can filter client-side after selecting within a state/bbox prefilter.
    try {
      final res = await _client
          .from('truck_restrictions')
          .select('id,state_code,category,description,location')
          .limit(limit);
      final list = (res as List<dynamic>)
          .map((e) => TruckRestriction.fromJson(Map<String, dynamic>.from(e)))
          .where((t) {
            final loc = t.location;
            if (loc == null) return false;
            final lat = (loc['lat'] ?? loc['latitude']) as num?;
            final lng = (loc['lng'] ?? loc['lon'] ?? loc['longitude']) as num?;
            if (lat == null || lng == null) return false;
            return lng >= minLon && lng <= maxLon && lat >= minLat && lat <= maxLat;
          })
          .toList(growable: false);
      return list;
    } catch (e, st) {
      dev.log('fetchByBbox error: $e', stackTrace: st);
      rethrow;
    }
  }

  // Simple route hazard RPC wrapper. Expects a PostgreSQL function
  // route_hazards_simple(polyline json, trailer_height_ft numeric) returning setof json or record.
  Future<List<Map<String, dynamic>>> checkRouteHazardsSimple({
    required List<List<double>> polylineLatLngs,
    double? trailerHeightFt,
  }) async {
    try {
      final params = {
        'polyline': polylineLatLngs,
        if (trailerHeightFt != null) 'trailer_height_ft': trailerHeightFt,
      };
      final res = await _client.rpc('route_hazards_simple', params: params);
      final list = (res as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      return list;
    } catch (e, st) {
      dev.log('checkRouteHazardsSimple RPC error: $e', stackTrace: st);
      rethrow;
    }
  }

  // Legacy placeholder (kept for compatibility)
  Future<List<Map<String, dynamic>>> checkRouteCompliance({
    required List<List<double>> polylineLatLngs,
    required Map<String, dynamic> truckProfile,
  }) async {
    try {
      // Placeholder implementation — backend not yet deployed
      if (kDebugMode) {
        dev.log('checkRouteCompliance called with ${polylineLatLngs.length} pts; no backend deployed');
      }
      return const [];
    } catch (e, st) {
      dev.log('checkRouteCompliance error: $e', stackTrace: st);
      rethrow;
    }
  }
}
