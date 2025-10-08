import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FleetOverviewScreen extends ConsumerWidget {
  const FleetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => context.push('/owner-operator/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.window),
            tooltip: 'Open Dashboard Window',
            onPressed: () => _openDashboardWindow(context),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              // Fleet Summary Cards
              _FleetSummaryCards(),
              SizedBox(height: 24),
              
              // Active Vehicles
              Text(
                'Active Vehicles',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              _ActiveVehiclesList(),
              SizedBox(height: 24),
              
              // Recent Loads
              _RecentLoadsHeader(),
              SizedBox(height: 12),
              _RecentLoadsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/owner-operator/loads/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Load'),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Owner Operator',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                SizedBox(height: 8),
                Text(
                  'Fleet Management',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('Vehicles'),
            onTap: () {
              Navigator.pop(context);
              context.push('/owner-operator/vehicles');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Drivers'),
            onTap: () {
              Navigator.pop(context);
              context.push('/owner-operator/drivers');
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Loads'),
            onTap: () {
              Navigator.pop(context);
              context.push('/owner-operator/loads');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reports'),
            onTap: () {
              Navigator.pop(context);
              context.push('/owner-operator/reports');
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Documents'),
            onTap: () {
              Navigator.pop(context);
              context.push('/owner-operator/documents');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.push('/owner-operator/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  void _openDashboardWindow(BuildContext context) {
    // TODO: Implement desktop multi-window using desktop_multi_window
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening dashboard window...')),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/auth/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _FleetSummaryCards extends StatelessWidget {
  const _FleetSummaryCards();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: const [
        _SummaryCard(
          title: 'Active Vehicles',
          value: '8',
          subtitle: '2 idle',
          icon: Icons.local_shipping,
          color: Colors.blue,
        ),
        _SummaryCard(
          title: 'Active Drivers',
          value: '12',
          subtitle: '3 available',
          icon: Icons.person,
          color: Colors.green,
        ),
        _SummaryCard(
          title: 'Active Loads',
          value: '15',
          subtitle: '5 pending',
          icon: Icons.assignment,
          color: Colors.orange,
        ),
        _SummaryCard(
          title: 'Revenue (MTD)',
          value: '\$45.2K',
          subtitle: '+12% vs last month',
          icon: Icons.attach_money,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveVehiclesList extends StatelessWidget {
  const _ActiveVehiclesList();
  @override
  Widget build(BuildContext context) {
    final vehicles = [
      _VehicleStatus('Truck #101', 'John Smith', 'In Transit', 'Denver, CO', Colors.green),
      _VehicleStatus('Truck #102', 'Jane Doe', 'Loading', 'Chicago, IL', Colors.orange),
      _VehicleStatus('Truck #103', 'Mike Johnson', 'Idle', 'Kansas City, MO', Colors.grey),
    ];

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: vehicles.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          return ListTile(
            leading: Icon(Icons.local_shipping, color: vehicle.statusColor),
            title: Text(vehicle.vehicleId),
            subtitle: Text('${vehicle.driver} • ${vehicle.location}'),
            trailing: Chip(
              label: Text(vehicle.status),
              backgroundColor: vehicle.statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: vehicle.statusColor),
            ),
            onTap: () {},
          );
        },
      ),
    );
  }
}

class _VehicleStatus {
  final String vehicleId;
  final String driver;
  final String status;
  final String location;
  final Color statusColor;

  _VehicleStatus(this.vehicleId, this.driver, this.status, this.location, this.statusColor);
}

class _RecentLoadsHeader extends StatelessWidget {
  const _RecentLoadsHeader();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Loads',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () => context.push('/owner-operator/loads'),
          child: const Text('View All'),
        ),
      ],
    );
  }
}

class _RecentLoadsList extends StatelessWidget {
  const _RecentLoadsList();
  @override
  Widget build(BuildContext context) {
    final loads = [
      _LoadInfo('Load #12345', 'Chicago → Denver', 'In Transit', Colors.blue),
      _LoadInfo('Load #12346', 'Denver → Phoenix', 'Pending', Colors.orange),
      _LoadInfo('Load #12347', 'Phoenix → LA', 'Delivered', Colors.green),
    ];

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: loads.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final load = loads[index];
          return ListTile(
            leading: Icon(Icons.assignment, color: load.statusColor),
            title: Text(load.loadId),
            subtitle: Text(load.route),
            trailing: Chip(
              label: Text(load.status),
              backgroundColor: load.statusColor.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: load.statusColor),
            ),
            onTap: () {},
          );
        },
      ),
    );
  }
}

class _LoadInfo {
  final String loadId;
  final String route;
  final String status;
  final Color statusColor;

  _LoadInfo(this.loadId, this.route, this.status, this.statusColor);
}
