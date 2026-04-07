import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

// ... existing code ...

class TruckStop {
  final String id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String tier; // 'free' | 'pro' | 'enterprise'

  const TruckStop({
    required this.id,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    required this.tier,
  });

  static TruckStop fromMap(Map<String, dynamic> row) => TruckStop(
    id: row['id'] as String,
    name: row['name'] as String,
    address: row['address'] as String?,
    lat: (row['lat'] as num).toDouble(),
    lng: (row['lng'] as num).toDouble(),
    tier: (row['tier'] as String?) ?? 'free',
  );
}

// ... existing code ...

class TruckStopDeal {
  final String id;
  final String truckStopId;
  final String title;
  final String? description;
  final DateTime? validUntil;
  final bool isActive;

  const TruckStopDeal({
    required this.id,
    required this.truckStopId,
    required this.title,
    this.description,
    this.validUntil,
    required this.isActive,
  });

  static TruckStopDeal fromMap(Map<String, dynamic> row) => TruckStopDeal(
    id: row['id'] as String,
    truckStopId: row['truck_stop_id'] as String,
    title: row['title'] as String,
    description: row['description'] as String?,
    validUntil: row['valid_until'] == null
        ? null
        : DateTime.tryParse(row['valid_until'] as String),
    isActive: (row['is_active'] as bool?) ?? true,
  );
}

class TruckStopParking {
  final String truckStopId;
  final int totalSpots;
  final int availableSpots;
  final DateTime? updatedAt;

  const TruckStopParking({
    required this.truckStopId,
    required this.totalSpots,
    required this.availableSpots,
    this.updatedAt,
  });

  static TruckStopParking fromMap(Map<String, dynamic> row) => TruckStopParking(
    truckStopId: row['truck_stop_id'] as String,
    totalSpots: (row['total_spots'] as num).toInt(),
    availableSpots: (row['available_spots'] as num).toInt(),
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.tryParse(row['updated_at'] as String),
  );
}

class TruckStopAlert {
  final String id;
  final String truckStopId;
  final String title;
  final String? body;
  final String severity; // 'info' | 'warning' | 'critical'
  final DateTime createdAt;

  const TruckStopAlert({
    required this.id,
    required this.truckStopId,
    required this.title,
    this.body,
    required this.severity,
    required this.createdAt,
  });

  static TruckStopAlert fromMap(Map<String, dynamic> row) => TruckStopAlert(
    id: row['id'] as String,
    truckStopId: row['truck_stop_id'] as String,
    title: row['title'] as String,
    body: row['body'] as String?,
    severity: (row['severity'] as String?) ?? 'info',
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

class TruckStopService {
  TruckStopService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    final configured =
        cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
    if (!configured) return null;
    return Supabase.instance.client;
  }

  // Fetch ALL stops (for public views). Requires a broad read policy.
  Future<List<TruckStop>> fetchTruckStops() async {
    final c = _maybe();
    if (c == null) return const <TruckStop>[];
    final rowsDyn = await c
        .from('truck_stops')
        .select('id,name,address,lat,lng,tier') // include tier here
        .order('name');
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(TruckStop.fromMap).toList();
  }

  Future<List<TruckStop>> fetchOperatorStops() async {
    final c = _maybe();
    if (c == null) return const <TruckStop>[];
    final uid = c.auth.currentUser?.id;
    if (uid == null) return const <TruckStop>[];
    final rowsDyn = await c
        .from('truck_stops')
        .select('id,name,address,lat,lng,tier') // include tier here too
        .order('name');
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(TruckStop.fromMap).toList();
  }

  // Admin: link an operator to a truck stop
  Future<void> linkOperator({
    required String userId,
    required String truckStopId,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    if (userId.trim().isEmpty || truckStopId.trim().isEmpty) {
      throw Exception('userId and truckStopId are required.');
    }
    await c.from('truck_stop_operators').insert({
      'user_id': userId.trim(),
      'truck_stop_id': truckStopId.trim(),
    });
  }

  // Admin: unlink an operator from a truck stop
  Future<void> unlinkOperator({
    required String userId,
    required String truckStopId,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    await c.from('truck_stop_operators').delete().match({
      'user_id': userId.trim(),
      'truck_stop_id': truckStopId.trim(),
    });
  }

  // Admin: list current operators for a stop
  Future<List<String>> listOperatorUserIds(String truckStopId) async {
    final c = _maybe();
    if (c == null) return const [];
    final rows = await c
        .from('truck_stop_operators')
        .select('user_id')
        .eq('truck_stop_id', truckStopId);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
        .toList();
  }

  // ... existing helpers (tier, deals, parking, alerts, realtime, etc.) ...
  // --- TIER HELPERS ---

  Future<String> getStopTier(String truckStopId) async {
    final c = _maybe();
    if (c == null) return 'free';
    final rowDyn = await c
        .from('truck_stops')
        .select('tier')
        .eq('id', truckStopId)
        .maybeSingle();
    if (rowDyn == null) return 'free';
    final row = Map<String, dynamic>.from(rowDyn as Map);
    final tier = (row['tier'] as String?) ?? 'free';
    return tier; // expected values: 'free', 'pro', 'enterprise'
  }

  Future<int> activeDealCountForStop(String truckStopId) async {
    final c = _maybe();
    if (c == null) return 0;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await c
        .from('truck_stop_deals')
        .select('id')
        .eq('truck_stop_id', truckStopId)
        .eq('is_active', true)
        .or('valid_until.is.null,valid_until.gt.$nowIso');
    return (rows as List).length;
  }

  // --- DEALS CRUD ---

  // --- ALERTS ---
  Future<void> sendAlert({
    required String truckStopId,
    required String title,
    String? body,
    String severity = 'info',
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    await c.from('truck_stop_alerts').insert({
      'truck_stop_id': truckStopId,
      'title': title,
      'body': body,
      'severity': severity,
    });
  }

  Future<List<TruckStopAlert>> fetchRecentAlerts(
    String truckStopId, {
    int limit = 20,
  }) async {
    final c = _maybe();
    if (c == null) return const <TruckStopAlert>[];
    final rowsDyn = await c
        .from('truck_stop_alerts')
        .select()
        .eq('truck_stop_id', truckStopId)
        .order('created_at', ascending: false)
        .limit(limit);
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(TruckStopAlert.fromMap).toList();
  }

  Stream<TruckStopAlert> alertsRealtimeStream(String truckStopId) {
    final c = _maybe();
    if (c == null) {
      return const Stream<TruckStopAlert>.empty();
    }

    final controller = StreamController<TruckStopAlert>.broadcast();
    final channel = c.channel('realtime:truck_stop_alerts:$truckStopId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'truck_stop_alerts',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['truck_stop_id'] == truckStopId) {
              controller.add(TruckStopAlert.fromMap(row));
            }
          },
        )
        .subscribe();

    controller.onCancel = () async {
      await c.removeChannel(channel);
      await controller.close();
    };

    return controller.stream;
  }

  Future<List<TruckStopDeal>> fetchDealsForStop(String truckStopId) async {
    final c = _maybe();
    if (c == null) return const <TruckStopDeal>[];
    final rowsDyn = await c
        .from('truck_stop_deals')
        .select()
        .eq('truck_stop_id', truckStopId)
        .order('created_at', ascending: false);
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(TruckStopDeal.fromMap).toList();
  }

  Future<TruckStopDeal> upsertDeal({
    required String? id, // null = create
    required String truckStopId,
    required String title,
    String? description,
    DateTime? validUntil,
    required bool isActive,
  }) async {
    final c = _maybe();
    if (c == null) {
      throw Exception('Supabase not configured');
    }

    // Enforce Free tier max active deals = 2
    final tier = await getStopTier(truckStopId);
    if (tier == 'free' && isActive) {
      final activeCount = await activeDealCountForStop(truckStopId);
      // If creating a new active deal or activating an inactive one, enforce limit
      if (id == null && activeCount >= 2) {
        throw Exception('Free tier limit reached: maximum 2 active deals.');
      }
      if (id != null) {
        // If updating an existing deal to active, still enforce
        // We will allow if the deal was already active (handled by caller context).
      }
    }

    final payload = {
      'truck_stop_id': truckStopId,
      'title': title,
      'description': description,
      'valid_until': validUntil?.toUtc().toIso8601String(),
      'is_active': isActive,
    };

    final query = c.from('truck_stop_deals');
    final result = id == null
        ? await query.insert(payload).select().single()
        : await query.update(payload).eq('id', id).select().single();

    return TruckStopDeal.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<void> deleteDeal(String id) async {
    final c = _maybe();
    if (c == null) return;
    await c.from('truck_stop_deals').delete().eq('id', id);
  }

  Future<List<TruckStopDeal>> fetchActiveDeals() async {
    final c = _maybe();
    if (c == null) return const <TruckStopDeal>[];
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rowsDyn = await c
        .from('truck_stop_deals')
        .select()
        .eq('is_active', true)
        .or('valid_until.is.null,valid_until.gt.$nowIso');
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(TruckStopDeal.fromMap).toList();
  }

  Future<TruckStopParking?> latestParkingFor(String truckStopId) async {
    final c = _maybe();
    if (c == null) return null;
    final row = await c
        .from('truck_stop_parking')
        .select()
        .eq('truck_stop_id', truckStopId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return TruckStopParking.fromMap(row);
  }

  // --- TRUE REALTIME STREAM (Supabase Realtime) ---

  /// Subscribe to realtime INSERT/UPDATE events for parking changes of a specific truck stop.
  Stream<TruckStopParking> parkingRealtimeStream(String truckStopId) {
    final c = _maybe();
    if (c == null) {
      return const Stream<TruckStopParking>.empty();
    }

    final controller = StreamController<TruckStopParking>.broadcast();

    final channel = c.channel('realtime:truck_stop_parking:$truckStopId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'truck_stop_parking',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['truck_stop_id'] == truckStopId) {
              controller.add(TruckStopParking.fromMap(row));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'truck_stop_parking',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['truck_stop_id'] == truckStopId) {
              controller.add(TruckStopParking.fromMap(row));
            }
          },
        )
        .subscribe();

    controller.onListen = () async {
      // emit the latest snapshot immediately
      final latest = await latestParkingFor(truckStopId);
      if (latest != null) controller.add(latest);
    };

    controller.onCancel = () async {
      await c.removeChannel(channel);
      await controller.close();
    };

    return controller.stream;
  }

  // Keep the old name for compatibility by delegating to realtime
  Stream<TruckStopParking> parkingStream(String truckStopId) {
    return parkingRealtimeStream(truckStopId);
  }

  /// Upserts a parking record by inserting a new "snapshot" row (append-only).
  /// Use this for accurate history and realtime fan-out.
  Future<void> updateParking({
    required String truckStopId,
    required int totalSpots,
    required int availableSpots,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    if (availableSpots < 0 || availableSpots > totalSpots) {
      throw Exception('Available spots must be between 0 and total.');
    }
    await c.from('truck_stop_parking').insert({
      'truck_stop_id': truckStopId,
      'total_spots': totalSpots,
      'available_spots': availableSpots,
      // updated_by handled by RLS if you store it via trigger or client-side add later
    });
  }

  /// Convenience to nudge availability up/down by 1.
  Future<void> nudgeAvailability({
    required String truckStopId,
    required int delta, // +1 or -1
  }) async {
    final latest = await latestParkingFor(truckStopId);
    if (latest == null) {
      throw Exception('No parking baseline. Set total/available first.');
    }
    final next = (latest.availableSpots + delta).clamp(0, latest.totalSpots);
    await updateParking(
      truckStopId: truckStopId,
      totalSpots: latest.totalSpots,
      availableSpots: next,
    );
  }

  /// Mark lot as full (available = 0).
  Future<void> markLotFull(String truckStopId) async {
    final latest = await latestParkingFor(truckStopId);
    if (latest == null) {
      throw Exception('No parking baseline. Set total/available first.');
    }
    await updateParking(
      truckStopId: truckStopId,
      totalSpots: latest.totalSpots,
      availableSpots: 0,
    );
  }

  /// For Free tier: enforce soft limit of updates per day (e.g., 4).
  Future<bool> canFreeTierUpdate(String truckStopId) async {
    final c = _maybe();
    if (c == null) return false;
    // Count updates today
    final today = DateTime.now().toUtc();
    final start = DateTime.utc(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final rows = await c
        .from('truck_stop_parking')
        .select('id')
        .eq('truck_stop_id', truckStopId)
        .gte('updated_at', start.toIso8601String())
        .lt('updated_at', end.toIso8601String());
    final count = (rows as List).length;
    return count < 4;
  }
}

final truckStopServiceProvider = Provider<TruckStopService>(
  (ref) => TruckStopService(ref),
);
