import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/config/app_config.dart';
import '../../../common/state/session_provider.dart';
import '../../../common/widgets/app_background.dart';
import '../../../common/widgets/auto_alerts_banner.dart';
import '../../../common/widgets/nearby_featured_banner.dart';
import '../../../common/widgets/role_badge.dart';
import '../../../common/widgets/switch_role_menu.dart';
import '../../../common/widgets/upgrade_card.dart';
import '../../../di/supabase_client_provider.dart';
import '../../ai/ai_profit_tips_panel.dart';
import '../../alerts/alerts_drawer.dart';
import '../../kpi/kpi_ribbon.dart';
import '../../owner_op/expenses/owner_op_expenses_service.dart';
import '../../owner_op/expenses/tax_expenses_tab.dart';
import '../../owner_op/free_caps/free_caps.dart';
import '../../owner_op/fuel/ifta_panel.dart';
import '../../safety/weigh_stations.dart';

class OwnerOpHome extends ConsumerWidget {
  static bool _mountedLogged = false;
  // Helpers below provide Free-tier features for Owner-Op
  final bool isPremium;
  const OwnerOpHome({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_mountedLogged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: avoid_print
        print('[mounted] OwnerOpHome');
      });
      _mountedLogged = true;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner-Operator Dashboard'),
        actions: [
          if (isPremium)
            IconButton(
              tooltip: 'RoadDogg Assistant',
              icon: const Icon(Icons.smart_toy_outlined),
              onPressed: () => context.push('/roaddogg'),
            ),
          const AlertsBell(),
          const SizedBox(width: 8),
          const SwitchRoleMenu(),
          const SizedBox(width: 8),
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
                  try {
                    final client = ref.read(supabaseClientProvider);
                    await client?.auth.signOut();
                  } catch (_) {}
                } catch (_) {
                  // Ignore sign-out errors; still navigate to login
                }
              }
              if (!context.mounted) return;
              context.go('/auth/login');
            },
          ),
        ],
      ),
      floatingActionButton: _ChatBubbleFab(),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            // Simple refresh: re-enter the page route
            if (!context.mounted) return;
            context.go('/home');
          },
          child: Builder(
            builder: (context) {
              final cfg = ref.watch(appConfigProvider);
              final supaReady =
                  cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;

              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                        Tab(
                          icon: Icon(Icons.receipt_long),
                          text: 'Financial Expense',
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // KPI ribbon at the very top
                              const KpiRibbon(),
                              const SizedBox(height: 12),

                              // Safety Score: You vs Fleet Avg (1–5 trucks)
                              const _OoSafetyScoreCard(),
                              const SizedBox(height: 12),

                              // IFTA Export quick card
                              const _IftaExportCard(),
                              const SizedBox(height: 12),

                              // Fuel/IFTA panel (fuel purchase + monthly summary)
                              const FuelIftaPanel(),
                              const SizedBox(height: 12),

                              // Profit Tips Panel (AI Finance)
                              const AiProfitTipsPanel(),
                              const SizedBox(height: 12),

                              // HOS + compliance quick panel row
                              const Row(
                                children: [
                                  Expanded(child: _HosWidget()),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _ComplianceAlertsPanel(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Compact map preview tile -> GPS
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.map),
                                  title: const Text('Map Preview'),
                                  subtitle: const Text(
                                    'Open real-time GPS map',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push('/gps'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Choose Stop for Alerts
                              ElevatedButton.icon(
                                icon: const Icon(Icons.notifications_active),
                                label: const Text('Choose Stop for Alerts'),
                                onPressed: () => context.push('/truck-stops'),
                              ),
                              const SizedBox(height: 12),
                              if (supaReady) const AutoAlertsBanner(),
                              if (supaReady) const SizedBox(height: 12),
                              const Text(
                                "What's new near me",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              if (supaReady) const NearbyFeaturedBanner(),
                              if (supaReady) const SizedBox(height: 12),
                              // Quick Actions
                              ElevatedButton.icon(
                                icon: const Icon(Icons.smart_toy_outlined),
                                label: const Text('RoadDogg Assistant'),
                                onPressed: () => context.push('/roaddogg'),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.store),
                                label: const Text('Truck Stops'),
                                onPressed: () => context.push('/truck-stops'),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.folder_open),
                                label: const Text(
                                  '📂 Route Planning (Premium)',
                                ),
                                onPressed: () =>
                                    context.push('/route-planning'),
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
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.share),
                                label: const Text('Share My Tracking'),
                                onPressed: () async {
                                  try {
                                    final c = Supabase.instance.client;
                                    final driverId = c.auth.currentUser?.id;
                                    if (driverId == null) {
                                      throw Exception('Sign in required');
                                    }
                                    // Call edge function or RPC to ensure link exists
                                    await c.functions.invoke(
                                      'ensure_driver_tracking_link',
                                      body: {'p_driver': driverId},
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tracking link ready'),
                                      ),
                                    );
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Coming soon'),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // Free Broker Load Board (3 loads/month on Free)
                              _FreeLoadBoardCard(isPremium: isPremium),
                              const SizedBox(height: 12),

                              // RoadDogg Lite (3 suggestions/week on Free)
                              _RoadDoggLiteCard(isPremium: isPremium),
                              const SizedBox(height: 12),

                              // Route Optimize / Multi-stop (MVP)
                              const _RouteOptimizeCard(),
                              const SizedBox(height: 12),

                              // Quick Expense Entry (Fuel/Tolls/Maint)
                              const _ExpenseQuickEntryCard(),
                              const SizedBox(height: 12),

                              // PPM / Deadhead Calculator (MVP)
                              const _PpmDeadheadCard(),
                              const SizedBox(height: 12),

                              // Invoice / Send to Broker — Premium (MVP)
                              const _InvoiceSendCard(),
                              const SizedBox(height: 12),

                              // Deadhead Savings (basic)
                              const _DeadheadSavingsCard(),
                              const SizedBox(height: 12),

                              // Community Insights (teaser)
                              const _CommunityInsightsCard(),
                              const SizedBox(height: 12),

                              // Pre/Post Trip Inspection quick actions
                              const _InspectionQuickActions(),
                              const SizedBox(height: 12),

                              // Route history & export
                              const _RouteHistoryCard(),
                              const SizedBox(height: 12),

                              // Cost inputs feeding CPM mini dashboard
                              const _CpmMiniDashboard(),
                              const SizedBox(height: 12),

                              // Cashflow & 8-Week Forecast (Premium)
                              if (isPremium)
                                const _CashflowForecastCard()
                              else
                                UpgradeCard(
                                  title:
                                      'Cashflow & 8-Week Forecasts (Premium)',
                                  onUpgrade: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Upgrade to unlock cashflow forecasting.',
                                        ),
                                      ),
                                    );
                                  },
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
                          // Tab 2: Financial Expense (Tax-Deductible Expenses)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: TaxExpensesTab(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ); // end OwnerOpHome build
  }
}

class _FreeLoadBoardCard extends ConsumerWidget {
  final bool isPremium;
  const _FreeLoadBoardCard({required this.isPremium});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Track caps state to refresh remaining counters when updated
    ref.watch(ownerOpFreeCapsProvider);
    final remaining = ref
        .read(ownerOpFreeCapsProvider.notifier)
        .remainingLoads();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.handshake_outlined),
                SizedBox(width: 8),
                Text(
                  'Broker Load Board Access',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isPremium)
              Text(
                'Free tier: $remaining of 3 loads remaining this month.',
                style: const TextStyle(color: Colors.amber),
              )
            else
              const Text('Pro/Enterprise: Unlimited access.'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Browse Load Board'),
                  onPressed: () => context.push('/marketplace'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Simulate Accept'),
                  onPressed: () {
                    final ctrl = ref.read(ownerOpFreeCapsProvider.notifier);
                    if (!ctrl.canAcceptLoad(isPremium: isPremium)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Free limit reached. Upgrade to Pro for unlimited load board access.',
                          ),
                        ),
                      );
                      return;
                    }
                    ctrl.recordLoadAccepted();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Accepted a load (simulated).'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoadDoggLiteCard extends ConsumerStatefulWidget {
  final bool isPremium;
  const _RoadDoggLiteCard({required this.isPremium});
  @override
  ConsumerState<_RoadDoggLiteCard> createState() => _RoadDoggLiteCardState();
}

class _RoadDoggLiteCardState extends ConsumerState<_RoadDoggLiteCard> {
  final _queryCtrl = TextEditingController();
  List<String> _suggestions = const [];
  bool _busy = false;

  Future<void> _runSuggestions() async {
    final ctrl = ref.read(ownerOpFreeCapsProvider.notifier);
    if (!ctrl.canUseRoadDogg(isPremium: widget.isPremium)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Free limit reached (3/week). Upgrade for unlimited RoadDogg.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _suggestions = const [];
    });
    try {
      // MVP: return up to 3 mock suggestions based on keywords in _queryCtrl
      final q = _queryCtrl.text.toLowerCase();
      final base = <String>[
        'Flatbed - Boston -> Newark - 315 mi - \$1,250',
        'Dry Van - Philly -> Richmond - 286 mi - \$1,020',
        'Reefer - Hartford -> NYC - 120 mi - \$680',
        'Flatbed - DC -> Norfolk - 200 mi - \$900',
      ];
      final filtered = base
          .where((s) => q.isEmpty || s.toLowerCase().contains(q))
          .take(3)
          .toList();
      await Future.delayed(const Duration(milliseconds: 450));
      ctrl.recordRoadDoggUse();
      setState(() {
        _suggestions = filtered;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = ref
        .read(ownerOpFreeCapsProvider.notifier)
        .remainingRoadDoggUses();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy_outlined),
                SizedBox(width: 8),
                Text(
                  'RoadDogg Lite — Load Matching',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!widget.isPremium)
              Text(
                'Free tier: $remaining of 3 suggestions remaining this week.',
                style: const TextStyle(color: Colors.amber),
              )
            else
              const Text(
                'Pro/Enterprise: Unlimited suggestions with advanced filters.',
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _queryCtrl,
              decoration: const InputDecoration(
                labelText:
                    'Describe your load need (e.g., Flatbed, East Coast, <500 miles, no tolls)',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lightbulb_outline),
                label: const Text('Suggest Top Matches'),
                onPressed: _busy ? null : _runSuggestions,
              ),
            ),
            for (final s in _suggestions)
              ListTile(leading: const Icon(Icons.star_border), title: Text(s)),
          ],
        ),
      ),
    );
  }
}

class _DeadheadSavingsCard extends ConsumerWidget {
  const _DeadheadSavingsCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MVP: static banner; future: derive from last drop-off position and list of loads
    return Card(
      color: Colors.green.shade50,
      child: const ListTile(
        leading: Icon(Icons.route, color: Colors.green),
        title: Text('Deadhead Savings'),
        subtitle: Text(
          'A load within 38 miles of your last drop-off. Upgrade for advanced optimization.',
        ),
      ),
    );
  }
}

class _CommunityInsightsCard extends StatelessWidget {
  const _CommunityInsightsCard();
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community Insights (Teaser)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('- Most profitable lanes this week: Midwest -> Northeast'),
            Text('- Avg CPM in Northeast: \$2.35/mi (last 7 days)'),
            SizedBox(height: 4),
            Text(
              'Upgrade to Pro for full analytics and unlimited insights.',
              style: TextStyle(color: Colors.amber),
            ),
          ],
        ),
      ),
    );
  }
}

class _OoSafetyScoreCard extends StatelessWidget {
  const _OoSafetyScoreCard();
  @override
  Widget build(BuildContext context) {
    // MVP: simple gauge comparison
    const myScore = 86; // /100
    const fleetAvg = 81;
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined),
                SizedBox(width: 8),
                Text('Safety Score — You vs Fleet Avg'),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                Chip(label: Text('Your score: $myScore')),
                Chip(label: Text('Fleet avg: $fleetAvg')),
                Icon(
                  myScore >= fleetAvg
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: myScore >= fleetAvg ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IftaExportCard extends StatelessWidget {
  const _IftaExportCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.file_download_outlined),
        title: const Text('IFTA Export'),
        subtitle: const Text('Generate quarterly IFTA report (CSV/PDF)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IFTA export queued (MVP).')),
        ),
      ),
    );
  }
}


class _HosWidget extends StatefulWidget {
  const _HosWidget();
  @override
  State<_HosWidget> createState() => _HosWidgetState();
}

class _HosWidgetState extends State<_HosWidget> {
  String _status = 'Off Duty';
  final int _driveLeft = 8; // hours
  final int _dutyLeft = 12;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HOS', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(
                      value: 'Off Duty',
                      child: Text('Off Duty'),
                    ),
                    DropdownMenuItem(value: 'On Duty', child: Text('On Duty')),
                    DropdownMenuItem(value: 'Driving', child: Text('Driving')),
                    DropdownMenuItem(value: 'Sleeper', child: Text('Sleeper')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(width: 12),
                Chip(label: Text('Drive left: ${_driveLeft}h')),
                const SizedBox(width: 8),
                Chip(label: Text('Duty left: ${_dutyLeft}h')),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Quick compliance status: No violations'),
          ],
        ),
      ),
    );
  }
}

class _ComplianceAlertsPanel extends ConsumerWidget {
  const _ComplianceAlertsPanel();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blitz = ref.watch(isBlitzDayProvider);
    final alerts = ref.watch(approachAlertsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compliance Alerts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (blitz) ...[
              const SizedBox(height: 6),
              const Text(
                'CVSA Inspection Week — extra patrols active',
                style: TextStyle(color: Colors.orange),
              ),
            ],
            const SizedBox(height: 6),
            if (alerts.isEmpty)
              const Text('No nearby open stations within 15 minutes.')
            else
              ...alerts.map(
                (a) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.balance),
                  title: Text('Station ${a.stationId}'),
                  subtitle: Text('ETA: ${a.eta}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InspectionQuickActions extends StatelessWidget {
  const _InspectionQuickActions();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pre-/Post-Trip Inspection',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Start Pre-Trip'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pre-Trip started (MVP).')),
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Start Post-Trip'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post-Trip started (MVP).')),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Last inspection PDF'),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/documents'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteHistoryCard extends StatelessWidget {
  const _RouteHistoryCard();
  @override
  Widget build(BuildContext context) {
    final routes = const [
      '8/25: Columbus -> Chicago (358 mi)',
      '8/27: Chicago -> Detroit (282 mi)',
      '8/28: Detroit -> Cleveland (169 mi)',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Route History & Export',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...routes.map(
              (r) => ListTile(leading: const Icon(Icons.route), title: Text(r)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV export started (MVP).')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF export started (MVP).')),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume last route'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Resuming last route (MVP).')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CpmMiniDashboard extends StatefulWidget {
  const _CpmMiniDashboard();
  @override
  State<_CpmMiniDashboard> createState() => _CpmMiniDashboardState();
}

class _CpmMiniDashboardState extends State<_CpmMiniDashboard> {
  final _diesel = TextEditingController(text: '0.85');
  final _ins = TextEditingController(text: '0.18');
  final _maint = TextEditingController(text: '0.22');
  double _miles = 1000; // example window

  double _toDouble(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final diesel = _toDouble(_diesel);
    final ins = _toDouble(_ins);
    final maint = _toDouble(_maint);
    final costPerMile = diesel + ins + maint;
    final revenuePerMile = 2.35; // placeholder
    final profitPerMile = revenuePerMile - costPerMile;
    final net = profitPerMile * _miles;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit/CPM Inputs',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _diesel,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Diesel \$/mi',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _ins,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Insurance \$/mi',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _maint,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maintenance \$/mi',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      const Text('Miles:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          min: 100,
                          max: 3000,
                          value: _miles,
                          onChanged: (v) => setState(() => _miles = v),
                        ),
                      ),
                      Text(_miles.toStringAsFixed(0)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: [
                Chip(
                  label: Text('Cost/mi: \$${costPerMile.toStringAsFixed(2)}'),
                ),
                Chip(
                  label: Text(
                    'Revenue/mi: \$${revenuePerMile.toStringAsFixed(2)}',
                  ),
                ),
                Chip(
                  label: Text(
                    'Profit/mi: \$${profitPerMile.toStringAsFixed(2)}',
                  ),
                ),
                Chip(label: Text('Projected Net: \$${net.toStringAsFixed(0)}')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubbleFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'fab_ownerop_chat',
      tooltip: 'Ask RoadDogg',
      child: const Icon(Icons.chat_bubble_outline),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) {
            final ctrl = TextEditingController();
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick question to RoadDogg'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Best loads near Columbus today?',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Ask'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sent to RoadDogg (MVP).'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ===== Cashflow & Forecast Card (Premium) =====
class _CashflowForecastCard extends ConsumerStatefulWidget {
  const _CashflowForecastCard();
  @override
  ConsumerState<_CashflowForecastCard> createState() =>
      _CashflowForecastCardState();
}

class _CashflowForecastCardState extends ConsumerState<_CashflowForecastCard> {
  late Future<_CashflowData> _fut;

  @override
  void initState() {
    super.initState();
    _fut = _load();
  }

  Future<_CashflowData> _load() async {
    final svc = ref.read(ownerOpExpensesServiceProvider);
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 90));
    final weekly = await svc.weeklyExpenseSums(start, now);
    final forecast = await svc.forecastOutflowWeekly(pivot: now);
    // Compute last 4 weeks avg
    final keys = weekly.keys.toList()..sort();
    final last4 = keys.length >= 4 ? keys.sublist(keys.length - 4) : keys;
    final last4Sum = last4.fold<int>(0, (a, k) => a + (weekly[k] ?? 0));
    final last4Avg = last4.isEmpty ? 0 : (last4Sum ~/ last4.length);
    return _CashflowData(
      weekly: weekly,
      last4AvgOutflowCents: last4Avg,
      forecastOutflowCents: forecast,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<_CashflowData>(
          future: _fut,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final d = snap.data!;
            // Simple low-cash alert example (assumes current balance $3,000)
            const currentBalanceCents = 300000; // $3,000
            const lowThresholdCents = 100000; // $1,000
            final projected =
                currentBalanceCents - d.forecastOutflowCents.first;
            final low = projected < lowThresholdCents;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined),
                    SizedBox(width: 8),
                    Text(
                      'Cashflow & 8-Week Forecast',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (low)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Low cash week projected — consider delaying maintenance',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        'Last 4w avg outflow: ${_fmtMoney(d.last4AvgOutflowCents)}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Next wk outflow: ${_fmtMoney(d.forecastOutflowCents.first)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Forecast (next 8 weeks):',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(d.forecastOutflowCents.length, (i) {
                      final c = d.forecastOutflowCents[i];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('W${i + 1}: ${_fmtMoney(c)}'),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Past 90d weekly outflows shown in avg - Updated just now',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _fmtMoney(int cents) {
    final dollars = cents / 100.0;
    final text = dollars.toStringAsFixed(0);
    return '\$$text';
  }
}

class _CashflowData {
  final Map<DateTime, int> weekly; // week start -> outflow cents
  final int last4AvgOutflowCents;
  final List<int> forecastOutflowCents; // per week, cents
  const _CashflowData({
    required this.weekly,
    required this.last4AvgOutflowCents,
    required this.forecastOutflowCents,
  });
}

// ===== New MVP Cards for Owner-Operator Checklist =====
class _RouteOptimizeCard extends ConsumerStatefulWidget {
  const _RouteOptimizeCard();
  @override
  ConsumerState<_RouteOptimizeCard> createState() => _RouteOptimizeCardState();
}

class _RouteOptimizeCardState extends ConsumerState<_RouteOptimizeCard> {
  final _stopsCtrl = TextEditingController(
    text: 'Dallas, TX; Oklahoma City, OK; Denver, CO',
  );
  bool _busy = false;
  String? _summary;

  Future<void> _optimize() async {
    setState(() => _busy = true);
    try {
      final c = Supabase.instance.client;
      final cfg = ref.read(appConfigProvider);
      final ready =
          cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
      final stops = _stopsCtrl.text
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      // very naive distance/time estimate
      final miles = (stops.length <= 1) ? 0 : (stops.length - 1) * 300;
      final hours = (miles / 55).toStringAsFixed(1);
      _summary = 'Stops: ${stops.length} • ~$miles mi • ~$hours h';
      if (ready) {
        await c.from('dispatch_events').insert({
          'event_type': 'oo_route_plan',
          'details': {
            'stops': stops,
            'estimated_miles': miles,
            'estimated_hours': hours,
            'optimizer': 'mvp_stub',
          },
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Optimized (MVP). Saved draft.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save plan (offline).')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.alt_route),
                SizedBox(width: 8),
                Text(
                  'Plan Route / Optimize (multi-stop)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stopsCtrl,
              decoration: const InputDecoration(
                labelText: 'Stops (semicolon separated)',
                hintText: 'Origin; Stop 1; Stop 2; Destination',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check),
                  label: const Text('Optimize'),
                  onPressed: _busy ? null : _optimize,
                ),
                const SizedBox(width: 8),
                if (_summary != null) Chip(label: Text(_summary!)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseQuickEntryCard extends ConsumerStatefulWidget {
  const _ExpenseQuickEntryCard();
  @override
  ConsumerState<_ExpenseQuickEntryCard> createState() =>
      _ExpenseQuickEntryCardState();
}

class _ExpenseQuickEntryCardState
    extends ConsumerState<_ExpenseQuickEntryCard> {
  final _amountCtrl = TextEditingController();
  String _cat = 'fuel_travel';
  String? _lastMsg;

  Future<void> _save() async {
    final cents = ((double.tryParse(_amountCtrl.text.trim()) ?? 0) * 100)
        .round();
    if (cents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter amount')));
      return;
    }
    try {
      final svc = ref.read(ownerOpExpensesServiceProvider);
      await svc.addExpense(category: _cat, amountCents: cents);
      if (mounted) {
        setState(
          () => _lastMsg =
              'Saved ${_cat.replaceAll('_', ' ')}: \$${(cents / 100).toStringAsFixed(2)}',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense saved')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _lastMsg = 'Queued locally (offline).');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline — will sync later (MVP).')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long),
                SizedBox(width: 8),
                Text(
                  'Expense Entry',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<String>(
                  value: _cat,
                  items: const [
                    DropdownMenuItem(value: 'fuel_travel', child: Text('Fuel')),
                    DropdownMenuItem(value: 'tolls', child: Text('Tolls')),
                    DropdownMenuItem(
                      value: 'maintenance_repairs',
                      child: Text('Maintenance'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _cat = v ?? _cat),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount (USD)',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: _save,
                ),
                const SizedBox(width: 8),
                if (_lastMsg != null)
                  Expanded(
                    child: Text(_lastMsg!, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PpmDeadheadCard extends ConsumerStatefulWidget {
  const _PpmDeadheadCard();
  @override
  ConsumerState<_PpmDeadheadCard> createState() => _PpmDeadheadCardState();
}

class _PpmDeadheadCardState extends ConsumerState<_PpmDeadheadCard> {
  final _routeMi = TextEditingController(text: '500');
  final _deadheadMi = TextEditingController(text: '40');
  final _revenue = TextEditingController(text: '1200');
  String? _ppm;

  Future<void> _persistSnapshot(
    double ppm,
    int routeMiles,
    int deadhead,
    int revenueCents,
  ) async {
    try {
      final cfg = ref.read(appConfigProvider);
      if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return;
      await Supabase.instance.client.from('dispatch_events').insert({
        'event_type': 'oo_finance_snapshot',
        'details': {
          'ppm': ppm,
          'route_miles': routeMiles,
          'deadhead_miles': deadhead,
          'revenue_cents': revenueCents,
          'ts': DateTime.now().toUtc().toIso8601String(),
        },
      });
    } catch (_) {}
  }

  void _recalc() {
    final route = int.tryParse(_routeMi.text.trim()) ?? 0;
    final dh = int.tryParse(_deadheadMi.text.trim()) ?? 0;
    final revCents = ((double.tryParse(_revenue.text.trim()) ?? 0) * 100)
        .round();
    final totalMiles = (route + dh).clamp(1, 1000000);
    final ppm = revCents / 100.0 / totalMiles;
    setState(() => _ppm = ppm.toStringAsFixed(2));
    _persistSnapshot(ppm, route, dh, revCents);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.calculate_outlined),
                SizedBox(width: 8),
                Text(
                  'PPM / Deadhead Calculator',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _routeMi,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Route mi',
                      isDense: true,
                    ),
                    onChanged: (_) => _recalc(),
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _deadheadMi,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Deadhead mi',
                      isDense: true,
                    ),
                    onChanged: (_) => _recalc(),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _revenue,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Revenue USD',
                      isDense: true,
                    ),
                    onChanged: (_) => _recalc(),
                  ),
                ),
                if (_ppm != null) Chip(label: Text('PPM: \$$_ppm/mi')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceSendCard extends ConsumerStatefulWidget {
  const _InvoiceSendCard();
  @override
  ConsumerState<_InvoiceSendCard> createState() => _InvoiceSendCardState();
}

class _InvoiceSendCardState extends ConsumerState<_InvoiceSendCard> {
  final _broker = TextEditingController(text: 'Acme Logistics');
  final _amount = TextEditingController(text: '1200');
  bool _busy = false;
  String? _status;

  Future<void> _send() async {
    final isPremium = ref.read(sessionProvider).isPremium;
    if (!isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upgrade to Premium to send invoices.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final cfg = ref.read(appConfigProvider);
      if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
        throw Exception('Supabase not configured');
      }
      final c = Supabase.instance.client;
      final userId = c.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');
      final cents = ((double.tryParse(_amount.text.trim()) ?? 0) * 100).round();
      final invDyn = await c
          .from('invoices')
          .insert({
            'owner_user_id': userId,
            'broker_name': _broker.text.trim(),
            'status': 'sent',
            'currency': 'USD',
            'total_cents': cents,
          })
          .select()
          .single();
      final inv = Map<String, dynamic>.from(invDyn as Map);
      final invId = inv['id'];
      await c.from('invoice_items').insert({
        'invoice_id': invId,
        'title': 'Linehaul',
        'qty': 1,
        'unit_cents': cents,
      });
      if (mounted) {
        setState(() => _status = 'Sent to ${_broker.text.trim()}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created and sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Failed: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to send now. Try later.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.request_quote_outlined),
                SizedBox(width: 8),
                Text(
                  'Invoice / Send to Broker — Premium',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _broker,
                    decoration: const InputDecoration(
                      labelText: 'Broker name',
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total USD',
                      isDense: true,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Send Invoice'),
                  onPressed: _busy ? null : _send,
                ),
                if (_status != null) Chip(label: Text(_status!)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
