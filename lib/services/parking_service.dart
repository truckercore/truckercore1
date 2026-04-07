// lib/services/parking_service.dart
// Parking status service using EdgeClient and robust model parsing.

import '../models/parking_status.dart';
import 'edge_client.dart';

class ParkingService {
  final EdgeClient edge;
  ParkingService(this.edge);

  Future<ParkingStatus?> getStatus(String stopId) async {
    final resp = await edge.post('parking-status', {'stop_id': stopId});
    return ParkingStatus.fromJson(resp);
  }

  Future<ParkingStatus?> getStatusNearest(double lat, double lng) async {
    try {
      final resp = await edge.get('parking-status', {
        'lat': '$lat',
        'lng': '$lng',
      });
      return ParkingStatus.fromJson(resp);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('404')) return null; // specifically treat 404 as no data
      rethrow;
    }
  }

  Future<void> report({
    required String stopId,
    required String kind, // 'open'|'limited'|'full'|'count'
    int? value,
    String? deviceHash,
  }) async {
    await edge.post('parking-report', {
      'stop_id': stopId,
      'kind': kind,
      if (value != null) 'value': value,
      if (deviceHash != null) 'device_hash': deviceHash,
    });
  }
}
