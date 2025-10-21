import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/dvir.dart';

final dvirServiceProvider = Provider<DVIRService>((ref) {
  return DVIRService();
});

class DVIRService {
  /// Submit pre-trip inspection
  Future<String> submitPreTripInspection({
    required String vehicleId,
    required Map<String, InspectionItem> items,
    String? defectsNotes,
    List<String>? photoUrls,
  }) async {
    final response = await SupaClient.from('dvir_reports')
        .insert({
          'vehicle_id': vehicleId,
          'inspection_type': 'pre_trip',
          'items': items.map((k, v) => MapEntry(k, v.toJson())),
          'defects_notes': defectsNotes,
          'photo_urls': photoUrls,
          'status': _calculateStatus(items),
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return (response as Map)['id'] as String;
  }

  /// Submit post-trip inspection
  Future<String> submitPostTripInspection({
    required String vehicleId,
    required Map<String, InspectionItem> items,
    required int odometerReading,
    String? defectsNotes,
    List<String>? photoUrls,
  }) async {
    final response = await SupaClient.from('dvir_reports')
        .insert({
          'vehicle_id': vehicleId,
          'inspection_type': 'post_trip',
          'items': items.map((k, v) => MapEntry(k, v.toJson())),
          'odometer_reading': odometerReading,
          'defects_notes': defectsNotes,
          'photo_urls': photoUrls,
          'status': _calculateStatus(items),
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return (response as Map)['id'] as String;
  }

  /// Get inspection history
  Future<List<DVIR>> getInspectionHistory({
    String? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    var query = SupaClient.from('dvir_reports')
        .select('*')
        .order('submitted_at', ascending: false)
        .limit(limit);

    if (vehicleId != null) {
      query = query.eq('vehicle_id', vehicleId);
    }
    if (startDate != null) {
      query = query.gte('submitted_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('submitted_at', endDate.toIso8601String());
    }

    final response = await query;
    return (response as List).map((d) => DVIR.fromJson(Map<String, dynamic>.from(d))).toList();
  }

  /// Get open defects requiring attention
  Future<List<DVIRDefect>> getOpenDefects() async {
    final response = await SupaClient.from('dvir_defects')
        .select('*')
        .eq('status', 'open')
        .order('severity', ascending: false);

    return (response as List).map((d) => DVIRDefect.fromJson(Map<String, dynamic>.from(d))).toList();
  }

  String _calculateStatus(Map<String, InspectionItem> items) {
    final hasDefects = items.values.any((item) => !item.passed);
    final hasCritical = items.values.any((item) => !item.passed && item.severity == 'critical');

    if (hasCritical) return 'out_of_service';
    if (hasDefects) return 'defects_found';
    return 'satisfactory';
  }
}
