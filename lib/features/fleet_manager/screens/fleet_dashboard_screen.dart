import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/fleet_tracking_service.dart';
import '../widgets/fleet_map_view.dart';
import '../widgets/fleet_stats_cards.dart';
import '../widgets/vehicle_list_view.dart';

class FleetDashboardScreen extends ConsumerStatefulWidget {
  const FleetDashboardScreen({super.key});

  @override
  ConsumerState<FleetDashboardScreen> createState() => _FleetDashboardScreenState();
}

class _FleetDashboardScreenState extends ConsumerState<FleetDashboardScreen> {
  bool _showMap = true;

  @override
  Widget build(BuildContext context) {
    final activeVehicles = ref.watch(activeVehiclesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Manager'),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () => setState(() => _showMap = !_showMap),
            tooltip: _showMap ? 'List View' : 'Map View',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.pushNamed(context, '/fleet/alerts'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Overview
          const FleetStatsCards(),

          // Map or List View
          Expanded(
            child: activeVehicles.when(
              data: (vehicles) => _showMap
                  ? FleetMapView(vehicles: vehicles)
                  : VehicleListView(vehicles: vehicles),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(activeVehiclesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/fleet/reports'),
        icon: const Icon(Icons.analytics),
        label: const Text('Reports'),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Vehicles'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Active'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Idle'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Offline'),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
