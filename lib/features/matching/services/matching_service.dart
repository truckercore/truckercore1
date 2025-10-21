// lib/features/matching/services/matching_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../common/services/loads_service.dart';

// Suggestion model
class LoadMatch {
  final String loadId;
  final String? driverUserId;
  final String suggestionDriverId;
  final double score; // 0..100
  final String rationale; // short explanation

  LoadMatch({
    required this.loadId,
    required this.driverUserId,
    required this.suggestionDriverId,
    required this.score,
    required this.rationale,
  });
}

class MatchingService {
  MatchingService(this._ref);
  final Ref _ref;

  // MVP data source: loads from LoadsService + mock available drivers.
  // Replace mockAvailableDrivers with your DriversService later.
  Future<List<LoadMatch>> getSuggestions() async {
    final loadsSvc = _ref.read(loadsServiceProvider);
    final loads = await loadsSvc.listLoads();

    if (loads.isEmpty) return const [];

    // Mock available drivers (replace with real driver directory later)
    final availableDrivers = <String>[
      '00000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000003',
    ];

    final suggestions = <LoadMatch>[];

    for (final l in loads) {
      // Skip if already assigned
      if (l.assignedDriverId != null) continue;

      // MVP scoring: random-ish but deterministic ordering by load id hash
      // Replace with: proximity + HOS + capacity later
      for (final d in availableDrivers) {
        final score = _score(l.id, d);
        final rationale = 'Nearby + available (MVP mock)';
        suggestions.add(
          LoadMatch(
            loadId: l.id,
            driverUserId: l.assignedDriverId,
            suggestionDriverId: d,
            score: score,
            rationale: rationale,
          ),
        );
      }
    }

    // Keep top suggestion per load
    final byLoad = <String, LoadMatch>{};
    for (final s in suggestions) {
      final cur = byLoad[s.loadId];
      if (cur == null || s.score > cur.score) {
        byLoad[s.loadId] = s;
      }
    }

    // Return sorted by score desc
    final result = byLoad.values.toList();
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  double _score(String loadId, String driverId) {
    // Simple stable hash combo to produce a score 60..95 (MVP)
    final h = loadId.hashCode ^ driverId.hashCode;
    final norm = (h & 0xFFFF) / 0xFFFF;
    return 60 + norm * 35;
  }
}

final matchingServiceProvider = Provider<MatchingService>(
  (ref) => MatchingService(ref),
);
