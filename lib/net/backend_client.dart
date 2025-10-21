import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class BackendClient {
  final String baseUrl;
  BackendClient(this.baseUrl);

  /// GET with bearer forwarding and sane defaults for timeout/retry.
  /// - Adds x-trace-id for observability across Edge.
  /// - Default read timeout 12s; single retry on network error with 200–500ms jitter.
  Future<http.Response> get(String path, {Map<String, String>? headers, Duration? timeout, String? traceId}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final tid = traceId ?? const Uuid().v4();
    final merged = <String, String>{
      'Accept': 'application/json',
      'x-trace-id': tid,
      if (headers != null) ...headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _retry(() => http
            .get(Uri.parse('$baseUrl$path'), headers: merged)
            .timeout(timeout ?? const Duration(seconds: 12)));
  }

  Future<T> _retry<T>(Future<T> Function() run, {int max = 1}) async {
    var attempt = 0;
    while (true) {
      try {
        return await run();
      } on SocketException {
        if (attempt++ >= max) rethrow;
        await Future.delayed(Duration(milliseconds: 200 + Random().nextInt(400)));
      }
    }
  }
}
