
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monitored_storage.dart';
import 'storage_monitoring.dart';

/// Abstraction over dashboard persistence to enable swapping storage backend.
abstract class DashboardStorage {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);

  Future<List<String>?> getStringList(String key);
  Future<void> setStringList(String key, List<String> value);

  Future<void> remove(String key);
}

class SharedPrefsDashboardStorage implements DashboardStorage {
  const SharedPrefsDashboardStorage();

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async {
    final p = await _prefs();
    return p.getString(key);
    }

  @override
  Future<void> setString(String key, String value) async {
    final p = await _prefs();
    await p.setString(key, value);
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final p = await _prefs();
    return p.getStringList(key);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    final p = await _prefs();
    await p.setStringList(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final p = await _prefs();
    await p.remove(key);
  }
}


final dashboardStorageProvider = Provider<DashboardStorage>((ref) {
  final base = const SharedPrefsDashboardStorage();
  final monitor = DefaultStorageMonitor.instance;
  return MonitoredDashboardStorage(base, monitor);
});
