// lib/common/services/loads_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class LoadItem {
  final String id;
  final String origin;
  final String destination;
  final DateTime pickupAt;
  final DateTime dropoffAt;
  final String
  status; // draft | assigned | in_transit | delivered | canceled | covered
  final String? assignedDriverId;
  // Optional financial and posting fields (default to zero/null if absent)
  final int revenueCents;
  final int fuelCents;
  final int tollsCents;
  final int maintenanceCents;
  final int wageCents;
  final String? vehicleType; // e.g., dry_van, reefer, flatbed
  final double? originLat;
  final double? originLon;
  final double? postedRateUsdPerMi;
  final int? estimatedMiles;

  const LoadItem({
    required this.id,
    required this.origin,
    required this.destination,
    required this.pickupAt,
    required this.dropoffAt,
    required this.status,
    this.assignedDriverId,
    this.revenueCents = 0,
    this.fuelCents = 0,
    this.tollsCents = 0,
    this.maintenanceCents = 0,
    this.wageCents = 0,
    this.vehicleType,
    this.originLat,
    this.originLon,
    this.postedRateUsdPerMi,
    this.estimatedMiles,
  });

  static LoadItem fromMap(Map<String, dynamic> row) => LoadItem(
    id: row['id'] as String,
    origin: row['origin'] as String,
    destination: row['destination'] as String,
    pickupAt: DateTime.parse(row['pickup_at'] as String),
    dropoffAt: DateTime.parse(row['dropoff_at'] as String),
    status: row['status'] as String? ?? 'draft',
    assignedDriverId: row['assigned_driver_id'] as String?,
    revenueCents: (row['revenue_cents'] as int?) ?? 0,
    fuelCents: (row['fuel_cents'] as int?) ?? 0,
    tollsCents: (row['tolls_cents'] as int?) ?? 0,
    maintenanceCents: (row['maintenance_cents'] as int?) ?? 0,
    wageCents: (row['wage_cents'] as int?) ?? 0,
    vehicleType: row['vehicle_type'] as String?,
    originLat: (row['origin_lat'] as num?)?.toDouble(),
    originLon: (row['origin_lon'] as num?)?.toDouble(),
    postedRateUsdPerMi: (row['posted_rate_usd_per_mi'] as num?)?.toDouble(),
    estimatedMiles: row['estimated_miles'] as int?,
  );

  Map<String, dynamic> toInsert() => {
    'origin': origin,
    'destination': destination,
    'pickup_at': pickupAt.toUtc().toIso8601String(),
    'dropoff_at': dropoffAt.toUtc().toIso8601String(),
    'status': status,
    'assigned_driver_id': assignedDriverId,
    'revenue_cents': revenueCents,
    'fuel_cents': fuelCents,
    'tolls_cents': tollsCents,
    'maintenance_cents': maintenanceCents,
    'wage_cents': wageCents,
    if (vehicleType != null) 'vehicle_type': vehicleType,
    if (originLat != null) 'origin_lat': originLat,
    if (originLon != null) 'origin_lon': originLon,
    if (postedRateUsdPerMi != null)
      'posted_rate_usd_per_mi': postedRateUsdPerMi,
    if (estimatedMiles != null) 'estimated_miles': estimatedMiles,
  };
}

class LoadsService {
  LoadsService(this._ref);
  final Ref _ref;

  // Loads assigned to the currently authenticated driver (by assigned_driver_id)
  Future<List<LoadItem>> listAssignedToMe() async {
    final c = _maybe();
    if (c == null) return const [];
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const [];
    final rowsDyn = await c
        .from('loads')
        .select()
        .eq('assigned_driver_id', user.id)
        .order('pickup_at');
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(LoadItem.fromMap).toList();
  }

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<LoadItem>> listLoads() async {
    final c = _maybe();
    if (c == null) return const [];
    final rowsDyn = await c.from('loads').select().order('pickup_at');
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(LoadItem.fromMap).toList();
  }

  Future<LoadItem> getLoad(String id) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final rowDyn = await c.from('loads').select().eq('id', id).single();
    final row = Map<String, dynamic>.from(rowDyn as Map);
    return LoadItem.fromMap(row);
  }

  Future<LoadItem> createLoad({
    required String origin,
    required String destination,
    required DateTime pickupAt,
    required DateTime dropoffAt,
    String? vehicleType,
    double? postedRateUsdPerMi,
    int? estimatedMiles,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    // compute revenue if rpm and miles provided
    int revenueCents = 0;
    if (postedRateUsdPerMi != null &&
        estimatedMiles != null &&
        estimatedMiles > 0) {
      revenueCents = (postedRateUsdPerMi * estimatedMiles * 100).round();
    }
    final payload = {
      'origin': origin,
      'destination': destination,
      'pickup_at': pickupAt.toUtc().toIso8601String(),
      'dropoff_at': dropoffAt.toUtc().toIso8601String(),
      'status': 'draft',
      'assigned_driver_id': null,
      'revenue_cents': revenueCents,
      'fuel_cents': 0,
      'tolls_cents': 0,
      'maintenance_cents': 0,
      'wage_cents': 0,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (postedRateUsdPerMi != null)
        'posted_rate_usd_per_mi': postedRateUsdPerMi,
      if (estimatedMiles != null) 'estimated_miles': estimatedMiles,
    };
    final rowDyn = await c.from('loads').insert(payload).select().single();
    final row = Map<String, dynamic>.from(rowDyn as Map);
    return LoadItem.fromMap(row);
  }

  Future<void> assignDriver({
    required String loadId,
    required String driverUserId,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final res = await c
        .from('loads')
        .update({'assigned_driver_id': driverUserId, 'status': 'assigned'})
        .eq('id', loadId)
        .select('id')
        .maybeSingle();
    // Supabase Flutter throws on error, but double-check the result
    if (res == null) {
      throw Exception(
        'Failed to assign driver: load not found or no rows updated',
      );
    }
  }

  Future<void> updateStatus({
    required String loadId,
    required String status,
    String? idempotencyKey,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    // Simple idempotency: if provided, record a dispatch_event and no-op if exists (best-effort)
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      try {
        final exists = await c
            .from('dispatch_events')
            .select('id')
            .eq('event_type', 'update_status')
            .eq('details->>key', idempotencyKey)
            .maybeSingle();
        if (exists != null) return;
        await c.from('dispatch_events').insert({
          'event_type': 'update_status',
          'details': {
            'load_id': loadId,
            'status': status,
            'key': idempotencyKey,
          },
        });
      } catch (_) {}
    }
    await c.from('loads').update({'status': status}).eq('id', loadId);
  }

  Future<void> instantBook({
    required String loadId,
    required String driverUserId,
    String? idempotencyKey,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final res = await c
        .from('loads')
        .update({'assigned_driver_id': driverUserId, 'status': 'covered'})
        .eq('id', loadId)
        .select('id')
        .maybeSingle();
    if (res == null) {
      throw Exception('Instant Book failed: load not found or no rows updated');
    }
    try {
      // Simple idempotency: prevent duplicate fee row by unique (load_id,type) or best-effort check here
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        try {
          final exists = await c
              .from('dispatch_events')
              .select('id')
              .eq('event_type', 'instant_book')
              .eq('details->>key', idempotencyKey)
              .maybeSingle();
          if (exists == null) {
            await c.from('dispatch_events').insert({
              'event_type': 'instant_book',
              'details': {
                'load_id': loadId,
                'driver_user_id': driverUserId,
                'key': idempotencyKey,
              },
            });
          } else {
            return;
          }
        } catch (_) {}
      }
      // Insert marketplace fee transaction (default $10 => 1000 cents)
      await c.from('transactions').insert({
        'load_id': loadId,
        'driver_user_id': driverUserId,
        'fee_cents': 1000,
        'type': 'booking_fee',
      });
    } catch (_) {
      // Non-fatal: booking succeeded even if fee insert fails
    }
  }

  Future<void> updateFinancials({
    required String loadId,
    required int revenueCents,
    required int fuelCents,
    required int tollsCents,
    required int maintenanceCents,
    required int wageCents,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    await c
        .from('loads')
        .update({
          'revenue_cents': revenueCents,
          'fuel_cents': fuelCents,
          'tolls_cents': tollsCents,
          'maintenance_cents': maintenanceCents,
          'wage_cents': wageCents,
        })
        .eq('id', loadId);
  }
}

final loadsServiceProvider = Provider<LoadsService>((ref) => LoadsService(ref));
