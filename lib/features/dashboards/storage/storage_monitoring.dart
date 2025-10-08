import 'dart:collection';

/// Lightweight monitoring interfaces for dashboard storage operations.
/// These are intentionally simple and in-memory to avoid new dependencies.

/// Snapshot of basic metrics for a single storage operation.
class OperationStats {
  int successCount = 0;
  int errorCount = 0;
  int calls = 0;
  double totalMs = 0; // sum of latencies in milliseconds
  double maxMs = 0;

  double get avgMs => calls == 0 ? 0 : totalMs / calls;
}

/// Interface for recording storage operation metrics.
abstract class StorageMonitor {
  /// Record a storage operation measurement.
  /// op should be a stable name like: getString, setString, getStringList, setStringList, remove
  void recordOperation({
    required String op,
    required double ms,
    required bool success,
    Map<String, Object?> meta,
  });

  /// Read-only view of metrics per operation.
  Map<String, OperationStats> getMetrics();

  /// Clears accumulated metrics (useful for tests or resets).
  void reset();
}

/// Default in-memory implementation. Thread-safety is not a concern for Flutter UI usage.
class DefaultStorageMonitor implements StorageMonitor {
  DefaultStorageMonitor._();
  static final DefaultStorageMonitor instance = DefaultStorageMonitor._();

  final Map<String, OperationStats> _byOp = HashMap<String, OperationStats>();

  @override
  void recordOperation({
    required String op,
    required double ms,
    required bool success,
    Map<String, Object?> meta = const {},
  }) {
    final stats = _byOp.putIfAbsent(op, () => OperationStats());
    stats.calls += 1;
    stats.totalMs += ms;
    if (ms > stats.maxMs) stats.maxMs = ms;
    if (success) {
      stats.successCount += 1;
    } else {
      stats.errorCount += 1;
    }
  }

  @override
  Map<String, OperationStats> getMetrics() => Map.unmodifiable(_byOp);

  @override
  void reset() => _byOp.clear();
}
