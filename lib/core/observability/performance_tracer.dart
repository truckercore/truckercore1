import 'package:sentry_flutter/sentry_flutter.dart';

class PerformanceTracer {
  /// Start a performance transaction and bind to scope so child spans attach automatically.
  static ISentrySpan? startTransaction(
    String name, {
    String operation = 'task',
    Map<String, dynamic>? data,
  }) {
    try {
      final tx = Sentry.startTransaction(
        name,
        operation,
        bindToScope: true,
      );
      if (data != null) {
        for (final entry in data.entries) {
          tx.setData(entry.key, entry.value);
        }
      }
      return tx;
    } catch (_) {
      return null;
    }
  }

  /// Start a child span from the current transaction/span.
  static ISentrySpan? startSpan(
    String operation, {
    String? description,
    Map<String, dynamic>? data,
  }) {
    try {
      final parent = Sentry.getSpan();
      final span = parent?.startChild(operation, description: description);
      if (span != null && data != null) {
        for (final entry in data.entries) {
          span.setData(entry.key, entry.value);
        }
      }
      return span;
    } catch (_) {
      return null;
    }
  }

  /// Finish a span/transaction with status (defaults to ok).
  static Future<void> finish(
    ISentrySpan? span, {
    SpanStatus status = const SpanStatus.ok(),
  }) async {
    try {
      if (span != null) {
        span.status = status;
        await span.finish();
      }
    } catch (_) {}
  }

  /// Measure and trace an async function execution. Captures exception to Sentry.
  static Future<T> trace<T>(
    String operation,
    Future<T> Function() function, {
    String? description,
    Map<String, dynamic>? data,
  }) async {
    final span = startSpan(operation, description: description, data: data);
    try {
      final result = await function();
      await finish(span);
      return result;
    } catch (e, st) {
      await finish(span, status: const SpanStatus.internalError());
      try {
        await Sentry.captureException(e, stackTrace: st);
      } catch (_) {}
      rethrow;
    }
  }

  /// Add breadcrumb with optional data.
  static void addBreadcrumb(
    String message, {
    String category = 'performance',
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category,
        level: level,
        data: data,
      ));
    } catch (_) {}
  }

  /// Set performance-related context on current scope.
  static void setContext(String key, dynamic value) {
    try {
      Sentry.configureScope((scope) {
        scope.setContexts(key, value);
      });
    } catch (_) {}
  }

  /// Record a custom measurement on the current span/transaction.
  static void recordMeasurement(
    String name,
    num value, {
    SentryMeasurementUnit? unit,
  }) {
    try {
      final span = Sentry.getSpan();
      span?.setMeasurement(name, value, unit: unit);
    } catch (_) {}
  }

  /// Trace a database query execution with description and query data.
  static Future<T> traceQuery<T>(
    String query,
    Future<T> Function() function,
  ) async {
    return trace(
      'db.query',
      function,
      description: query,
      data: {'query': query},
    );
  }

  /// Trace a network request execution with URL and method details.
  static Future<T> traceNetworkRequest<T>(
    String url,
    String method,
    Future<T> Function() function,
  ) async {
    return trace(
      'http.request',
      function,
      description: '$method $url',
      data: {
        'url': url,
        'method': method,
      },
    );
  }

  /// Record render performance metrics as measurements on current span.
  static void recordRenderMetrics({
    required int widgetCount,
    required Duration buildTime,
    required Duration layoutTime,
  }) {
    try {
      recordMeasurement('widget_count', widgetCount);
      recordMeasurement('build_time_ms', buildTime.inMilliseconds);
      recordMeasurement('layout_time_ms', layoutTime.inMilliseconds);
    } catch (_) {}
  }
}
