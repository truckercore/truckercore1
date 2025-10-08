import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/dashboards/base_dashboard.dart';

/// Minimal placeholder Fleet Overview dashboard to satisfy router import.
class FleetOverviewDashboard extends BaseDashboard {
  const FleetOverviewDashboard({super.key})
      : super(
          config: const DashboardConfig(
            id: 'fleet_overview',
            title: 'Fleet Overview Dashboard',
            defaultSize: Size(1600, 900),
            allowResize: true,
          ),
        );

  @override
  ConsumerState<FleetOverviewDashboard> createState() => _FleetOverviewDashboardState();

  @override
  Widget buildDashboard(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 80, color: Colors.green),
          SizedBox(height: 24),
          Text('Fleet Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('This dashboard will show fleet KPIs and attention items.', style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FleetOverviewDashboardState extends BaseDashboardState<FleetOverviewDashboard> {}
