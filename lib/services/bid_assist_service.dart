import 'dart:convert';
import 'package:http/http.dart' as http;

class BidAssistService {
  final String functionsBase; // e.g. $SUPABASE_URL/functions/v1
  final String anonKey;
  BidAssistService({required this.functionsBase, required this.anonKey});

  Future<Map<String, dynamic>> suggestBid({
    required String origin,
    required String destination,
    required String equipment,
    required DateTime pickupAtUtc,
    String? driverId,
  }) async {
    final uri = Uri.parse('$functionsBase/bid_assist');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'equipment': equipment,
        'pickup_at': pickupAtUtc.toIso8601String(),
        if (driverId != null) 'driver_id': driverId,
      }),
    );
    if (res.statusCode >= 300) {
      throw Exception('bid assist error: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
