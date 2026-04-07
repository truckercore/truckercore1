import 'package:flutter/material.dart';

/// Simple dashboard screen blueprint provided by the TruckerCore plan.
/// This screen is not wired into routing by default to avoid conflicts
/// with the existing DesktopScaffold/AppRouter. You can navigate to it
/// manually for experiments, or integrate portions into your router.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TruckerCore: Unified Fleet Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Import CSV',
            onPressed: () {
              // TODO: Navigate to CSV Import Wizard
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open CSV Import Wizard')),
              );
            },
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Print',
            onPressed: () {
              // TODO: Trigger printing sample
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Open Print Preview')),
              );
            },
            icon: const Icon(Icons.print),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map),
                label: Text('Fleet Map'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Maintenance'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_gas_station),
                label: Text('Fuel Logs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.supervisor_account),
                label: Text('Drivers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.work),
                label: Text('Loads'),
              ),
            ],
            selectedIndex: 0,
          ),
          const VerticalDivider(width: 1),
          const Expanded(
            child: Center(
              child: Text(
                'Welcome to TruckerCore — All fleet data, one pane.\n\n(Implement widgets for Dispatch, Fleet Map, Analytics, etc.)',
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      ),
    );
  }
}
