import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_safe.dart';

class SafetyEventsService {
  final String restBase;
  final String anonKey;
  SafetyEventsService({required this.restBase, required this.anonKey});

  Future<List<Map<String, dynamic>>> listEvents({String? driverId}) async {
    final qp = [
      'select=id,driver_id,event_type,severity,occurred_at',
      if (driverId != null) 'driver_id=eq.$driverId',
      'order=occurred_at.desc',
      'limit=100',
    ].join('&');
    final uri = Uri.parse('$restBase/rest/v1/safety_events?$qp');
    final token = SupabaseSafe.clientOrNull?.auth.currentSession?.accessToken;
    int attempt = 0;
    while (true) {
      try {
        final res = await http
            .get(
              uri,
              headers: {
                'apikey': anonKey,
                'Authorization': 'Bearer ${token ?? anonKey}',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode >= 300) {
          throw Exception('safety fetch error: ${res.body}');
        }
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      } catch (e) {
        if (attempt < 1 && e.toString().contains('Timeout')) {
          attempt++;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> createCoachingTask({
    required String incidentId,
    required String note,
  }) async {
    final uri = Uri.parse('$restBase/rest/v1/safety_coaching');
    final res = await http.post(
      uri,
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'incident_id': incidentId, 'note': note}),
    );
    if (res.statusCode >= 300) {
      throw Exception('coaching create error: ${res.body}');
    }
  }
}
