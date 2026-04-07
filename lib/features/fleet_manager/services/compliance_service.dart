import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/supa_client.dart';
import '../../driver/models/hos_models.dart';
import '../models/compliance_models.dart';

final complianceServiceProvider = Provider<ComplianceService>((ref) {
  return ComplianceService();
});

class ComplianceService {
  /// Get ELD compliance status
  Future<ELDComplianceStatus> getELDComplianceStatus() async {
    final response = await SupaClient.rpc('get_eld_compliance_status');
    return ELDComplianceStatus.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Generate IFTA report
  Future<IFTAReport> generateIFTAReport({
    required DateTime startDate,
    required DateTime endDate,
    String? vehicleId,
  }) async {
    final response = await SupaClient.rpc('generate_ifta_report', params: {
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'vehicle_id': vehicleId,
    });

    return IFTAReport.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Get HOS violations across fleet
  Future<List<HOSViolation>> getFleetHOSViolations({
    required DateTime startDate,
    required DateTime endDate,
    String? driverId,
  }) async {
    var query = SupaClient.from('hos_violations')
        .select('*')
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String())
        .order('created_at', ascending: false);

    if (driverId != null) {
      query = query.eq('driver_id', driverId);
    }

    final response = await query;
    return (response as List)
        .map((v) => HOSViolation.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  /// Get compliance alerts
  Stream<ComplianceAlert> watchComplianceAlerts() {
    return SupaClient.stream(
      'compliance_alerts',
      primaryKey: const ['id'],
      filter: (query) => query
          .eq('acknowledged', false)
          .order('severity', ascending: false),
    ).map((data) => ComplianceAlert.fromJson(Map<String, dynamic>.from(data.first)));
  }

  /// Export compliance report
  Future<String> exportComplianceReport({
    required String reportType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await SupaClient.functions('export-compliance-report', {
      'report_type': reportType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });

    final map = Map<String, dynamic>.from(response.data as Map);
    return map['download_url']?.toString() ?? '';
  }
}
