import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supa_client.dart';
import '../models/load.dart';

final loadServiceProvider = Provider<LoadService>((ref) {
  return LoadService();
});

final availableLoadsProvider = StreamProvider<List<Load>>((ref) {
  final service = ref.watch(loadServiceProvider);
  return service.watchAvailableLoads();
});

final myActiveLoadsProvider = StreamProvider<List<Load>>((ref) {
  final service = ref.watch(loadServiceProvider);
  return service.watchMyActiveLoads();
});

class LoadService {
  /// Watch available loads for dispatch
  Stream<List<Load>> watchAvailableLoads() {
    return SupaClient.stream(
      'loads',
      primaryKey: const ['id'],
      filter: (query) => query.eq('status', 'available').order('pickup_date', ascending: true),
    ).map((data) => data.map((l) => Load.fromJson(Map<String, dynamic>.from(l))).toList());
  }

  /// Watch active loads for current driver
  Stream<List<Load>> watchMyActiveLoads() {
    return SupaClient.stream(
      'loads',
      primaryKey: const ['id'],
      filter: (query) => query
          .in_('status', ['assigned', 'in_transit', 'at_pickup', 'at_delivery'])
          .order('pickup_date', ascending: true),
    ).map((data) => data.map((l) => Load.fromJson(Map<String, dynamic>.from(l))).toList());
  }

  /// Get load details
  Future<Load> getLoad(String loadId) async {
    final response = await SupaClient.from('loads').select('*').eq('id', loadId).single();
    return Load.fromJson(Map<String, dynamic>.from(response as Map));
    }

  /// Create new load
  Future<String> createLoad({
    required LoadLocation pickupLocation,
    required LoadLocation deliveryLocation,
    required DateTime pickupDate,
    required DateTime deliveryDate,
    required double weight,
    required String commodity,
    required double rate,
    required double miles,
    String? specialInstructions,
  }) async {
    final response = await SupaClient.from('loads')
        .insert({
          'load_number': _generateLoadNumber(),
          'status': 'available',
          'pickup_location': pickupLocation.toJson(),
          'delivery_location': deliveryLocation.toJson(),
          'pickup_date': pickupDate.toIso8601String(),
          'delivery_date': deliveryDate.toIso8601String(),
          'weight': weight,
          'commodity': commodity,
          'rate': rate,
          'miles': miles,
          'special_instructions': specialInstructions,
        })
        .select('id')
        .single();

    return (response as Map)['id'] as String;
  }

  /// Assign load to driver
  Future<void> assignLoad({
    required String loadId,
    required String driverId,
    required String vehicleId,
  }) async {
    await SupaClient.from('loads').update({
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'status': 'assigned',
      'assigned_at': DateTime.now().toIso8601String(),
    }).eq('id', loadId);
  }

  /// Update load status
  Future<void> updateLoadStatus({
    required String loadId,
    required String status,
  }) async {
    await SupaClient.from('loads').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', loadId);
  }

  /// Mark load as picked up
  Future<void> markPickedUp(String loadId) async {
    await SupaClient.from('loads').update({
      'status': 'in_transit',
      'actual_pickup_time': DateTime.now().toIso8601String(),
    }).eq('id', loadId);
  }

  /// Mark load as delivered
  Future<void> markDelivered({
    required String loadId,
    required String signatureUrl,
    List<String>? photoUrls,
  }) async {
    await SupaClient.from('loads').update({
      'status': 'delivered',
      'actual_delivery_time': DateTime.now().toIso8601String(),
      'signature_url': signatureUrl,
      'delivery_photo_urls': photoUrls,
    }).eq('id', loadId);
  }

  /// Get load history
  Future<List<Load>> getLoadHistory({
    String? driverId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    var query = SupaClient.from('loads')
        .select('*')
        .eq('status', 'delivered')
        .order('actual_delivery_time', ascending: false)
        .limit(limit);

    if (driverId != null) {
      query = query.eq('driver_id', driverId);
    }
    if (startDate != null) {
      query = query.gte('actual_delivery_time', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('actual_delivery_time', endDate.toIso8601String());
    }

    final response = await query;
    return (response as List).map((l) => Load.fromJson(Map<String, dynamic>.from(l))).toList();
  }

  /// Search available loads
  Future<List<Load>> searchLoads({
    String? originState,
    String? destinationState,
    DateTime? pickupDateStart,
    DateTime? pickupDateEnd,
    double? minRate,
  }) async {
    var query = SupaClient.from('loads').select('*').eq('status', 'available');

    if (pickupDateStart != null) {
      query = query.gte('pickup_date', pickupDateStart.toIso8601String());
    }
    if (pickupDateEnd != null) {
      query = query.lte('pickup_date', pickupDateEnd.toIso8601String());
    }
    if (minRate != null) {
      query = query.gte('rate', minRate);
    }

    final response = await query.order('pickup_date', ascending: true);
    return (response as List).map((l) => Load.fromJson(Map<String, dynamic>.from(l))).toList();
  }

  String _generateLoadNumber() {
    final now = DateTime.now();
    return 'LD${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }
}
