import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackingLinkService {
  final String supabaseUrl;
  final String anonKey;

  TrackingLinkService({required this.supabaseUrl, required this.anonKey});

  Future<String?> ensureTokenForLoad(String loadId) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/ensure_tracking_link');
    final res = await http.post(
      uri,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'p_load': loadId}),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is String) return body;
      if (body is Map && body['ensure_tracking_link'] is String) {
        return body['ensure_tracking_link'];
      }
    }
    return null;
  }

  Future<void> setExpiry(String token, DateTime? expiresAt) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/set_tracking_expiry');
    await http.post(
      uri,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'p_token': token,
        'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> revoke(String token) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/revoke_tracking_link');
    await http.post(
      uri,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'p_token': token}),
    );
  }
}
