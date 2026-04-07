// lib/services/edge_client.dart
// A tiny HTTP client for calling Edge endpoints with sane defaults.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class EdgeClient {
  EdgeClient({required this.base, this.jwt});

  final String base; // e.g., https://<project-ref>.functions.supabase.co
  final String? jwt; // optional user JWT (Authorization: Bearer)
  Duration timeout = const Duration(seconds: 10);
  int maxRetries = 1; // number of retries on 5xx (additional to first attempt)

  Uri _build(String path, [Map<String, String>? qs]) {
    final root = base.replaceAll(RegExp(r'/+$'), '');
    final clean = path.replaceFirst(RegExp(r'^/+'), '');
    final uri = Uri.parse('$root/$clean');
    return qs == null ? uri : uri.replace(queryParameters: qs);
  }

  Map<String, String> _headers([Map<String, String>? extra]) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (jwt != null) 'Authorization': 'Bearer $jwt',
        if (extra != null) ...extra,
      };

  Future<Map<String, dynamic>> get(String path, Map<String, String> qs, {Map<String, String>? headers}) async {
    final uri = _build(path, qs);
    return _withRetry(() async {
      final res = await http.get(uri, headers: _headers(headers)).timeout(timeout);
      _ok(res);
      return _json(res);
    });
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    final uri = _build(path);
    return _withRetry(() async {
      final res = await http
          .post(uri, headers: _headers(headers), body: jsonEncode(body))
          .timeout(timeout);
      _ok(res);
      return _json(res);
    });
  }

  Future<Map<String, dynamic>> _withRetry(Future<Map<String, dynamic>> Function() fn) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await fn();
      } on SocketException catch (_) {
        if (attempt > maxRetries + 1) rethrow;
        await Future.delayed(Duration(milliseconds: 150 * attempt));
        continue;
      } on http.ClientException catch (_) {
        rethrow;
      } on HttpException catch (_) {
        rethrow;
      } on TimeoutException catch (_) {
        if (attempt > maxRetries + 1) rethrow;
        await Future.delayed(Duration(milliseconds: 150 * attempt));
        continue;
      } on _EdgeHttpStatusException catch (e) {
        // Retry only 5xx
        if (e.status >= 500 && e.status < 600 && attempt <= maxRetries + 1) {
          await Future.delayed(Duration(milliseconds: 150 * attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  void _ok(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    // Try to propagate JSON { error }
    try {
      final m = jsonDecode(res.body) as Map;
      final err = (m['error'] ?? m['message'] ?? res.reasonPhrase)?.toString();
      throw _EdgeHttpStatusException(res.statusCode, err ?? 'error');
    } catch (_) {
      throw _EdgeHttpStatusException(res.statusCode, res.body);
    }
  }

  Map<String, dynamic> _json(http.Response r) {
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
      return {'data': decoded};
    } catch (_) {
      return {'raw': r.body};
    }
  }
}

class _EdgeHttpStatusException implements Exception {
  final int status;
  final String message;
  _EdgeHttpStatusException(this.status, this.message);
  @override
  String toString() => 'EdgeHttpStatusException($status): $message';
}
