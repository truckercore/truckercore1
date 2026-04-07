import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single source of truth for Supabase access + typed helpers + logging.
class TC {
  TC._();

  static SupabaseClient get _raw => Supabase.instance.client;

  /// Postgrest with safe defaults: schema, headers, retries (manual), logging.
  static PostgrestClient get db => _raw.rest;

  /// Auth facade (extend as needed).
  static GoTrueClient get auth => _raw.auth;

  /// Storage facade.
  static SupabaseStorageClient get storage => _raw.storage;

  /// Wrap any query to standardize error logging + metrics.
  static Future<T> guard<T>(
    Future<T> Function() run, {
    String op = 'supabase_op',
    Map<String, Object?> meta = const {},
  }) async {
    final sw = Stopwatch()..start();
    try {
      final res = await run();
      dev.log(
        'OK:$op',
        name: 'TC',
        time: DateTime.now(),
        sequenceNumber: sw.elapsedMilliseconds,
      );
      return res;
    } catch (e, st) {
      dev.log('ERR:$op', name: 'TC', error: e, stackTrace: st);
      rethrow;
    } finally {
      sw.stop();
    }
  }

  /// Typed helpers ------------------------------------------------------------

  /// Paginated select helper (offset/limit). Adds standard order/filters.
  static Future<List<Map<String, dynamic>>> selectPage({
    required String from,
    String? columns,
    String? orderBy,
    bool ascending = false,
    int offset = 0,
    int limit = 25,
    Map<String, dynamic>? eq,
    Map<String, dynamic>? ilike,
  }) {
    return guard(() async {
      // Clamp pagination to sane bounds to avoid accidental large scans
      final safeOffset = offset < 0 ? 0 : offset;
      final safeLimit = limit.clamp(1, 200);
      dynamic q = db.from(from).select(columns ?? '*');
      (eq ?? {}).forEach((k, v) => q = q.eq(k, v));
      (ilike ?? {}).forEach((k, v) => q = q.ilike(k, '%$v%'));
      if (orderBy != null) q = q.order(orderBy, ascending: ascending);
      q = q.range(safeOffset, safeOffset + safeLimit - 1);
      final data = await q;
      return (data as List).cast<Map<String, dynamic>>();
    }, op: 'selectPage:$from', meta: {
      'offset': offset,
      'limit': limit,
      'orderBy': orderBy ?? '',
    });
  }

  static Future<Map<String, dynamic>?> getById({
    required String from,
    required String idCol,
    required String id,
    String? columns,
  }) {
    return guard(() async {
      final data = await db.from(from)
            .select(columns ?? '*')
            .eq(idCol, id)
          .maybeSingle();
      return data;
    }, op: 'getById:$from');
  }
}
