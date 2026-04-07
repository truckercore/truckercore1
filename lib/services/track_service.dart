import 'dart:convert';
import 'package:http/http.dart' as http;

class TrackData {
  final String? origin;
  final String? destination;
  final String? status;
  final DateTime? etaAt;
  final DateTime? pickupAt;
  final DateTime? dropoffAt;
  final double? lat;
  final double? lon;
  final DateTime? recordedAt;

  TrackData({
    this.origin,
    this.destination,
    this.status,
    this.etaAt,
    this.pickupAt,
    this.dropoffAt,
    this.lat,
    this.lon,
    this.recordedAt,
  });
}

class TrackService {
  final String supabaseUrl;
  final String anonKey;

  TrackService({required this.supabaseUrl, required this.anonKey});

  Future<TrackData?> fetchByToken(String token) async {
    final uri = Uri.parse(
      '$supabaseUrl/functions/v1/public_track?token=$token',
    );
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final load = json['load'] as Map<String, dynamic>?;
    final pos = json['last_position'] as Map<String, dynamic>?;

    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v as String);

    return TrackData(
      origin: load?['origin'] as String?,
      destination: load?['destination'] as String?,
      status: load?['status'] as String?,
      etaAt: dt(load?['eta_at']),
      pickupAt: dt(load?['pickup_at']),
      dropoffAt: dt(load?['dropoff_at']),
      lat: pos?['lat'] != null ? (pos!['lat'] as num).toDouble() : null,
      lon: pos?['lon'] != null ? (pos!['lon'] as num).toDouble() : null,
      recordedAt: dt(pos?['recorded_at']),
    );
  }
}
