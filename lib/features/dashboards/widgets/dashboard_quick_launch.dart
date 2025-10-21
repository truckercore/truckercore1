import 'package:flutter/material.dart';

import '../../../core/dashboards/dashboard_window_manager.dart';
import '../models/dashboard_metadata.dart';

class DashboardQuickLaunch extends StatelessWidget {
  const DashboardQuickLaunch({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Launch',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Navigate to dashboard marketplace - caller can use context.go('/dashboards')
                    Navigator.of(context).pushNamed('/dashboards');
                  },
                  icon: const Icon(Icons.grid_view, size: 16),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableDashboards.take(4).map((dashboard) {
                return _QuickLaunchButton(dashboard: dashboard);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLaunchButton extends StatelessWidget {
  final DashboardMetadata dashboard;
  const _QuickLaunchButton({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: ElevatedButton(
        onPressed: () {
          DashboardWindowManager().openDashboard(dashboard.id);
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: dashboard.color.withValues(alpha: 0.1),
          foregroundColor: dashboard.color,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(dashboard.icon, size: 32),
            const SizedBox(height: 8),
            Text(
              dashboard.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
