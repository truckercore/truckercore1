/// Dashboard template utilities for arranging and spawning dashboard windows.
library;

// Group 2: package imports
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart' show Offset, Size; // for window frames
import 'package:screen_retriever/screen_retriever.dart';

// Group 3: relative imports
import '../../../core/dashboards/dashboard_window_manager.dart';

enum DashboardTemplate {
  dispatcher, // Fleet Overview + Live Tracking
  manager, // All dashboards
  driver, // Driver Performance only
  maintenance, // Fuel & Maintenance only
}

class TemplateManager {
  static Future<void> applyTemplate(DashboardTemplate template) async {
    final manager = DashboardWindowManager();

    switch (template) {
      case DashboardTemplate.dispatcher:
        await manager.openDashboard('fleet_overview');
        await Future.delayed(const Duration(milliseconds: 400));
        await manager.openDashboard('live_tracking');
        await _tileTwoWindows();
        break;
      case DashboardTemplate.manager:
        // Open all dashboards
        for (final id in const ['fleet_overview', 'live_tracking', 'driver_performance', 'fuel_maintenance', 'load_board']) {
          await manager.openDashboard(id);
        }
        // Best-effort: leave arrangement to user, or could cascade windows.
        break;
      case DashboardTemplate.driver:
        await manager.openDashboard('driver_performance');
        break;
      case DashboardTemplate.maintenance:
        await manager.openDashboard('fuel_maintenance');
        break;
    }
  }

  /// Attempts to arrange the first two sub-windows into left and right halves.
  static Future<void> _tileTwoWindows() async {
    try {
      final ids = await DesktopMultiWindow.getAllSubWindowIds();
      if (ids.length < 2) return;
      final screen = await ScreenRetriever.instance.getPrimaryDisplay();
      final w = screen.size.width.toDouble();
      final h = screen.size.height.toDouble();

      // Left half
      final left = WindowController.fromWindowId(ids[0]);
      await left.setFrame(const Offset(0, 0) & Size(w / 2, h));

      // Right half
      final right = WindowController.fromWindowId(ids[1]);
      await right.setFrame(Offset(w / 2, 0) & Size(w / 2, h));
    } catch (_) {
      // Ignore errors silently; layout is best-effort.
    }
  }
}
