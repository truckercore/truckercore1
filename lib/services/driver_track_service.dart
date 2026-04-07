import 'dart:convert';
import 'package:http/http.dart' as http;

class DriverTrackData {
  final String driverId;
  final double? lat;
  final double? lon;
  final DateTime? recordedAt;
  final Map<String, dynamic>?
  activeLoad; // id, origin, destination, status, pickup_at, dropoff_at, eta_at
  const DriverTrackData({
    required this.driverId,
    this.lat,
    this.lon,
    this.recordedAt,
    this.activeLoad,
  });
}

class DriverTrackService {
  final String supabaseUrl;
  final String anonKey;
  const DriverTrackService({required this.supabaseUrl, required this.anonKey});

  Future<DriverTrackData?> fetchByToken(String token) async {
    final uri = Uri.parse(
      '$supabaseUrl/functions/v1/public_driver_track?token=$token',
    );
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final driver = j['driver'] as Map<String, dynamic>? ?? const {};
    final pos = j['last_position'] as Map<String, dynamic>?;
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v as String);
    return DriverTrackData(
      driverId: driver['id'] as String? ?? 'unknown',
      lat: pos?['lat'] != null ? (pos!['lat'] as num).toDouble() : null,
      lon: pos?['lon'] != null ? (pos!['lon'] as num).toDouble() : null,
      recordedAt: dt(pos?['recorded_at']),
      activeLoad: j['active_load'] as Map<String, dynamic>?,
    );
  }
}
