import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Lightweight REST API client for Flutter front-end.
///
/// Notes:
/// - Uses AppConfig.apiBaseUrl if available (via optional import),
///   otherwise falls back to dotenv REACT-like keys or a sane default.
/// - Timeouts and headers are centralized.
/// - Methods return parsed JSON (Map/List) and throw on non-2xx.
class ApiService {
  // Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Resolve base URL from (in order):
  /// 1) Dart define: API_BASE_URL
  /// 2) .env: API_BASE_URL (mobile) or REACT_APP_API_URL (shared)
  /// 3) Fallback to localhost
  String get _baseUrl {
    // 1) dart-define
    const dd = String.fromEnvironment('API_BASE_URL');
    if (dd.isNotEmpty) return dd;

    // 2) .env
    try {
      final envMobile = dotenv.maybeGet('API_BASE_URL');
      if (envMobile != null && envMobile.isNotEmpty) return envMobile;
      final envReact = dotenv.maybeGet('REACT_APP_API_URL');
      if (envReact != null && envReact.isNotEmpty) return envReact;
    } catch (_) {}

    // 3) fallback
    return 'http://localhost:3001/api';
  }

  Duration get _timeout {
    // Allow override via dart-define or .env (milliseconds)
    const dd = String.fromEnvironment('API_TIMEOUT');
    if (dd.isNotEmpty) {
      final ms = int.tryParse(dd);
      if (ms != null && ms > 0) return Duration(milliseconds: ms);
    }
    try {
      final env = dotenv.maybeGet('API_TIMEOUT');
      final ms = env != null ? int.tryParse(env) : null;
      if (ms != null && ms > 0) return Duration(milliseconds: ms);
    } catch (_) {}
    return defaultTimeout;
  }

  Map<String, String> _defaultHeaders() => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String endpoint) => Uri.parse('${_baseUrl.replaceAll(RegExp(r'/+
?
?
?
?
?$'), '')}/$endpoint');

  // Generic GET request
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final resp = await http
          .get(_uri(endpoint), headers: {..._defaultHeaders(), ...?headers})
          .timeout(_timeout);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = resp.body.isEmpty ? '{}' : resp.body;
        return json.decode(body) as Map<String, dynamic>;
      }
      throw Exception('GET $endpoint failed: ${resp.statusCode} ${resp.reasonPhrase}');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('ApiService GET error: $e');
      }
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    try {
      final resp = await http
          .post(
            _uri(endpoint),
            headers: {..._defaultHeaders(), ...?headers},
            body: json.encode(data),
          )
          .timeout(_timeout);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = resp.body.isEmpty ? '{}' : resp.body;
        return json.decode(body) as Map<String, dynamic>;
      }
      throw Exception('POST $endpoint failed: ${resp.statusCode} ${resp.reasonPhrase}');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('ApiService POST error: $e');
      }
      throw Exception('Network error: $e');
    }
  }

  // Domain helpers
  Future<List<dynamic>> fetchLoads() async {
    final res = await get('loads');
    final v = res['loads'];
    return v is List ? v : <dynamic>[];
  }

  Future<List<dynamic>> fetchDrivers() async {
    final res = await get('drivers');
    final v = res['drivers'];
    return v is List ? v : <dynamic>[];
  }

  Future<Map<String, dynamic>> submitExpense(Map<String, dynamic> expense) async {
    return await post('expenses', expense);
  }

  Future<Map<String, dynamic>> submitPOD(Map<String, dynamic> pod) async {
    return await post('pod', pod);
  }

  Future<Map<String, dynamic>> postLoad(Map<String, dynamic> load) async {
    return await post('loads', load);
  }
}
