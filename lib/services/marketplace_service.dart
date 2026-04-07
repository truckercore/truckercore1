// lib/services/marketplace_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/config/app_config.dart';
import '../core/ids/idempotency.dart';
import '../core/outbox/outbox_client.dart';

class MarketplaceLoad {
  final String id;
  final String origin;
  final String destination;
  final DateTime pickupAt;
  final DateTime dropoffAt;
  final String? equipment;
  final int payCents;
  const MarketplaceLoad({
    required this.id,
    required this.origin,
    required this.destination,
    required this.pickupAt,
    required this.dropoffAt,
    this.equipment,
    required this.payCents,
  });
  static MarketplaceLoad fromMap(Map<String, dynamic> r) => MarketplaceLoad(
    id: r['id']?.toString() ?? '',
    origin: r['origin']?.toString() ?? '',
    destination: r['destination']?.toString() ?? '',
    pickupAt:
        DateTime.tryParse(r['pickup_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    dropoffAt:
        DateTime.tryParse(r['dropoff_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    equipment: r['equipment'] as String?,
    payCents:
        (r['pay_cents'] as int?) ??
        ((r['pay_usd'] as num?)?.toDouble() ?? 0 * 100).round(),
  );
}

class MarketplaceOffer {
  final String id;
  final String loadId;
  final String bidderUserId;
  final int bidCents;
  final String message;
  final String status; // pending|accepted|rejected
  final DateTime createdAt;
  const MarketplaceOffer({
    required this.id,
    required this.loadId,
    required this.bidderUserId,
    required this.bidCents,
    required this.message,
    required this.status,
    required this.createdAt,
  });
  static MarketplaceOffer fromMap(Map<String, dynamic> r) => MarketplaceOffer(
    id: r['id']?.toString() ?? '',
    loadId: r['load_id']?.toString() ?? '',
    bidderUserId: r['bidder_user_id']?.toString() ?? '',
    bidCents: (r['bid_cents'] as int?) ?? 0,
    message: r['message']?.toString() ?? '',
    status: r['status']?.toString() ?? 'pending',
    createdAt:
        DateTime.tryParse(r['created_at']?.toString() ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );
}

class MarketplaceService {
  MarketplaceService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<List<MarketplaceLoad>> fetchOpenLoads({
    String? originQ,
    String? destinationQ,
    String? equipment,
    DateTime? date,
    double? minDollarPerMile,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    var sel = c.from('marketplace_loads').select().eq('status', 'open');
    if (originQ != null && originQ.trim().isNotEmpty) {
      sel = sel.ilike('origin', '%${originQ.trim()}%');
    }
    if (destinationQ != null && destinationQ.trim().isNotEmpty) {
      sel = sel.ilike('destination', '%${destinationQ.trim()}%');
    }
    if (equipment != null &&
        equipment.trim().isNotEmpty &&
        equipment != 'any') {
      sel = sel.eq('equipment', equipment.trim());
    }
    if (date != null) {
      final start = DateTime.utc(
        date.year,
        date.month,
        date.day,
      ).toIso8601String();
      final end = DateTime.utc(
        date.year,
        date.month,
        date.day,
        23,
        59,
        59,
      ).toIso8601String();
      sel = sel.gte('pickup_at', start).lte('pickup_at', end);
    }
    // Apply min $/mi server-side if you have miles/pay columns; otherwise fetch and filter client-side.
    final rows = await sel.order('pickup_at').limit(200);
    final list = (rows as List?) ?? const [];
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(MarketplaceLoad.fromMap)
        .toList();
  }

  Future<Map<String, dynamic>> postLoad({
    required String origin,
    required String destination,
    required DateTime pickupAt,
    required DateTime dropoffAt,
    required int payCents,
    String? equipment,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    final row = await c
        .from('marketplace_loads')
        .insert({
          'origin': origin,
          'destination': destination,
          'pickup_at': pickupAt.toUtc().toIso8601String(),
          'dropoff_at': dropoffAt.toUtc().toIso8601String(),
          'pay_cents': payCents,
          if (equipment != null) 'equipment': equipment,
          'status': 'open',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>> placeOffer({
    required String loadId,
    required String bidderUserId,
    required int bidCents,
    String? message,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    // Enqueue into action_outbox using OutboxClient helper
    final outbox = OutboxClient(c);
    final payload = {
      'load_id': loadId,
      'bidder_user_id': bidderUserId,
      'bid_cents': bidCents,
      'message': message ?? '',
    };
    final id = await outbox.enqueue(scope: 'offer_request', payload: payload, idempotencyKey: IdempotencyKeys.newKey());
    return {'id': id, 'status': 'pending'};
  }

  Future<List<MarketplaceOffer>> offersForMyPostedLoads({
    String? ownerUserId,
  }) async {
    final c = _maybe();
    if (c == null) return const [];
    // Join via RPC or do two-step: find my posted loads then offers
    final uid = ownerUserId ?? c.auth.currentUser?.id;
    if (uid == null) return const [];
    final loads = await c
        .from('marketplace_loads')
        .select('id')
        .eq('owner_user_id', uid);
    final loadsList = (loads as List?) ?? const [];
    final ids = loadsList.map((e) => (e as Map)['id'].toString()).toList();
    if (ids.isEmpty) return const [];
    final offers = await c
        .from('marketplace_offers')
        .select()
        .inFilter('load_id', ids)
        .order('created_at', ascending: false);
    final offersList = (offers as List?) ?? const [];
    return offersList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(MarketplaceOffer.fromMap)
        .toList();
  }

  Future<void> updateOfferStatus({
    required String offerId,
    required String status,
  }) async {
    final c = _maybe();
    if (c == null) throw Exception('Supabase not configured');
    await c
        .from('marketplace_offers')
        .update({'status': status})
        .eq('id', offerId);
  }
}

final marketplaceServiceProvider = Provider<MarketplaceService>(
  (ref) => MarketplaceService(ref),
);
