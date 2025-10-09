import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MultiFleetDashboard extends ConsumerWidget {
  const MultiFleetDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => context.push('/fleet-manager/notifications'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'logout') {
                context.go('/auth/login');
              } else if (value == 'settings') {
                context.push('/fleet-manager/settings');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Row(
        children: [
          // Left Panel - Fleet Selector
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: const _FleetSelectorPanel(),
          ),
          
          // Main Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 1));
              },
              child: const SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _MetricsGrid(),
                    SizedBox(height: 32),
                    
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fleet Status',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 12),
                              _FleetStatusTable(),
                            ],
                          ),
                        ),
                        SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alerts',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 12),
                              _AlertsList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                    
                    Text(
                      'Recent Activity',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    _RecentActivityTable(),
                  ],
                ),
              ),
            ),
          ),
        ],
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
                  'Fleet Manager',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                SizedBox(height: 8),
                Text(
                  'Multi-Fleet Management',
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
            leading: const Icon(Icons.business),
            title: const Text('Fleets'),
            onTap: () {
              Navigator.pop(context);
              context.push('/fleet-manager/fleets');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Users'),
            onTap: () {
              Navigator.pop(context);
              context.push('/fleet-manager/users');
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Compliance'),
            onTap: () {
              Navigator.pop(context);
              context.push('/fleet-manager/compliance');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pop(context);
              context.push('/fleet-manager/analytics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Audit Logs'),
            onTap: () {
              Navigator.pop(context);
              context.push('/fleet-manager/audit-logs');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              context.push('/fleet-manager/settings');
            },
          ),
        ],
      ),
    );
  }
}

class _FleetSelectorPanel extends StatelessWidget {
  const _FleetSelectorPanel();
  @override
  Widget build(BuildContext context) {
    final fleets = [
      _FleetItem('All Fleets', 45, true),
      _FleetItem('East Coast Operations', 15, false),
      _FleetItem('West Coast Operations', 18, false),
      _FleetItem('Midwest Hub', 12, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fleets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search fleets...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: fleets.length,
            itemBuilder: (context, index) {
              final fleet = fleets[index];
              return ListTile(
                leading: Icon(
                  Icons.business,
                  color: fleet.selected ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(fleet.name),
                subtitle: Text('${fleet.vehicleCount} vehicles'),
                selected: fleet.selected,
                onTap: () {},
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FleetItem {
  final String name;
  final int vehicleCount;
  final bool selected;

  _FleetItem(this.name, this.vehicleCount, this.selected);
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.8,
      children: const [
        _MetricCard(
          title: 'Total Vehicles',
          value: '45',
          change: '+3',
          icon: Icons.local_shipping,
          color: Colors.blue,
        ),
        _MetricCard(
          title: 'Active Drivers',
          value: '38',
          change: '+2',
          icon: Icons.person,
          color: Colors.green,
        ),
        _MetricCard(
          title: 'Active Loads',
          value: '52',
          change: '+8',
          icon: Icons.assignment,
          color: Colors.orange,
        ),
        _MetricCard(
          title: 'Compliance Score',
          value: '94%',
          change: '+2%',
          icon: Icons.verified,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.change,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    change,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetStatusTable extends StatelessWidget {
  const _FleetStatusTable();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(
        children: [
          _TableHeader(),
          Divider(height: 1),
          _TableRow('East Coast Operations', '15', '12', '3', '0', Colors.green),
          Divider(height: 1),
          _TableRow('West Coast Operations', '18', '14', '3', '1', Colors.orange),
          Divider(height: 1),
          _TableRow('Midwest Hub', '12', '10', '2', '0', Colors.green),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Fleet', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Active', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Idle', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text('Issues', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final String name;
  final String total;
  final String active;
  final String idle;
  final String issues;
  final Color statusColor;

  const _TableRow(
    this.name,
    this.total,
    this.active,
    this.idle,
    this.issues,
    this.statusColor,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(name),
              ],
            ),
          ),
          Expanded(child: Text(total)),
          Expanded(child: Text(active)),
          Expanded(child: Text(idle)),
          Expanded(child: Text(issues)),
          SizedBox(
            width: 80,
            child: TextButton(
              onPressed: () {},
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertsList extends StatelessWidget {
  const _AlertsList();
  @override
  Widget build(BuildContext context) {
    final alerts = [
      _Alert('Maintenance Due', 'Truck #205', 'warning'),
      _Alert('HOS Violation', 'Driver: Smith', 'error'),
      _Alert('Delayed Delivery', 'Load #456', 'warning'),
    ];

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final alert = alerts[index];
          final color = alert.severity == 'error' ? Colors.red : Colors.orange;
          
          return ListTile(
            leading: Icon(
              alert.severity == 'error' ? Icons.error : Icons.warning,
              color: color,
            ),
            title: Text(alert.title),
            subtitle: Text(alert.description),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {},
            ),
          );
        },
      ),
    );
  }
}

class _Alert {
  final String title;
  final String description;
  final String severity;

  _Alert(this.title, this.description, this.severity);
}

class _RecentActivityTable extends StatelessWidget {
  const _RecentActivityTable();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Action')),
          DataColumn(label: Text('Fleet')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          _buildDataRow('2 min ago', 'John Admin', 'Updated vehicle', 'East Coast', 'Success'),
          _buildDataRow('15 min ago', 'Jane Manager', 'Created load', 'West Coast', 'Success'),
          _buildDataRow('1 hour ago', 'Mike Supervisor', 'Assigned driver', 'Midwest', 'Success'),
        ],
      ),
    );
  }

  DataRow _buildDataRow(String time, String user, String action, String fleet, String status) {
    return DataRow(cells: [
      DataCell(Text(time)),
      DataCell(Text(user)),
      DataCell(Text(action)),
      DataCell(Text(fleet)),
      DataCell(
        Chip(
          label: Text(status),
          backgroundColor: Colors.green.withValues(alpha: 0.2),
          labelStyle: const TextStyle(color: Colors.green, fontSize: 12),
        ),
      ),
    ]);
  }
}
