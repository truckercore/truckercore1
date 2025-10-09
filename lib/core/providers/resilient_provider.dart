import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../error/error_handler.dart';

/// Wraps a provider with error handling and recovery
Future<AsyncValue<T>> withErrorHandling<T>({
  required Future<T> Function() operation,
  required String operationName,
  T? cachedValue,
}) async {
  try {
    final result = await ErrorHandler.handle(
      operation: operation,
      operationName: operationName,
      fallbackValue: cachedValue,
      recovery: cachedValue != null 
          ? ErrorRecoveryStrategy.useCache 
          : ErrorRecoveryStrategy.none,
    );
    return AsyncValue.data(result);
  } catch (error, stackTrace) {
    return AsyncValue.error(error, stackTrace);
  }
}
