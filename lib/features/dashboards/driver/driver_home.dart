import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../common/config/app_config.dart';
import '../../../common/widgets/auto_alerts_banner.dart';
import '../../../common/widgets/nearby_featured_banner.dart';
import '../../../common/widgets/role_badge.dart';
import '../../../common/widgets/truck_stop_deals_banner.dart';
import '../../../common/widgets/upgrade_card.dart';
import '../../../services/supabase_safe.dart';

class DriverHome extends ConsumerWidget {
  final bool isPremium;
  const DriverHome({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
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
                } catch (_) {
                  // Ignore sign-out errors; still navigate to login
                }
              }
              if (context.mounted) {
                context.go('/auth/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Simple refresh: re-enter the page route
          if (!context.mounted) {
            return;
          }
          context.go('/home');
        },
        child: Builder(
          builder: (context) {
            final cfg = ref.watch(appConfigProvider);
            final supaReady =
                cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Compact map preview tile -> GPS
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.map),
                    title: const Text('Map Preview'),
                    subtitle: const Text('Open real-time GPS map'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/gps'),
                  ),
                ),
                const SizedBox(height: 12),

                // Choose Stop for Alerts (lets driver jump to truck stops to pick/focus)
                ElevatedButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Choose Stop for Alerts'),
                  onPressed: () => context.push('/truck-stops'),
                ),
                const SizedBox(height: 12),

                // Auto Alerts banner (only if Supabase is configured)
                if (supaReady) const AutoAlertsBanner(),
                if (supaReady) const SizedBox(height: 12),

                // What's new section header + nearby featured + deals
                const Text(
                  "What's new near me",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (supaReady) const NearbyFeaturedBanner(),
                if (supaReady) const SizedBox(height: 12),
                if (supaReady) const TruckStopDealsBanner(),
                if (supaReady) const SizedBox(height: 12),

                // Quick navigation buttons
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

                // Premium gate example
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
            );
          },
        ),
      ),
    );
  }
}
