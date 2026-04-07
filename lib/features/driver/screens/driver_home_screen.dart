import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/driver_safety_service.dart';
import '../services/hos_service.dart';
import '../widgets/active_route_card.dart';
import '../widgets/hos_status_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/safety_score_card.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosStatus = ref.watch(currentHOSStatusProvider);
    final safetyScore = ref.watch(drivingSafetyScoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency),
            onPressed: () => _showEmergencyDialog(context),
            tooltip: 'Emergency',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentHOSStatusProvider);
          ref.invalidate(drivingSafetyScoreProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // HOS Status Card
            hosStatus.when(
              data: (status) => HOSStatusCard(status: status),
              loading: () => const _LoadingCard(),
              error: (e, s) => const _ErrorCard(message: 'Failed to load HOS status'),
            ),
            const SizedBox(height: 16),

            // Active Route Card
            const ActiveRouteCard(),
            const SizedBox(height: 16),

            // Safety Score Card
            safetyScore.when(
              data: (score) => SafetyScoreCard(score: score),
              loading: () => const _LoadingCard(),
              error: (e, s) => const _ErrorCard(message: 'Failed to load safety score'),
            ),
            const SizedBox(height: 16),

            // Quick Actions
            const QuickActionsGrid(),
            const SizedBox(height: 16),

            // Recent Messages
            _buildRecentMessages(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/navigation'),
        icon: const Icon(Icons.navigation),
        label: const Text('Navigate'),
      ),
    );
  }

  Widget _buildRecentMessages(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Messages',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/messages'),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Message list would go here
          const ListTile(
            leading: Icon(Icons.message),
            title: Text('No new messages'),
            subtitle: Text('All caught up!'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Assistance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text('Call 911'),
              onTap: () {
                // Implement call to 911
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text('Medical Emergency'),
              onTap: () => Navigator.pushNamed(context, '/emergency/medical'),
            ),
            ListTile(
              leading: const Icon(Icons.car_crash),
              title: const Text('Accident Report'),
              onTap: () => Navigator.pushNamed(context, '/emergency/accident'),
            ),
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Breakdown Assistance'),
              onTap: () => Navigator.pushNamed(context, '/emergency/breakdown'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
