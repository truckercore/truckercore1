import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_load.dart';
import '../models/driver_status.dart';
import '../models/hos_summary.dart';

/// Offline storage provider for driver app data
final offlineStorageProvider = Provider<OfflineStorage>((ref) {
  return OfflineStorage();
});

class OfflineStorage {
  static const _keyDriverStatus = 'offline_driver_status';
  static const _keyActiveLoad = 'offline_active_load';
  static const _keyHOSSummary = 'offline_hos_summary';
  static const _keyLoads = 'offline_loads';
  static const _keyPendingSync = 'offline_pending_sync';

  // Save driver status for offline access
  Future<void> saveDriverStatus(DriverStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDriverStatus, jsonEncode(status.toJson()));
  }

  Future<DriverStatus?> getDriverStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyDriverStatus);
    if (data == null) return null;
    return DriverStatus.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  // Save active load
  Future<void> saveActiveLoad(ActiveLoad? load) async {
    final prefs = await SharedPreferences.getInstance();
    if (load == null) {
      await prefs.remove(_keyActiveLoad);
    } else {
      await prefs.setString(_keyActiveLoad, jsonEncode(load.toJson()));
    }
  }

  Future<ActiveLoad?> getActiveLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyActiveLoad);
    if (data == null) return null;
    return ActiveLoad.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  // Save HOS summary
  Future<void> saveHOSSummary(HOSSummary hos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHOSSummary, jsonEncode(hos.toJson()));
  }

  Future<HOSSummary?> getHOSSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyHOSSummary);
    if (data == null) return null;
    return HOSSummary.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  // Save loads list
  Future<void> saveLoads(List<ActiveLoad> loads) async {
    final prefs = await SharedPreferences.getInstance();
    final data = loads.map((l) => l.toJson()).toList();
    await prefs.setString(_keyLoads, jsonEncode(data));
  }

  Future<List<ActiveLoad>> getLoads() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyLoads);
    if (data == null) return [];
    final List<dynamic> list = jsonDecode(data) as List<dynamic>;
    return list.map((json) => ActiveLoad.fromJson(json as Map<String, dynamic>)).toList();
  }

  // Queue actions for sync when back online
  Future<void> queueForSync(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_keyPendingSync) ?? [];
    existing.add(jsonEncode(action));
    await prefs.setStringList(_keyPendingSync, existing);
  }

  Future<List<Map<String, dynamic>>> getPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_keyPendingSync) ?? [];
    return data.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  Future<void> clearPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingSync);
  }

  // Clear all offline data
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDriverStatus);
    await prefs.remove(_keyActiveLoad);
    await prefs.remove(_keyHOSSummary);
    await prefs.remove(_keyLoads);
    await prefs.remove(_keyPendingSync);
  }
}
