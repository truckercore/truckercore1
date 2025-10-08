import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../error/error_handler.dart';

/// Wraps an async operation with ErrorHandler and returns AsyncValue
AsyncValue<T> withErrorHandling<T>({
  required Future<T> Function() operation,
  required String operationName,
  T? cachedValue,
}) {
  return AsyncValue.guard(() => ErrorHandler.handle(
        operation: operation,
        operationName: operationName,
        fallbackValue: cachedValue,
        recovery: cachedValue != null
            ? ErrorRecoveryStrategy.useCache
            : ErrorRecoveryStrategy.none,
      ));
}

/*
// Example usage (kept commented to avoid unresolved imports if Vehicle isn't available here):
final resilientDataProvider = FutureProvider<List<Vehicle>>((ref) async {
  final cached = await ref.read(offlineStorageProvider).getVehicles();
  return await ErrorHandler.handle(
    operation: () async {
      final data = await Supabase.instance.client.from('vehicles').select();
      return data.map((json) => Vehicle.fromJson(json)).toList();
    },
    operationName: 'fetch_vehicles',
    fallbackValue: cached,
    recovery: ErrorRecoveryStrategy.useCache,
  );
});
*/
