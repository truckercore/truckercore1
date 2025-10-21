import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_safe.dart';

class TelemetryService {
  final String restBase;
  final String anonKey;
  TelemetryService({required this.restBase, required this.anonKey});

  Future<List<Map<String, dynamic>>> recentTruckMetrics(String truckId) async {
    final uri = Uri.parse(
      '$restBase/rest/v1/vehicle_metrics?select=truck_id,ts,fuel,idle,dtc_codes&truck_id=eq.$truckId&order=ts.desc&limit=100',
    );
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
          throw Exception('metrics error: ${res.body}');
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

  Future<List<Map<String, dynamic>>> recentReefer(String assetId) async {
    final uri = Uri.parse(
      '$restBase/rest/v1/reefer_readings?select=asset_id,ts,temp,setpoint&asset_id=eq.$assetId&order=ts.desc&limit=200',
    );
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
          throw Exception('reefer error: ${res.body}');
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
