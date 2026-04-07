import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/driver.dart';
import '../../../services/api_service.dart';
import 'package:truckercore1/providers/api_provider.dart';

// Define loading state
final driversLoadingProvider = StateProvider<bool>((ref) => false);

// Define drivers list provider
final driversProvider = FutureProvider<List<Driver>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final List<dynamic> raw = await apiService.fetchDrivers();
  final drivers = raw.map<Driver>((e) => Driver.fromJson(e as Map<String, dynamic>)).toList();
  return drivers;
});

// Status getter helper
extension DriverProviderExtension on AsyncValue<List<Driver>> {
  bool get isLoading => this is AsyncLoading<List<Driver>>;
  bool get hasError => this is AsyncError<List<Driver>>;
  bool get hasData => this is AsyncData<List<Driver>>;
}
