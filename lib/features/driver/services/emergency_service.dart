import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/emergency_alert.dart';

final emergencyServiceProvider = Provider<EmergencyService>((ref) {
  return EmergencyService();
});

class EmergencyService {
  /// Trigger panic button / emergency alert
  Future<String> triggerEmergencyAlert({
    required EmergencyType type,
    required double lat,
    required double lng,
    String? notes,
    List<String>? photoUrls,
  }) async {
    final response = await SupaClient.from('emergency_alerts').insert({
      'type': type.name,
      'lat': lat,
      'lng': lng,
      'notes': notes,
      'photo_urls': photoUrls,
      'status': 'active',
      'triggered_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    // Also trigger real-time notification to dispatch
    await _notifyDispatch(response['id'] as String, type, lat, lng);

    return response['id'] as String;
  }

  /// Cancel emergency alert
  Future<void> cancelEmergencyAlert(String alertId) async {
    await SupaClient.from('emergency_alerts')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', alertId);
  }

  /// Update emergency alert status
  Future<void> updateEmergencyStatus({
    required String alertId,
    required String status,
    String? notes,
  }) async {
    await SupaClient.from('emergency_alerts')
        .update({
          'status': status,
          'notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', alertId);
  }

  /// Report breakdown
  Future<String> reportBreakdown({
    required String vehicleId,
    required double lat,
    required double lng,
    required String issue,
    String? notes,
    List<String>? photoUrls,
  }) async {
    final response = await SupaClient.from('breakdown_reports').insert({
      'vehicle_id': vehicleId,
      'lat': lat,
      'lng': lng,
      'issue': issue,
      'notes': notes,
      'photo_urls': photoUrls,
      'status': 'reported',
      'reported_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    return response['id'] as String;
  }

  /// Request roadside assistance
  Future<String> requestRoadsideAssistance({
    required double lat,
    required double lng,
    required String serviceType,
    String? notes,
  }) async {
    final response = await SupaClient.from('roadside_assistance').insert({
      'lat': lat,
      'lng': lng,
      'service_type': serviceType,
      'notes': notes,
      'status': 'requested',
      'requested_at': DateTime.now().toIso8601String(),
    }).select('id').single();

    return response['id'] as String;
  }

  /// Get emergency contacts
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final response = await SupaClient.from('emergency_contacts')
        .select('*')
        .eq('active', true)
        .order('priority', ascending: true);

    return (response as List).map((c) => EmergencyContact.fromJson(c)).toList();
  }

  /// Watch active emergency alerts (for fleet managers)
  Stream<List<EmergencyAlert>> watchActiveEmergencies() {
    return SupaClient.stream(
      'emergency_alerts',
      primaryKey: const ['id'],
      filter: (query) => query
          .in_('status', ['active', 'responding'])
          .order('triggered_at', ascending: false),
    ).map((data) => data.map((e) => EmergencyAlert.fromJson(e)).toList());
  }

  /// Send SOS to dispatch with location
  Future<void> sendSOSWithLocation({
    required double lat,
    required double lng,
    String? message,
  }) async {
    await SupaClient.functions('send-sos', {
      'lat': lat,
      'lng': lng,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _notifyDispatch(
    String alertId,
    EmergencyType type,
    double lat,
    double lng,
  ) async {
    await SupaClient.functions('notify-dispatch-emergency', {
      'alert_id': alertId,
      'type': type.name,
      'lat': lat,
      'lng': lng,
    });
  }
}
