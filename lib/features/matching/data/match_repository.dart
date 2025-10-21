import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchRepository {
  final SupabaseClient? _sb;
  MatchRepository([SupabaseClient? client])
    : _sb = client ?? Supabase.instance.client;

  Future<List<DriverMatch>> runMatch({required String loadId}) async {
    final client = _sb ?? Supabase.instance.client;
    final res = await client.functions.invoke(
      'ai_matchmaker',
      body: {'load_id': loadId},
    );
    final data = (res.data is Map)
        ? res.data as Map
        : jsonDecode(jsonEncode(res.data)) as Map;
    final results = data['results'] as List? ?? [];
    return results
        .map((e) => DriverMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class DriverMatch {
  final String driverUserId;
  final double score;
  final String rationale;

  DriverMatch({
    required this.driverUserId,
    required this.score,
    required this.rationale,
  });

  factory DriverMatch.fromJson(Map<String, dynamic> j) => DriverMatch(
    driverUserId: j['driver_user_id'] as String,
    score: (j['score'] as num).toDouble(),
    rationale: j['rationale'] as String,
  );
}
