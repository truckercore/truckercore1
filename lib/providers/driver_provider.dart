import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver.dart';
import '../services/api_service.dart';
import 'load_provider.dart' show apiServiceProvider; // reuse same instance

final driversProvider = FutureProvider<List<Driver>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.fetchDrivers();
  return response.map((json) => Driver.fromJson(json as Map<String, dynamic>)).toList();
});

final availableDriversProvider = Provider<AsyncValue<List<Driver>>>((ref) {
  final driversAsync = ref.watch(driversProvider);
  return driversAsync.whenData(
    (drivers) => drivers.where((d) => d.status == DriverStatus.available).toList(),
  );
});

class DriverNotifier extends StateNotifier<AsyncValue<List<Driver>>> {
  DriverNotifier(this.apiService) : super(const AsyncValue.loading()) {
    _loadDrivers();
  }

  final ApiService apiService;

  Future<void> _loadDrivers() async {
    try {
      final response = await apiService.fetchDrivers();
      final drivers = response
          .map((json) => Driver.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(drivers);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadDrivers();
  }
}

final driverNotifierProvider =
    StateNotifierProvider<DriverNotifier, AsyncValue<List<Driver>>>((ref) {
  return DriverNotifier(ref.watch(apiServiceProvider));
});
