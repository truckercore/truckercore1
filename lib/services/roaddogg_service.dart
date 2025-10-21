import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supa_client.dart';

class RoaddoggService {
  final SupaClient client;
  RoaddoggService(this.client);

  Future<Map<String, dynamic>> scoreLoad(String loadId) async {
    final uri = Uri.parse('${client.supabaseUrl}/functions/v1/roaddogg_match');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${client.anonKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'load_id': loadId}),
    );
    if (res.statusCode >= 300) {
      throw AppError(
        'server',
        'Roaddogg error: ${res.statusCode} ${res.body}',
        status: res.statusCode,
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
