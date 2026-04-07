import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboards/driver_performance/driver_performance_dashboard.dart';
import '../../features/dashboards/fleet_overview/fleet_overview_dashboard.dart';
import '../../features/dashboards/fuel_maintenance/fuel_maintenance_dashboard.dart';
import '../../features/dashboards/live_tracking/live_tracking_dashboard.dart';
import '../../features/dashboards/load_board/load_board_dashboard.dart';

/// Entry point for dashboard windows
/// This is called when a new dashboard window is created
class DashboardEntry extends StatelessWidget {
  final WindowController controller;
  final Map<String, dynamic> args;

  const DashboardEntry({super.key, required this.controller, required this.args});

  @override
  Widget build(BuildContext context) {
    // Parse window arguments provided from main via args[2]
    final Map<String, dynamic> data = args;
    final String dashboardId = (data['dashboardId'] ?? '').toString();
    final Map<String, dynamic> params = (data['params'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final overrides = <Override>[];
    final mockCount = params['mockVehicleCount'];
    if (mockCount is int) {
      // Provide mock vehicle count specifically for Live Tracking dashboard
      try {
        overrides.add(mockVehicleCountProvider.overrideWithValue(mockCount));
      } catch (_) {}
    }

    return ProviderScope(
      overrides: overrides,
      child: _DashboardRouter(dashboardId: dashboardId, params: params),
    );
  }
}

class _DashboardRouter extends StatelessWidget {
  final String dashboardId;
  final Map<String, dynamic> params;

  const _DashboardRouter({required this.dashboardId, required this.params});

  @override
  Widget build(BuildContext context) {
    switch (dashboardId) {
      case 'fleet_overview':
        return const FleetOverviewDashboard();
      case 'live_tracking':
        return const LiveTrackingDashboard();
      case 'load_board':
        return const LoadBoardDashboard();
      case 'driver_performance':
        return const DriverPerformanceDashboard();
      case 'fuel_maintenance':
        return const FuelMaintenanceDashboard();
      default:
        return _UnknownDashboard(dashboardId: dashboardId);
    }
  }
}

class _UnknownDashboard extends StatelessWidget {
  final String dashboardId;

  const _UnknownDashboard({required this.dashboardId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Unknown Dashboard: $dashboardId', style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
