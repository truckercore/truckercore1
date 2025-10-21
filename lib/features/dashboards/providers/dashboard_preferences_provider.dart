import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/dashboard_preferences.dart' as models;

// Riverpod provider for dashboard preferences (family by dashboardId)
final dashboardPreferencesProvider = StateNotifierProvider.autoDispose
    .family<DashboardPreferencesNotifier, models.DashboardPreferences, String>(
  (ref, dashboardId) {
    return DashboardPreferencesNotifier(dashboardId);
  },
);

// Separate notifier provider for easier access where `.notifier` causes issues with family types
final dashboardPreferencesNotifierProvider = Provider.autoDispose
    .family<DashboardPreferencesNotifier, String>((ref, dashboardId) {
  return ref.watch(dashboardPreferencesProvider(dashboardId).notifier);
});

class DashboardPreferencesNotifier
    extends StateNotifier<models.DashboardPreferences> {
  final String dashboardId;

  DashboardPreferencesNotifier(this.dashboardId)
      : super(models.DashboardPreferences(dashboardId: dashboardId)) {
    _load();
  }

  Future<File> _prefsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(path.join(dir.path, 'dashboard_prefs_$dashboardId.json'));
  }

  Future<void> _load() async {
    try {
      final file = await _prefsFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        state = models.DashboardPreferences.fromJson(json);
      }
    } catch (_) {
      // Ignore load errors; keep defaults
    }
  }

  Future<void> _save() async {
    try {
      final file = await _prefsFile();
      await file.writeAsString(jsonEncode(state.toJson()));
    } catch (_) {
      // Ignore save errors
    }
  }

  // Compatibility helpers expected by callers
  models.DashboardPreferences getPreferences(String id) => state;

  Future<void> updatePreferences(
    String id,
    models.DashboardPreferences prefs,
  ) async {
    state = prefs.copyWith();
    await _save();
  }

  void setAutoRefresh(bool value) {
    state = state.copyWith(autoRefresh: value);
    _save();
  }

  void setRefreshInterval(int seconds) {
    state = state.copyWith(refreshIntervalSeconds: seconds);
    _save();
  }

  void setAlwaysOnTop(bool value) {
    state = state.copyWith(alwaysOnTop: value);
    _save();
  }

  void setShowNotifications(bool value) {
    state = state.copyWith(showNotifications: value);
    _save();
  }

  Future<void> saveWindowPosition(
    String id,
    Offset? position,
    Size? size,
  ) async {
    state = state.copyWith(savedPosition: position, savedSize: size);
    await _save();
  }

  void updateCustomSetting(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(state.customSettings);
    updated[key] = value;
    state = state.copyWith(customSettings: updated);
    _save();
  }
}
