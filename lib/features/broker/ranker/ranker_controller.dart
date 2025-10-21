// lib/features/broker/ranker/ranker_controller.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/swr.dart';
import '../../../core/flags/rollout_flags.dart';
import 'ranker_service.dart';

class RankedSuggestionsState {
  final bool loading;
  final DateTime? lastUpdated;
  final List<RankerItem> items;
  final String? error;
  const RankedSuggestionsState({this.loading = false, this.lastUpdated, this.items = const [], this.error});
  RankedSuggestionsState copyWith({bool? loading, DateTime? lastUpdated, List<RankerItem>? items, String? error}) =>
      RankedSuggestionsState(loading: loading ?? this.loading, lastUpdated: lastUpdated ?? this.lastUpdated, items: items ?? this.items, error: error);
}

class RankerController extends StateNotifier<RankedSuggestionsState> {
  final Ref ref;
  RankerController(this.ref) : super(const RankedSuggestionsState());

  static const _cacheKey = 'ranker_v1_suggestions';

  Future<void> refreshNow({required String userId, Map<String, dynamic>? filters}) async {
    final flags = ref.read(rolloutFlagsProvider);
    if (!flags.rankerV1Enabled) return; // disabled

    state = state.copyWith(loading: true);
    try {
      await Swr.getCachedThenRevalidate<List<RankerItem>>(
        key: _cacheKey,
        ttl: const Duration(seconds: 60),
        fetcher: () async {
          final svc = ref.read(rankerServiceProvider);
          final res = await svc.rank(userId: userId, filters: filters);
          return res.items;
        },
        onUpdate: (data, when) => state = RankedSuggestionsState(lastUpdated: when, items: data),
        toCache: (items) => jsonEncode(items.map((e) => {
          'load_id': e.loadId,
          'score': e.score,
          'features': e.features,
          'explain': e.explain,
          'low_confidence': e.lowConfidence,
        }).toList()),
        fromCache: (s) {
          final list = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
          return list.map((m) => RankerItem(
            loadId: m['load_id'].toString(),
            score: (m['score'] as num).toDouble(),
            features: Map<String, dynamic>.from(m['features'] as Map),
            explain: (m['explain'] as List).map((x) => {'kind': x['kind'].toString(), 'label': x['label'].toString()}).cast<Map<String, String>>().toList(),
            lowConfidence: (m['low_confidence'] as bool?) ?? false,
          )).toList();
        },
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final rankerControllerProvider = StateNotifierProvider<RankerController, RankedSuggestionsState>((ref) => RankerController(ref));
