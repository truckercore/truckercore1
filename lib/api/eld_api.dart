import 'dart:convert';
import 'package:http/http.dart' as http;

class EldApi {
  final String baseUrl; final String jwt;
  EldApi(this.baseUrl, this.jwt);
  Future<Map<String,dynamic>> predictHos({required String driverId, required String sessionId, required String bbox}) async {
    final r = await http.post(Uri.parse('$baseUrl/eld/predict_hos'),
      headers: {'authorization': 'Bearer $jwt','content-type':'application/json'},
      body: jsonEncode({'driver_id':driverId,'session_id':sessionId,'bbox':bbox}));
    if (r.statusCode>=200 && r.statusCode<300) return jsonDecode(r.body);
    throw Exception('predictHos ${r.statusCode}');
  }
}
