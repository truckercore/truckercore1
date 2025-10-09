import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// only to hint caching exists (not used directly)
import '../../main.dart' show log; // assuming a logger named `log` exists in main.dart

/// Global error handler with recovery strategies
class ErrorHandler {
  static Future<T> handle<T>({
    required Future<T> Function() operation,
    required String operationName,
    T? fallbackValue,
    ErrorRecoveryStrategy recovery = ErrorRecoveryStrategy.none,
  }) async {
    try {
      return await operation();
    } on PostgrestException catch (e, stackTrace) {
      await _handleDatabaseError(e, stackTrace, operationName);
      if (recovery == ErrorRecoveryStrategy.useCache && fallbackValue != null) {
        log.w('Using cached data for $operationName');
        return fallbackValue;
      }
      rethrow;
    } on AuthException catch (e, stackTrace) {
      await _handleAuthError(e, stackTrace, operationName);
      rethrow;
    } catch (e, stackTrace) {
      await _handleUnknownError(e, stackTrace, operationName);
      if (fallbackValue != null) {
        return fallbackValue;
      }
      rethrow;
    }
  }

  static Future<void> _handleDatabaseError(
    PostgrestException error,
    StackTrace stackTrace,
    String operation,
  ) async {
    log.e('Database error in $operation', error: error, stackTrace: stackTrace);
    await Sentry.captureException(error, stackTrace: stackTrace, withScope: (scope) {
      scope.setTag('operation', operation);
      if (error.code != null) scope.setTag('status_code', error.code!);
    });
  }

  static Future<void> _handleAuthError(
    AuthException error,
    StackTrace stackTrace,
    String operation,
  ) async {
    log.e('Auth error in $operation', error: error, stackTrace: stackTrace);
    await Sentry.captureException(error, stackTrace: stackTrace);

    if (error.message.contains('expired') || error.message.contains('invalid')) {
      log.i('Attempting to refresh session');
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (refreshError, st) {
        log.e('Session refresh failed', error: refreshError, stackTrace: st);
        try {
          await Supabase.instance.client.auth.signOut();
        } catch (_) {}
      }
    }
  }

  static Future<void> _handleUnknownError(
    Object error,
    StackTrace stackTrace,
    String operation,
  ) async {
    log.e('Unknown error in $operation', error: error, stackTrace: stackTrace);
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

enum ErrorRecoveryStrategy {
  none,
  useCache,
  retry,
  fallback,
}
