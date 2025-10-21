import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../common/config/app_config.dart';
import '../../common/state/phase2_flags.dart';
import '../../common/state/plan_tier.dart';

class TrihaulOption {
  final List<String> legs; // e.g., ["ATL->MEM","MEM->DFW","DFW->ATL"]
  final double estMiles;
  final double estRevenue;
  final double estPpm;
  final String notes;
  const TrihaulOption({
    required this.legs,
    required this.estMiles,
    required this.estRevenue,
    required this.estPpm,
    this.notes = '',
  });
}

class TrihaulSuggestion {
  final String id; // suggestion row id
  final List<TrihaulOption> options;
  const TrihaulSuggestion({required this.id, required this.options});
}

class TrihaulService {
  TrihaulService(this._ref);
  final Ref _ref;

  SupabaseClient? _maybe() {
    final cfg = _ref.read(appConfigProvider);
    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return null;
    return Supabase.instance.client;
  }

  // Suggest trihaul options (calls Edge Function if configured, else returns mock suggestions)
  Future<TrihaulSuggestion> suggest({
    required String origin,
    required String dest,
    required String equipment,
    double minPpm = 2.0,
    int maxDeadheadMi = 100,
  }) async {
    final flags = _ref.read(phase2FlagsProvider);
    if (flags.mock) {
      // enforce feature flag and plan tier
      if (!flags.trihaul) {
        throw Exception('404: TriHaul API disabled');
      }
      final plan = _ref.read(planTierProvider);
      if (plan != PlanTier.premium) {
        throw Exception('403: plan_tier < premium');
      }
      // Basic inputs validation
      if (origin.isEmpty || dest.isEmpty || equipment.isEmpty) {
        throw Exception('400: invalid body');
      }
      // Static suggestions per spec using zips if they look like 5-digit; else use provided strings
      String zip(String s) => s;
      final id = 'mock_suggestion_30301_75201';
      final opts = [
        TrihaulOption(
          legs: [
            '${zip(origin)}->38103',
            '38103->${zip(dest)}',
            '${zip(dest)}->${zip(origin)}',
          ],
          estMiles: 1626.0,
          estRevenue: 3825.00,
          estPpm: 2.353,
        ),
        TrihaulOption(
          legs: [
            '${zip(origin)}->70802',
            '70802->${zip(dest)}',
            '${zip(dest)}->${zip(origin)}',
          ],
          estMiles: 1821.0,
          estRevenue: 4040.00,
          estPpm: 2.219,
        ),
        TrihaulOption(
          legs: [
            '${zip(origin)}->72201',
            '72201->${zip(dest)}',
            '${zip(dest)}->${zip(origin)}',
          ],
          estMiles: 1621.0,
          estRevenue: 3694.00,
          estPpm: 2.278,
        ),
      ];
      return TrihaulSuggestion(id: id, options: opts);
    }
    final c = _maybe();
    if (c == null) {
      return _demo(origin, dest);
    }
    try {
      final resp = await c.functions.invoke(
        'trihaul_suggest',
        body: {
          'origin': origin,
          'dest': dest,
          'equipment': equipment,
          'min_ppm': minPpm,
          'max_deadhead_mi': maxDeadheadMi,
        },
      );
      final data = resp.data;
      if (data is Map && data['id'] != null && data['options'] is List) {
        final id = data['id'].toString();
        final options = (data['options'] as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return TrihaulOption(
            legs: (m['legs'] as List).map((x) => x.toString()).toList(),
            estMiles: (m['est_miles'] as num).toDouble(),
            estRevenue: (m['est_revenue'] as num).toDouble(),
            estPpm: (m['est_ppm'] as num).toDouble(),
            notes: m['notes']?.toString() ?? '',
          );
        }).toList();
        return TrihaulSuggestion(id: id, options: options);
      }
    } catch (_) {}
    return _demo(origin, dest);
  }

  Future<bool> accept({required String suggestionId}) async {
    final flags = _ref.read(phase2FlagsProvider);
    if (flags.mock) {
      // No DB writes in mock mode
      return true;
    }
    final c = _maybe();
    if (c == null) return true; // demo
    try {
      await c
          .from('trihaul_suggestions')
          .update({'accepted': true})
          .eq('id', suggestionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  TrihaulSuggestion _demo(String o, String d) {
    final id = 'local_demo_${DateTime.now().millisecondsSinceEpoch}';
    final opts = <TrihaulOption>[
      TrihaulOption(
        legs: ['$o->MEM', 'MEM->$d', '$d->$o'],
        estMiles: 1580,
        estRevenue: 4200,
        estPpm: 2.66,
        notes: 'Adds Memphis midpoint',
      ),
      TrihaulOption(
        legs: ['$o->STL', 'STL->$d', '$d->$o'],
        estMiles: 1640,
        estRevenue: 4300,
        estPpm: 2.62,
        notes: 'St. Louis option',
      ),
      TrihaulOption(
        legs: ['$o->BHM', 'BHM->$d', '$d->$o'],
        estMiles: 1705,
        estRevenue: 4480,
        estPpm: 2.63,
        notes: 'Birmingham option',
      ),
    ];
    return TrihaulSuggestion(id: id, options: opts);
  }
}

final trihaulServiceProvider = Provider<TrihaulService>(
  (ref) => TrihaulService(ref),
);
