import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/config/app_config.dart';
import '../../../common/widgets/role_badge.dart';
import '../../../common/widgets/upgrade_card.dart';
import '../../../services/supabase_safe.dart';

class BrokerHome extends ConsumerWidget {
  final bool isPremium;
  const BrokerHome({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freight Broker Dashboard'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: RoleBadge()),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final cfg = ref.read(appConfigProvider);
              final isConfigured =
                  cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
              if (isConfigured) {
                try {
                  final c = SupabaseSafe.clientOrNull;
                  if (c != null) {
                    await c.auth.signOut();
                  }
                } catch (_) {}
              }
              if (context.mounted) {
                context.go('/auth/login');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.store),
            label: const Text('Truck Stops'),
            onPressed: () => context.push('/truck-stops'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: const Text('📂 Route Planning (Premium)'),
            onPressed: () => context.push('/route-planning'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder),
            label: const Text('Documents'),
            onPressed: () => context.push('/documents'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.public),
            label: const Text('View GPS Map'),
            onPressed: () => context.push('/gps'),
          ),
          const SizedBox(height: 16),
          if (isPremium)
            const Card(
              child: ListTile(
                title: Text('Expense Tracker'),
                subtitle: Text('Premium feature active.'),
              ),
            )
          else
            UpgradeCard(
              title: 'Expense Tracker (Premium)',
              onUpgrade: () {
                if (!context.mounted) return;
                context.push('/pricing');
              },
            ),
        ],
      ),
    );
  }
}
