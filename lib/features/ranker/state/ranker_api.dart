// lib/features/ranker/state/ranker_api.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/config/app_config.dart';
import '../../../common/telemetry/perf_tracing.dart';
import '../../../core/supabase/supabase_factory.dart';

/// Data model for a single ranked suggestion/load.
class RankerSuggestion {
  final String id; // load id or composite key
  final String title; // short title (e.g., OR -> NJ, 45k lb)
  final double cpm; // cents per mile or dollars per mile depending on product; assume dollars/mile
  final double? cph; // dollars per hour, optional
  final double miles; // total miles (or linehaul miles)
  final double deadheadMiles;
  final double score; // overall ranker score
  final int? trust; // broker trust 0..100
  final Map<String, dynamic>? explain; // explainability payload

  const RankerSuggestion({
    required this.id,
    required this.title,
    required this.cpm,
    this.cph,
    required this.miles,
    required this.deadheadMiles,
    required this.score,
    this.trust,
    this.explain,
  });

  factory RankerSuggestion.fromJson(Map<String, dynamic> j) => RankerSuggestion(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        cpm: (j['cpm'] as num?)?.toDouble() ?? 0,
        cph: (j['cph'] as num?)?.toDouble(),
        miles: (j['miles'] as num?)?.toDouble() ?? 0,
        deadheadMiles: (j['deadhead_miles'] as num?)?.toDouble() ?? (j['deadheadMiles'] as num?)?.toDouble() ?? 0,
        score: (j['score'] as num?)?.toDouble() ?? 0,
        trust: (j['trust'] as num?)?.toInt(),
        explain: j['explain'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cpm': cpm,
        'cph': cph,
        'miles': miles,
        'deadhead_miles': deadheadMiles,
        'score': score,
        'trust': trust,
        'explain': explain,
      };
}

class RankerResponse {
  final List<RankerSuggestion> suggestions;
  final DateTime ts;
  const RankerResponse({required this.suggestions, required this.ts});

  Map<String, dynamic> toJson() => {
        'ts': ts.toIso8601String(),
        'suggestions': suggestions.map((e) => e.toJson()).toList(),
      };

  factory RankerResponse.fromJson(Map<String, dynamic> j) => RankerResponse(
        suggestions: ((j['suggestions'] as List?) ?? const [])
            .map((e) => RankerSuggestion.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        ts: DateTime.tryParse(j['ts']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
      );
}

/// Edge function client wrapper.
class RankerApi {
  RankerApi(this._ref);
  final Ref _ref;

  Future<RankerResponse> fetchRankings({
    required String query,
    required Map<String, dynamic> filters,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final cfg = _ref.read(appConfigProvider);
    // Mock mode: return empty response to avoid hitting network
    if (cfg.useMockData) {
      return RankerResponse(suggestions: const [], ts: DateTime.utc(1970));
    }

    final factory = _ref.read(supabaseFactoryProvider);
    final client = factory.maybeClient;
    if (client == null) {
      // When supabase not ready, return empty set instead of throwing to keep UI responsive
      return RankerResponse(suggestions: const [], ts: DateTime.utc(1970));
    }

    final payload = {'query': query, 'filters': filters};

    // Prefer invoke of Edge Function "ranker_v1"
    final fn = client.functions;
    final res = await fn
        .invokeWithTrace('ranker_v1', action: 'ranker.search', body: jsonEncode(payload),
            headers: {'Content-Type': 'application/json'})
        .timeout(timeout);

    if (res.data == null) {
      return RankerResponse(suggestions: const [], ts: DateTime.utc(1970));
    }
    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final list = (data is Map && data['suggestions'] is List)
        ? (data['suggestions'] as List)
        : (data as List? ?? const []);
    final suggestions = list
        .map((e) => RankerSuggestion.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return RankerResponse(suggestions: suggestions, ts: DateTime.now().toUtc());
  }
}

final rankerApiProvider = Provider<RankerApi>((ref) => RankerApi(ref));
