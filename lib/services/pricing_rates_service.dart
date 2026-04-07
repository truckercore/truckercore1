import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_safe.dart';

class PricingRatesService {
  final String restBase;
  final String anonKey;
  PricingRatesService({required this.restBase, required this.anonKey});

  Future<List<Map<String, dynamic>>> dailyLaneRates({
    required String lane,
    required String equipment,
    DateTime? from,
    DateTime? to,
  }) async {
    final qp = [
      'select=lane,equipment,date,p50,p80,source,sample_size,confidence',
      'lane=eq.$lane',
      'equipment=eq.$equipment',
      if (from != null) 'date=gte.${from.toIso8601String().substring(0, 10)}',
      if (to != null) 'date=lte.${to.toIso8601String().substring(0, 10)}',
      'order=date.desc',
      'limit=30',
    ].join('&');
    final uri = Uri.parse('$restBase/rest/v1/market_rates_daily?$qp');
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
          throw Exception('rates error: ${res.body}');
        }
        return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      } catch (e) {
        // single retry on transient error
        if (attempt < 1 && e.toString().contains('Timeout')) {
          attempt++;
          continue;
        }
        rethrow;
      }
    }
  }

  Future<List<Map<String, dynamic>>> brokerCredit(String brokerId) async {
    final uri = Uri.parse(
      '$restBase/rest/v1/broker_credit?select=*&broker_id=eq.$brokerId',
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
          throw Exception('credit error: ${res.body}');
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
