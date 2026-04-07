import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/maintenance_models.dart';

final maintenanceServiceProvider = Provider<MaintenanceService>((ref) {
  return MaintenanceService();
});

final maintenanceAlertsProvider = StreamProvider<List<MaintenanceAlert>>((ref) {
  final service = ref.watch(maintenanceServiceProvider);
  return service.watchMaintenanceAlerts();
});

class MaintenanceService {
  /// Get maintenance alerts for vehicles
  Stream<List<MaintenanceAlert>> watchMaintenanceAlerts() {
    return SupaClient.stream(
      'maintenance_alerts',
      primaryKey: const ['id'],
      filter: (query) => query
          .eq('resolved', false)
          .order('severity', ascending: false),
    ).map((data) => data
        .map((a) => MaintenanceAlert.fromJson(Map<String, dynamic>.from(a)))
        .toList());
  }

  /// Schedule maintenance
  Future<String> scheduleMaintenance({
    required String vehicleId,
    required String maintenanceType,
    required DateTime scheduledDate,
    String? notes,
    String? shopId,
  }) async {
    final response = await SupaClient.from('maintenance_schedule')
        .insert({
          'vehicle_id': vehicleId,
          'maintenance_type': maintenanceType,
          'scheduled_date': scheduledDate.toIso8601String(),
          'notes': notes,
          'shop_id': shopId,
          'status': 'scheduled',
        })
        .select('id')
        .single();

    return (response as Map)['id']?.toString() ?? '';
  }

  /// Record completed maintenance
  Future<void> recordMaintenance({
    required String vehicleId,
    required String maintenanceType,
    required int odometerReading,
    required double cost,
    String? notes,
    List<String>? invoiceUrls,
  }) async {
    await SupaClient.from('maintenance_records').insert({
      'vehicle_id': vehicleId,
      'maintenance_type': maintenanceType,
      'odometer_reading': odometerReading,
      'cost': cost,
      'notes': notes,
      'invoice_urls': invoiceUrls,
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get maintenance history
  Future<List<MaintenanceRecord>> getMaintenanceHistory({
    String? vehicleId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = SupaClient.from('maintenance_records')
        .select('*')
        .order('completed_at', ascending: false);

    if (vehicleId != null) {
      query = query.eq('vehicle_id', vehicleId);
    }
    if (startDate != null) {
      query = query.gte('completed_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('completed_at', endDate.toIso8601String());
    }

    final response = await query;
    return (response as List)
        .map((m) => MaintenanceRecord.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Get vehicle diagnostics
  Future<VehicleDiagnostics> getVehicleDiagnostics(String vehicleId) async {
    final response = await SupaClient.rpc('get_vehicle_diagnostics', params: {
      'vehicle_id': vehicleId,
    });

    return VehicleDiagnostics.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
