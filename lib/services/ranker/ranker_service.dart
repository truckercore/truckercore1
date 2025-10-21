// lib/services/ranker/ranker_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/flags/rollout_flags.dart';
import '../../core/supabase/supabase_factory.dart';

/// Input payload for ranker service.
class QueryInput {
  final String query;
  final Map<String, dynamic> filters; // equipment, min_cpm, radius, dates, etc.
  final Map<String, dynamic>? profile; // subset: home_base, radius, prefs
  final String? orgId;
  const QueryInput({
    required this.query,
    required this.filters,
    this.profile,
    this.orgId,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'filters': filters,
        if (profile != null) 'profile': profile,
        if (orgId != null) 'org_id': orgId,
      };
}

class Suggestion {
  final String id; // underlying entity id (load id)
  final String candidateId; // stable candidate id for events
  final double? cphEst;
  final double? marketCpmDelta;
  final double? deadheadMi;
  final int? brokerTrustScore;
  final int? slaReplyMinutes;
  final double? confidence;
  final List<String> topReasons;

  // Some commonly used UI fields (optional)
  final double? cpm;
  final double? miles;

  const Suggestion({
    required this.id,
    required this.candidateId,
    this.cphEst,
    this.marketCpmDelta,
    this.deadheadMi,
    this.brokerTrustScore,
    this.slaReplyMinutes,
    this.confidence,
    this.topReasons = const [],
    this.cpm,
    this.miles,
  });

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        id: j['id']?.toString() ?? j['load_id']?.toString() ?? j['candidate_id']?.toString() ?? '',
        candidateId: j['candidate_id']?.toString() ?? (j['id']?.toString() ?? ''),
        cphEst: (j['cph_est'] as num?)?.toDouble(),
        marketCpmDelta: (j['market_cpm_delta'] as num?)?.toDouble(),
        deadheadMi: (j['deadhead_mi'] as num?)?.toDouble(),
        brokerTrustScore: (j['broker_trust_score'] as num?)?.toInt(),
        slaReplyMinutes: (j['sla_reply_minutes'] as num?)?.toInt(),
        confidence: (j['confidence'] as num?)?.toDouble(),
        topReasons: ((j['top_reasons'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
        cpm: (j['cpm'] as num?)?.toDouble(),
        miles: (j['miles'] as num?)?.toDouble(),
      );
}

class _CacheEntry {
  final DateTime ts;
  final List<Suggestion> value;
  const _CacheEntry(this.ts, this.value);
}

class RankerService {
  RankerService(this._ref);
  final Ref _ref;

  static const Duration defaultTtl = Duration(seconds: 60);
  final _mem = <String, _CacheEntry>{};

  Future<List<Suggestion>> findRanked({required QueryInput input, Duration ttl = defaultTtl}) async {
    final flags = _ref.read(rolloutFlagsProvider);
    // short-circuit if disabled: return empty and do not fetch network
    if (!flags.rankerV1Enabled) {
      return const <Suggestion>[];
    }

    final key = _keyFor(input);
    final now = DateTime.now().toUtc();
    final cached = _mem[key];
    if (cached != null && now.difference(cached.ts) < ttl) {
      // Trigger background revalidate without awaiting
      // ignore: discarded_futures
      _revalidate(key, input);
      return cached.value;
    }

    return _revalidate(key, input);
  }

  Future<List<Suggestion>> _revalidate(String key, QueryInput input) async {
    final factory = _ref.read(supabaseFactoryProvider);
    final client = factory.maybeClient;
    if (client == null) {
      return _mem[key]?.value ?? const <Suggestion>[];
    }

    try {
      final payload = input.toJson();
      final res = await client.functions.invoke(
        'ranker_v1',
        body: jsonEncode(payload),
        headers: {'Content-Type': 'application/json'},
      );
      final data = res.data;
      final listDyn = data is Map && data['suggestions'] is List
          ? (data['suggestions'] as List)
          : (data as List? ?? const []);
      final items = listDyn
          .map((e) => Suggestion.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
      _mem[key] = _CacheEntry(DateTime.now().toUtc(), items);
      return items;
    } catch (e, st) {
      // Log and return best-effort cached; avoid coupling to optional error mappers
      debugPrint('ranker_v1 error: $e\n$st');
      return _mem[key]?.value ?? const <Suggestion>[];
    }
  }

  String _keyFor(QueryInput input) {
    // Normalize to lower-case query and sorted filter keys and profile slice.
    Map<String, dynamic> sortMap(Map<String, dynamic> m) {
      final entries = m.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      return Map<String, dynamic>.fromEntries(entries);
    }

    final payload = {
      'q': input.query.trim().toLowerCase(),
      'f': sortMap(input.filters),
      if (input.profile != null) 'p': sortMap(input.profile!),
      if (input.orgId != null) 'org': input.orgId,
    };
    return base64Url.encode(utf8.encode(jsonEncode(payload)));
  }
}


final rankerServiceProvider = Provider<RankerService>((ref) => RankerService(ref));
