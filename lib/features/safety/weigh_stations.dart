import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeighStation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String highway;
  final String direction; // N/S/E/W
  final WeighStatus status; // open/closed/unknown
  final DateTime? lastUpdated;
  final String source; // partner/community/diy
  final double confidence; // 0..1

  const WeighStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.highway,
    required this.direction,
    this.status = WeighStatus.unknown,
    this.lastUpdated,
    this.source = 'diy',
    this.confidence = 0.3,
  });
}

enum WeighStatus { open, closed, unknown }

class WeighAlert {
  final String stationId;
  final WeighStatus status;
  final DateTime eta;
  final bool acknowledged;
  final DateTime? snoozedUntil;
  final String source; // official|crowd|inferred
  final double confidence;
  const WeighAlert({
    required this.stationId,
    required this.status,
    required this.eta,
    this.acknowledged = false,
    this.snoozedUntil,
    this.source = 'crowd',
    this.confidence = 0.5,
  });

  WeighAlert copyWith({
    WeighStatus? status,
    DateTime? eta,
    bool? acknowledged,
    DateTime? snoozedUntil,
    String? source,
    double? confidence,
  }) => WeighAlert(
    stationId: stationId,
    status: status ?? this.status,
    eta: eta ?? this.eta,
    acknowledged: acknowledged ?? this.acknowledged,
    snoozedUntil: snoozedUntil ?? this.snoozedUntil,
    source: source ?? this.source,
    confidence: confidence ?? this.confidence,
  );
}

// Simple in-memory DIY vote model (MVP) --------------------------------------------------
class _VoteEntry {
  WeighStatus status;
  DateTime ts;
  _VoteEntry(this.status, this.ts);
}

final _weighVotesProvider = StateProvider<Map<String, List<_VoteEntry>>>(
  (ref) => {},
);

// A tiny mocked database of stations (subset, for MVP). In real app, fetch from backend/POI.
final weighStationsProvider = Provider<List<WeighStation>>(
  (ref) => const [
    WeighStation(
      id: 'I-80_WY_153_WB',
      name: 'I-80 Evanston POE',
      lat: 41.2683,
      lng: -110.9633,
      highway: 'I-80',
      direction: 'WB',
    ),
    WeighStation(
      id: 'I-90_SD_112_EB',
      name: 'I-90 Wall POE',
      lat: 43.9927,
      lng: -102.2410,
      highway: 'I-90',
      direction: 'EB',
    ),
    WeighStation(
      id: 'I-5_OR_260_NB',
      name: 'I-5 Ashland POE',
      lat: 42.0342,
      lng: -122.5837,
      highway: 'I-5',
      direction: 'NB',
    ),
  ],
);

// Compute status from votes with decay. Prefer recent votes; decay to unknown after 60 minutes.
WeighStatus _computeStatusFromVotes(List<_VoteEntry> votes, DateTime now) {
  votes = votes.where((v) => now.difference(v.ts).inMinutes <= 60).toList();
  if (votes.isEmpty) return WeighStatus.unknown;
  final int open = votes.where((v) => v.status == WeighStatus.open).length;
  final int closed = votes.length - open;
  if (open == closed) return WeighStatus.unknown;
  return open > closed ? WeighStatus.open : WeighStatus.closed;
}

// Very rough distance calc (Haversine)
double _haversineMiles(double lat1, double lon1, double lat2, double lon2) {
  const R = 3958.8; // miles
  final double dLat = (lat2 - lat1) * pi / 180;
  final double dLon = (lon2 - lon1) * pi / 180;
  final double a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

class RouteStationMatch {
  final WeighStation station;
  final double distanceMilesAhead;
  final Duration eta;
  const RouteStationMatch({
    required this.station,
    required this.distanceMilesAhead,
    required this.eta,
  });
}

final approachAlertsProvider =
    StateNotifierProvider<ApproachAlertsController, List<WeighAlert>>((ref) {
      return ApproachAlertsController(ref);
    });

class ApproachAlertsController extends StateNotifier<List<WeighAlert>> {
  ApproachAlertsController(this._ref) : super(const []);
  final Ref _ref;

  // For MVP, accept current position and avg speed to project ETA.
  void evaluateApproach({
    required double currLat,
    required double currLng,
    required double avgSpeedMph,
  }) {
    final stations = _ref.read(weighStationsProvider);
    final votes = _ref.read(_weighVotesProvider);
    final now = DateTime.now().toUtc();

    final List<RouteStationMatch> candidates = [];
    for (final s in stations) {
      final dist = _haversineMiles(currLat, currLng, s.lat, s.lng);
      if (dist <= 200) {
        // only consider within 200 miles corridor for MVP
        final etaHours = (avgSpeedMph <= 5)
            ? double.infinity
            : dist / avgSpeedMph;
        final eta = etaHours.isInfinite
            ? const Duration(hours: 99)
            : Duration(minutes: (etaHours * 60).round());
        candidates.add(
          RouteStationMatch(station: s, distanceMilesAhead: dist, eta: eta),
        );
      }
    }

    // Sort by ETA ascending
    candidates.sort((a, b) => a.eta.compareTo(b.eta));

    final List<WeighAlert> newAlerts = List.from(state);
    for (final m in candidates) {
      if (m.eta > const Duration(minutes: 15)) continue; // alert window 15 min
      final vs = votes[m.station.id] ?? const <_VoteEntry>[];
      final st = _computeStatusFromVotes(vs, now);
      final etaAbs = now.add(m.eta);
      // derive confidence from votes volume and recency
      final recentVotes = vs
          .where((v) => now.difference(v.ts).inMinutes <= 60)
          .length;
      final confidence = (recentVotes / 5).clamp(0, 1).toDouble();
      final existingIdx = newAlerts.indexWhere(
        (a) => a.stationId == m.station.id,
      );
      if (existingIdx >= 0) {
        final prev = newAlerts[existingIdx];
        // respect snooze/ack unless status materially changes
        final snoozed =
            prev.snoozedUntil != null && prev.snoozedUntil!.isAfter(now);
        final materialChange = prev.status != st;
        if (snoozed && !materialChange) continue;
        newAlerts[existingIdx] = prev.copyWith(
          status: st,
          eta: etaAbs,
          confidence: confidence,
        );
      } else {
        newAlerts.add(
          WeighAlert(
            stationId: m.station.id,
            status: st,
            eta: etaAbs,
            confidence: confidence,
          ),
        );
      }
    }
    // Filter out acknowledged items that are far away and not changed
    state = newAlerts;
  }

  void clearTrip() {
    state = const [];
  }

  void acknowledge(String stationId) {
    final alerts = List<WeighAlert>.from(state);
    final idx = alerts.indexWhere((a) => a.stationId == stationId);
    if (idx >= 0) {
      alerts[idx] = alerts[idx].copyWith(acknowledged: true);
      state = alerts;
    }
  }

  void snooze(String stationId, Duration forDuration) {
    final alerts = List<WeighAlert>.from(state);
    final idx = alerts.indexWhere((a) => a.stationId == stationId);
    if (idx >= 0) {
      alerts[idx] = alerts[idx].copyWith(
        snoozedUntil: DateTime.now().toUtc().add(forDuration),
      );
      state = alerts;
    }
  }
}

// Public commands for DIY reporting
class WeighStationsActions {
  WeighStationsActions(this._ref);
  final Ref _ref;

  void report(String stationId, WeighStatus status) {
    final votes = _ref.read(_weighVotesProvider.notifier).state;
    final list = List<_VoteEntry>.from(votes[stationId] ?? const []);
    list.add(_VoteEntry(status, DateTime.now().toUtc()));
    _ref.read(_weighVotesProvider.notifier).state = {...votes, stationId: list};
  }

  void acknowledge(String stationId) {
    _ref.read(approachAlertsProvider.notifier).acknowledge(stationId);
    // In a real app, write an audit row here via Supabase
  }

  void snooze(String stationId, Duration forDuration) {
    _ref.read(approachAlertsProvider.notifier).snooze(stationId, forDuration);
  }
}

final weighStationsActionsProvider = Provider(
  (ref) => WeighStationsActions(ref),
);

// CVSA Blitz schedule (2025) minimal for banners
final cvsaBlitzDaysProvider = Provider<List<DateTimeRange>>(
  (ref) => [
    DateTimeRange(
      start: DateTime.utc(2025, 5, 13),
      end: DateTime.utc(2025, 5, 16),
    ),
    DateTimeRange(
      start: DateTime.utc(2025, 7, 13),
      end: DateTime.utc(2025, 7, 20),
    ),
    DateTimeRange(
      start: DateTime.utc(2025, 8, 24),
      end: DateTime.utc(2025, 8, 31),
    ),
  ],
);

bool _isWithin(DateTime utcNow, DateTimeRange r) =>
    utcNow.isAfter(r.start) && utcNow.isBefore(r.end);

final isBlitzDayProvider = Provider<bool>((ref) {
  final ranges = ref.watch(cvsaBlitzDaysProvider);
  final now = DateTime.now().toUtc();
  return ranges.any((r) => _isWithin(now, r));
});
