import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/hos_models.dart';

final hosServiceProvider = Provider<HOSService>((ref) {
  return HOSService();
});

final currentHOSStatusProvider = StreamProvider<HOSStatus>((ref) {
  final service = ref.watch(hosServiceProvider);
  return service.watchCurrentStatus();
});

class HOSService {
  /// Get current HOS status for driver
  Future<HOSStatus> getCurrentStatus() async {
    final response = await SupaClient.from('hos_status')
        .select('*')
        .order('created_at', ascending: false)
        .limit(1)
        .single();

    return HOSStatus.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Watch real-time HOS status updates
  Stream<HOSStatus> watchCurrentStatus() {
    return SupaClient.stream(
      'hos_status',
      primaryKey: const ['id'],
      filter: (query) => query.order('created_at', ascending: false).limit(1),
    ).map((data) => HOSStatus.fromJson(Map<String, dynamic>.from(data.first)));
  }

  /// Update duty status (ON_DUTY, OFF_DUTY, DRIVING, SLEEPER)
  Future<void> updateDutyStatus(DutyStatus status, {String? notes}) async {
    await SupaClient.from('hos_logs').insert({
      'status': status.name,
      'timestamp': DateTime.now().toIso8601String(),
      'notes': notes,
      'location': await _getCurrentLocation(),
    });
  }

  /// Get HOS violations and warnings
  Future<List<HOSViolation>> getViolations({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = SupaClient.from('hos_violations').select('*');

    if (startDate != null) {
      // ISO8601
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }

    final response = await query;
    return (response as List)
        .map((v) => HOSViolation.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  /// Calculate time remaining before HOS limit
  Future<HOSTimeRemaining> getTimeRemaining() async {
    final response = await SupaClient.rpc('calculate_hos_remaining');
    return HOSTimeRemaining.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Get HOS alerts (approaching limits)
  Stream<HOSAlert> watchHOSAlerts() {
    return SupaClient.stream(
      'hos_alerts',
      primaryKey: const ['id'],
      filter: (query) => query
          .eq('acknowledged', false)
          .order('created_at', ascending: false),
    ).map((data) => HOSAlert.fromJson(Map<String, dynamic>.from(data.first)));
  }

  Future<Map<String, double>> _getCurrentLocation() async {
    // Implementation would use location service; stubbed for now
    return {'lat': 0.0, 'lng': 0.0};
  }
}
