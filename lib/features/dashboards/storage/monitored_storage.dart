import 'dart:async';

import 'dashboard_storage.dart';
import 'storage_monitoring.dart';

/// Decorator that wraps a DashboardStorage and records latency/success metrics
/// for each operation using a StorageMonitor.
class MonitoredDashboardStorage implements DashboardStorage {
  MonitoredDashboardStorage(this._inner, this._monitor);

  final DashboardStorage _inner;
  final StorageMonitor _monitor;

  Future<T> _measure<T>(String op, Future<T> Function() fn) async {
    final sw = Stopwatch()..start();
    bool success = true;
    try {
      final result = await fn();
      return result;
    } catch (e) {
      success = false;
      rethrow;
    } finally {
      sw.stop();
      // record milliseconds as double
      _monitor.recordOperation(op: op, ms: sw.elapsedMicroseconds / 1000.0, success: success, meta: const {});
    }
  }

  @override
  Future<String?> getString(String key) => _measure('getString', () => _inner.getString(key));

  @override
  Future<void> setString(String key, String value) => _measure('setString', () => _inner.setString(key, value));

  @override
  Future<List<String>?> getStringList(String key) => _measure('getStringList', () => _inner.getStringList(key));

  @override
  Future<void> setStringList(String key, List<String> value) => _measure('setStringList', () => _inner.setStringList(key, value));

  @override
  Future<void> remove(String key) => _measure('remove', () => _inner.remove(key));
}
