import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';

class DriverDashboard extends ConsumerWidget {
  const DriverDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real data providers
    final statusAsync = ref.watch(driverStatusProvider);
    final activeLoadAsync = ref.watch(activeLoadProvider);
    final hosAsync = ref.watch(hosSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => context.push('/driver/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/driver/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverStatusProvider);
            ref.invalidate(activeLoadProvider);
            ref.invalidate(hosSummaryProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: statusAsync.when(
            data: (status) => _buildContent(context, ref, status, activeLoadAsync, hosAsync),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading data: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(driverStatusProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Loads'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'HOS'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Documents'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
              context.push('/driver/loads');
              break;
            case 2:
              context.push('/driver/hos');
              break;
            case 3:
              context.push('/driver/documents');
              break;
          }
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    dynamic status,
    AsyncValue activeLoadAsync,
    AsyncValue hosAsync,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current Status Card
        _CurrentStatusCard(status: status),
        const SizedBox(height: 16),
        
        // Quick Actions
        const _QuickActionsGrid(),
        const SizedBox(height: 24),
        
        // Active Load
        const Text(
          'Active Load',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        activeLoadAsync.when(
          data: (load) => load != null
              ? _ActiveLoadCard(load: load)
              : const _NoActiveLoadCard(),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error loading active load'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // HOS Summary
        const Text(
          'Hours of Service',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        hosAsync.when(
          data: (hos) => hos != null
              ? _HOSSummaryCard(hos: hos)
              : const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No HOS data available'),
                  ),
                ),
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error loading HOS data'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Recent Activity
        const Text(
          'Recent Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const _RecentActivityList(),
      ],
    );
  }
}

class _CurrentStatusCard extends StatelessWidget {
  final dynamic status;

  const _CurrentStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusColor = status?.isActive == true ? Colors.green : Colors.grey;
    final driveTimeLeft = status?.driveTimeLeft ?? 0.0;
    final shiftTimeLeft = status?.shiftTimeLeft ?? 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status?.statusDisplay ?? 'Unknown',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // TODO: Implement status change dialog
                  },
                  child: const Text('Change Status'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusInfo(
                  label: 'Drive Time Left',
                  value: _formatHours(driveTimeLeft),
                  icon: Icons.drive_eta,
                ),
                _StatusInfo(
                  label: 'Shift Time Left',
                  value: _formatHours(shiftTimeLeft),
                  icon: Icons.access_time,
                ),
                _StatusInfo(
                  label: 'Next Break',
                  value: _calculateNextBreak(driveTimeLeft),
                  icon: Icons.free_breakfast,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  String _calculateNextBreak(double driveTimeLeft) {
    // Simplified: break needed after 8 hours of driving
    if (driveTimeLeft > 3) return '3h+';
    return _formatHours(driveTimeLeft);
  }
}

class _StatusInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatusInfo({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _QuickActionButton(
          icon: Icons.play_arrow,
          label: 'Start Trip',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Starting trip...')),
            );
          },
        ),
        _QuickActionButton(
          icon: Icons.location_on,
          label: 'Location',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Updating location...')),
            );
          },
        ),
        _QuickActionButton(
          icon: Icons.camera_alt,
          label: 'Scan',
          onTap: () {
            context.push('/driver/scan');
          },
        ),
        _QuickActionButton(
          icon: Icons.message,
          label: 'Messages',
          onTap: () {
            context.push('/driver/messages');
          },
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveLoadCard extends StatelessWidget {
  final dynamic load;

  const _ActiveLoadCard({required this.load});

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
                Text(
                  'Load #${load.loadNumber}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text(_getStatusDisplay(load.status)),
                  backgroundColor: _getStatusColor(load.status).withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: _getStatusColor(load.status)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LoadInfoRow(
              icon: Icons.location_on,
              label: 'Pickup',
              value: load.pickupLocation,
            ),
            const SizedBox(height: 8),
            _LoadInfoRow(
              icon: Icons.flag,
              label: 'Delivery',
              value: load.deliveryLocation,
            ),
            const SizedBox(height: 8),
            _LoadInfoRow(
              icon: Icons.schedule,
              label: 'ETA',
              value: load.eta != null ? _formatDateTime(load.eta) : 'N/A',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement navigation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening navigation...')),
                      );
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('Navigate'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/driver/loads/${load.id}');
                    },
                    icon: const Icon(Icons.info),
                    label: const Text('Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'in_transit':
        return 'In Transit';
      case 'pending':
        return 'Pending';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_transit':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);
    
    if (diff.inHours < 24) {
      return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.month}/${dt.day}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _NoActiveLoadCard extends StatelessWidget {
  const _NoActiveLoadCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Load',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any active loads at the moment',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.push('/driver/loads');
              },
              child: const Text('View Available Loads'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LoadInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _HOSSummaryCard extends StatelessWidget {
  final dynamic hos;

  const _HOSSummaryCard({required this.hos});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HOSBar(
              label: 'Drive',
              current: hos.driveTime,
              max: hos.maxDriveTime,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _HOSBar(
              label: 'Shift',
              current: hos.onDutyTime,
              max: hos.maxShiftTime,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _HOSBar(
              label: 'Cycle',
              current: hos.cycleTime,
              max: hos.maxCycleTime,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.push('/driver/hos');
              },
              child: const Text('View Full HOS'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HOSBar extends StatelessWidget {
  final String label;
  final double current;
  final double max;
  final Color color;

  const _HOSBar({
    required this.label,
    required this.current,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (current / max).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${current.toStringAsFixed(1)} / ${max.toStringAsFixed(0)} hrs'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList();
  @override
  Widget build(BuildContext context) {
    // TODO: Replace with real data from provider
    final activities = [
      _Activity('Load accepted', '2 hours ago', Icons.check_circle, Colors.green),
      _Activity('Arrived at pickup', '4 hours ago', Icons.location_on, Colors.blue),
      _Activity('Started driving', '5 hours ago', Icons.drive_eta, Colors.orange),
    ];

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: activity.color.withValues(alpha: 0.2),
              child: Icon(activity.icon, color: activity.color, size: 20),
            ),
            title: Text(activity.title),
            subtitle: Text(activity.time),
          );
        },
      ),
    );
  }
}

class _Activity {
  final String title;
  final String time;
  final IconData icon;
  final Color color;

  _Activity(this.title, this.time, this.icon, this.color);
}
