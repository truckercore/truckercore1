import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Manages dashboard windows lifecycle using desktop_multi_window.
/// Simple singleton that tracks open dashboards by id.
class DashboardWindowManager {
  static final DashboardWindowManager _instance = DashboardWindowManager._internal();
  factory DashboardWindowManager() => _instance;
  DashboardWindowManager._internal();

  /// Map of dashboardId -> sub-windowId
  final Map<String, int> _open = <String, int>{};

  bool isDashboardOpen(String dashboardId) => _open.containsKey(dashboardId);

  /// Open (or focus if already open) a dashboard sub-window by id.
  Future<void> openDashboard(String dashboardId, {Map<String, dynamic>? params}) async {
    if (_open.containsKey(dashboardId)) {
      // If already open, try to show the existing window
      final id = _open[dashboardId]!;
      try {
        final ctrl = WindowController.fromWindowId(id);
        await ctrl.show();
      } catch (_) {}
      return;
    }

    final payload = jsonEncode({
      'dashboardId': dashboardId,
      'params': params ?? <String, dynamic>{},
    });

    final window = await DesktopMultiWindow.createWindow(payload);
    // Best-effort: position/size/title will be handled by each dashboard via BaseDashboard
    await window.setTitle('Dashboard: $dashboardId');
    await window.center();
    await window.show();

    _open[dashboardId] = window.windowId;
  }

  Future<void> closeDashboard(String dashboardId) async {
    final id = _open.remove(dashboardId);
    if (id == null) return;
    try {
      final ctrl = WindowController.fromWindowId(id);
      await ctrl.close();
    } catch (_) {}
  }

  Future<void> closeAllDashboards() async {
    final ids = List<String>.from(_open.keys);
    for (final d in ids) {
      await closeDashboard(d);
    }
  }

  /// Internal: allow manual marking of a dashboard as closed when window is destroyed elsewhere.
  void markClosed(String dashboardId) {
    _open.remove(dashboardId);
  }
}
