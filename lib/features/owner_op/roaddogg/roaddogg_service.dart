import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/config/app_config.dart';
import '../../../common/services/loads_service.dart';

class RoadDoggSuggestion {
  final LoadItem load;
  final double? estimatedCpm; // revenue/miles if available, else null
  final int? estimatedDeadheadMiles; // placeholder for MVP
  final String aiNote; // short commentary
  const RoadDoggSuggestion({
    required this.load,
    this.estimatedCpm,
    this.estimatedDeadheadMiles,
    required this.aiNote,
  });
}

class BrokerRequestItem {
  final String id;
  final String loadId;
  final String ownerOpId;
  final String? brokerId;
  final String? message;
  final String status;
  final DateTime createdAt;
  const BrokerRequestItem({
    required this.id,
    required this.loadId,
    required this.ownerOpId,
    this.brokerId,
    this.message,
    required this.status,
    required this.createdAt,
  });
  factory BrokerRequestItem.fromRow(Map<String, dynamic> r) =>
      BrokerRequestItem(
        id: r['id'] as String,
        loadId: r['load_id'] as String,
        ownerOpId: r['owner_op_id'] as String,
        brokerId: r['broker_id'] as String?,
        message: r['message'] as String?,
        status: (r['status'] as String?) ?? 'requested',
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

class RoadDoggService {
  RoadDoggService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  Future<int> weeklyQueryCount() async {
    final c = _maybe();
    if (c == null) return 0; // allow in mock mode
    final uid = c.auth.currentUser?.id;
    if (uid == null) return 0;
    final now = DateTime.now().toUtc();
    final startOfWeek = now.subtract(
      Duration(days: now.weekday % 7),
    ); // rough week window (Sun-based)
    final rows = await c
        .from('roaddogg_queries')
        .select('id')
        .eq('owner_op_id', uid)
        .gte('created_at', startOfWeek.toIso8601String());
    return (rows as List).length;
  }

  Future<void> recordQuery({
    required String text,
    Map<String, dynamic>? filters,
    List<String>? loadIds,
  }) async {
    final c = _maybe();
    if (c == null) return;
    final uid = c.auth.currentUser?.id;
    if (uid == null) return;
    await c.from('roaddogg_queries').insert({
      'owner_op_id': uid,
      'query_text': text,
      'filters': filters,
      'loads_returned': loadIds,
    });
  }

  Future<List<RoadDoggSuggestion>> findSuggestions({
    required String text,
    Map<String, dynamic>? filters,
    required bool isPremium,
  }) async {
    if (kDebugMode) {
      print(
        '[ANALYTICS] roaddogg_query_submitted text="${text.trim()}" filters=${filters ?? {}} tier=${isPremium ? 'premium' : 'free'}',
      );
    }
    // Basic MVP: pull loads and rank lightly by recency/pickup date; attach placeholder AI notes.
    final loads = await _ref.read(loadsServiceProvider).listLoads();
    var items = loads;
    // Simple textual filter: if text contains origin/destination keywords
    final q = text.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items
          .where(
            (l) =>
                l.origin.toLowerCase().contains(q) ||
                l.destination.toLowerCase().contains(q),
          )
          .toList();
    }
    // Sort by pickupAt ascending as proxy
    items.sort((a, b) => a.pickupAt.compareTo(b.pickupAt));

    // Map to suggestions with placeholder CPM and notes
    final suggestions = items.map((l) {
      final hasRevenue = l.revenueCents > 0;
      final cpm = hasRevenue
          ? (l.revenueCents / 100.0) / 500.0
          : null; // assume ~500mi trip for MVP
      final note = hasRevenue
          ? 'Solid CPM candidate.'
          : 'Rate on request — consider messaging broker.';
      return RoadDoggSuggestion(
        load: l,
        estimatedCpm: cpm,
        estimatedDeadheadMiles: 45,
        aiNote: note,
      );
    }).toList();

    // Tier limit: Free shows top 3; Pro/Enterprise full list
    final capped = isPremium ? suggestions : suggestions.take(3).toList();

    // Record query (async fire-and-forget)
    try {
      await recordQuery(
        text: text,
        filters: filters,
        loadIds: capped.map((s) => s.load.id).toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('[RoadDogg] recordQuery failed: $e');
      }
    }

    if (kDebugMode) {
      print(
        '[ANALYTICS] roaddogg_results_viewed result_count=${capped.length}',
      );
    }

    return capped;
  }

  Future<void> sendRequest({
    required String loadId,
    String? message,
    String? brokerId,
  }) async {
    if (kDebugMode) {
      print('[ANALYTICS] roaddogg_apply_clicked load_id=$loadId');
    }
    final c = _maybe();
    if (c == null) return; // mock mode: pretend success
    final uid = c.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await c.from('broker_requests').insert({
      'load_id': loadId,
      'broker_id': brokerId,
      'owner_op_id': uid,
      'message': message,
      'status': 'requested',
    });
  }

  Future<List<BrokerRequestItem>> listMyRequests() async {
    final c = _maybe();
    if (c == null) return const [];
    final uid = c.auth.currentUser?.id;
    if (uid == null) return const [];
    final rowsDyn = await c
        .from('broker_requests')
        .select()
        .eq('owner_op_id', uid)
        .order('created_at', ascending: false);
    final rows = (rowsDyn as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return rows.map(BrokerRequestItem.fromRow).toList();
  }
}

final roadDoggServiceProvider = Provider<RoadDoggService>(
  (ref) => RoadDoggService(ref),
);
