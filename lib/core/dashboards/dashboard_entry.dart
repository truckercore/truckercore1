import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/dashboards/fleet_overview/fleet_overview_dashboard.dart';
import '../../features/dashboards/live_tracking/live_tracking_dashboard.dart';
import '../../features/dashboards/load_board/load_board_dashboard.dart';

/// Entry point for dashboard windows
/// This is called when a new dashboard window is created
class DashboardEntry extends StatelessWidget {
  final WindowController controller;

  const DashboardEntry({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final args = controller.getArgs();
    final Map<String, dynamic> data = args is String ? (jsonDecode(args) as Map<String, dynamic>) : <String, dynamic>{};
    final String dashboardId = (data['dashboardId'] ?? '').toString();
    final Map<String, dynamic> params = (data['params'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return ProviderScope(
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
