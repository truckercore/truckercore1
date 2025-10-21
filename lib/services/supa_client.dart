import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:truckercore1/core/observability/performance_tracer.dart';
import 'package:uuid/uuid.dart';

class AppError implements Exception {
  final String code; // e.g., 'network','forbidden','server','validation'
  final String message;
  final int? status;
  AppError(this.code, this.message, {this.status});
  @override
  String toString() => 'AppError($code, $status): $message';
}

AppError mapHttpError(int status, String body) {
  if (status == 401 || status == 403) {
    return AppError('forbidden', 'Not authorized', status: status);
  }
  if (status >= 500) return AppError('server', 'Server error', status: status);
  return AppError('network', 'Request failed ($status): $body', status: status);
}

class SupaClient {
  final String supabaseUrl;
  final String anonKey;
  const SupaClient({required this.supabaseUrl, required this.anonKey});

  // Allows app to provide additional headers (e.g., org/roles) at runtime.
  // Return a new map on each call; do not mutate and do not throw.
  static Map<String, String> Function()? defaultExtraHeaders;

  // Convenience static wrappers around Supabase Flutter client to match app usage
  // in services (rpc, functions, from, stream).
  // Return a flexible builder compatible with insert/update/select
  static dynamic from(String table) {
    return Supabase.instance.client.from(table);
  }

  static Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) async {
    final res = await Supabase.instance.client.rpc(fn, params: params);
    return res;
  }

  static Future<dynamic> functions(String fn, Map<String, dynamic> body) async {
    final res = await Supabase.instance.client.functions.invoke(fn, body: body);
    return res;
  }

  // Stream helper; keep types flexible to accommodate supabase_dart v2 API changes
  static dynamic stream(
    String table, {
    required List<String> primaryKey,
    dynamic Function(dynamic query)? filter,
  }) {
    dynamic query = Supabase.instance.client.from(table).stream(primaryKey: primaryKey);
    if (filter != null) {
      query = filter(query);
    }
    return query;
  }

  static final _uuid = const Uuid();
  Map<String, String> _headers({String? requestId, String? bearerToken, Map<String, String>? extra}) {
    final base = <String, String>{
      'apikey': anonKey,
      'Authorization': 'Bearer ${bearerToken ?? anonKey}',
      'Content-Type': 'application/json',
      'x-request-id': requestId ?? _uuid.v4(),
    };
    try {
      final def = defaultExtraHeaders?.call();
      if (def != null) base.addAll(def);
    } catch (_) {}
    if (extra != null) base.addAll(extra);
    return base;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    String? bearerToken,
    int maxRetries = 0,
    Duration retryDelay = const Duration(milliseconds: 400),
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$supabaseUrl$path');
    final t = timeout ?? const Duration(seconds: 15);
    var attempt = 0;
    while (true) {
      final reqId = _uuid.v4();
      try {
        dev.log('SupaClient POST $path start requestId=$reqId');
        final res = await PerformanceTracer.traceNetworkRequest(
          uri.toString(),
          'POST',
          () async {
            final r = await http
                .post(
                  uri,
                  headers: _headers(requestId: reqId, bearerToken: bearerToken, extra: extraHeaders),
                  body: jsonEncode(body),
                )
                .timeout(t);
            // Custom measurements
            try {
              PerformanceTracer.recordMeasurement('response_size_bytes', r.bodyBytes.length);
              PerformanceTracer.recordMeasurement('status_code', r.statusCode);
            } catch (_) {}
            return r;
          },
        );
        dev.log(
          'SupaClient POST $path done status=${res.statusCode} requestId=$reqId',
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.isEmpty) return {};
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) return decoded;
          return {'data': decoded};
        }
        throw mapHttpError(res.statusCode, res.body);
      } catch (e) {
        dev.log('SupaClient POST $path error requestId=$reqId: $e');
        final err = e is AppError ? e : AppError('network', e.toString());
        final isTransient =
            e is TimeoutException ||
            err.code == 'server' ||
            err.code == 'network';
        if (isTransient && attempt < maxRetries) {
          attempt++;
          // exponential backoff with jitter
          final baseMs = retryDelay.inMilliseconds;
          var delayMs = baseMs * (1 << (attempt - 1));
          if (delayMs > 10000) delayMs = 10000;
          final jitter = (delayMs * 0.2).toInt();
          final rand = DateTime.now().microsecondsSinceEpoch % (2 * jitter + 1) - jitter;
          delayMs += rand;
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        if (e is AppError) rethrow;
        throw err;
      }
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration? timeout,
    String? bearerToken,
    int maxRetries = 0,
    Duration retryDelay = const Duration(milliseconds: 400),
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$supabaseUrl$path');
    final t = timeout ?? const Duration(seconds: 15);
    var attempt = 0;
    while (true) {
      final reqId = _uuid.v4();
      try {
        dev.log('SupaClient GET $path start requestId=$reqId');
        final res = await PerformanceTracer.traceNetworkRequest(
          uri.toString(),
          'GET',
          () async {
            final r = await http
                .get(
                  uri,
                  headers: _headers(requestId: reqId, bearerToken: bearerToken, extra: extraHeaders),
                )
                .timeout(t);
            try {
              PerformanceTracer.recordMeasurement('response_size_bytes', r.bodyBytes.length);
              PerformanceTracer.recordMeasurement('status_code', r.statusCode);
            } catch (_) {}
            return r;
          },
        );
        dev.log(
          'SupaClient GET $path done status=${res.statusCode} requestId=$reqId',
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.isEmpty) return {};
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) return decoded;
          return {'data': decoded};
        }
        throw mapHttpError(res.statusCode, res.body);
      } catch (e) {
        dev.log('SupaClient GET $path error requestId=$reqId: $e');
        final err = e is AppError ? e : AppError('network', e.toString());
        final isTransient =
            e is TimeoutException ||
            err.code == 'server' ||
            err.code == 'network';
        if (isTransient && attempt < maxRetries) {
          attempt++;
          // exponential backoff with jitter
          final baseMs = retryDelay.inMilliseconds;
          var delayMs = baseMs * (1 << (attempt - 1));
          if (delayMs > 10000) delayMs = 10000;
          final jitter = (delayMs * 0.2).toInt();
          final rand = DateTime.now().microsecondsSinceEpoch % (2 * jitter + 1) - jitter;
          delayMs += rand;
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        if (e is AppError) rethrow;
        throw err;
      }
    }
  }
}
