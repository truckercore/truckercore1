import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_safe.dart';

class HosReadService {
  final String restBase;
  final String anonKey;
  HosReadService({required this.restBase, required this.anonKey});

  Future<List<Map<String, dynamic>>> listSegments(
    String driverId, {
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final qp = [
      'select=id,driver_id,start_time,end_time,status,source,eld_provider,created_at',
      'driver_id=eq.$driverId',
      if (fromUtc != null) 'start_time=gte.${fromUtc.toIso8601String()}',
      if (toUtc != null) 'end_time=lte.${toUtc.toIso8601String()}',
      'order=start_time.desc',
      'limit=200',
    ].join('&');
    final uri = Uri.parse('$restBase/rest/v1/hos_logs?$qp');
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
          throw Exception('HOS fetch error: ${res.body}');
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
}
