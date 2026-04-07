// lib/features/ranker/state/ranker_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/flags/rollout_flags.dart';
import '../../preferences/state/prefs_providers.dart';
import 'ranker_api.dart';
import 'ranker_cache.dart';

/// Query + filters state used by the ranker.
class RankerQuery {
  final String query;
  final Map<String, dynamic> filters;
  const RankerQuery({required this.query, required this.filters});
  RankerQuery copyWith({String? query, Map<String, dynamic>? filters}) =>
      RankerQuery(query: query ?? this.query, filters: filters ?? this.filters);
}

class RankerQueryController extends StateNotifier<RankerQuery> {
  RankerQueryController() : super(const RankerQuery(query: '', filters: {}));
  void setQuery(String q) => state = state.copyWith(query: q);
  void setFilters(Map<String, dynamic> f) => state = state.copyWith(filters: f);
  void patchFilter(String key, dynamic value) {
    final next = Map<String, dynamic>.from(state.filters);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    state = state.copyWith(filters: next);
  }
}

final rankerQueryProvider = StateNotifierProvider<RankerQueryController, RankerQuery>((ref) {
  final prefs = ref.watch(userPrefsProvider).maybeWhen(data: (p) => p, orElse: () => null);
  // Autofill filters from preferences when available (non-invasive defaults)
  final baseFilters = <String, dynamic>{};
  if (prefs != null) {
    if (prefs.defaultEquipment != null) baseFilters['equipment'] = prefs.defaultEquipment;
    if (prefs.minCpm != null) baseFilters['min_cpm'] = prefs.minCpm;
    if (prefs.homeBaseLat != null && prefs.homeBaseLng != null) {
      baseFilters['home'] = {
        'lat': prefs.homeBaseLat,
        'lng': prefs.homeBaseLng,
        'radius': prefs.homeRadiusMi,
      };
    }
    if (prefs.preferredLanes.isNotEmpty) baseFilters['preferred_lanes'] = prefs.preferredLanes;
    if (prefs.dislikedBrokers.isNotEmpty) baseFilters['disliked_brokers'] = prefs.dislikedBrokers;
    if (prefs.pickupWindowStartIso != null || prefs.pickupWindowEndIso != null) {
      baseFilters['pickup_window'] = {
        'start': prefs.pickupWindowStartIso,
        'end': prefs.pickupWindowEndIso,
      };
    }
  }
  final controller = RankerQueryController();
  controller.setFilters(baseFilters);
  return controller;
});

enum RankerSource { cache, network }

class RankerResultsState {
  final List<RankerSuggestion> items;
  final DateTime? lastUpdated;
  final RankerSource? source;
  const RankerResultsState({this.items = const [], this.lastUpdated, this.source});
  RankerResultsState copyWith({List<RankerSuggestion>? items, DateTime? lastUpdated, RankerSource? source}) =>
      RankerResultsState(items: items ?? this.items, lastUpdated: lastUpdated ?? this.lastUpdated, source: source ?? this.source);
}

class RankerResultsNotifier extends AsyncNotifier<RankerResultsState> {
  Object? _key;

  @override
  FutureOr<RankerResultsState> build() async {
    // Initialize key and clear on dispose to detect disposal across async gaps
    _key = Object();
    ref.onDispose(() => _key = null);
    final flags = ref.watch(rolloutFlagsProvider);
    if (!flags.rankerV1Enabled) {
      // Fallback: no-op results; existing screens should use their current finder instead.
      return const RankerResultsState();
    }

    final q = ref.watch(rankerQueryProvider);
    final cache = ref.read(rankerCacheProvider);
    final key = RankerCache.normalizeKey(query: q.query, filters: q.filters);

    // Cache-first
    final cached = await cache.get(key);
    if (cached != null) {
      // Fire-and-forget revalidate (SWR) if enabled
      if (ref.read(rolloutFlagsProvider).swrEnabled) {
        // ignore: discarded_futures
        _revalidate(key, q);
      }
      return RankerResultsState(items: cached.suggestions, lastUpdated: cached.ts, source: RankerSource.cache);
    }

    // No cache → fetch network
    return _fetchNetwork(key, q);
  }

  Future<RankerResultsState> _fetchNetwork(String key, RankerQuery q) async {
    final api = ref.read(rankerApiProvider);
    final res = await api.fetchRankings(query: q.query, filters: q.filters);
    await ref.read(rankerCacheProvider).set(key, res);
    return RankerResultsState(items: res.suggestions, lastUpdated: res.ts, source: RankerSource.network);
  }

  Future<void> _revalidate(String key, RankerQuery q) async {
    try {
      final guard = _key; // capture before await
      final next = await _fetchNetwork(key, q);
      if (guard != _key) return; // provider disposed or rebuilt
      state = AsyncData(next);
    } catch (_) {
      // Swallow errors during background revalidation
    }
  }

  Future<void> refreshNow() async {
    final guard = _key;
    final q = ref.read(rankerQueryProvider);
    final key = RankerCache.normalizeKey(query: q.query, filters: q.filters);
    final next = await _fetchNetwork(key, q);
    if (guard != _key) return;
    state = AsyncData(next);
  }
}

final rankerResultsProvider = AsyncNotifierProvider<RankerResultsNotifier, RankerResultsState>(
  () => RankerResultsNotifier(),
);
