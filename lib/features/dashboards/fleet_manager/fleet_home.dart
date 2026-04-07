import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:truckercore1/core/logging/app_logger.dart' as app_log;

import '../../../common/config/app_config.dart';
import '../../../common/models/app_role.dart';
import '../../../common/services/loads_service.dart';
import '../../../common/state/feature_flags.dart';
import '../../../common/state/phase2_flags.dart';
import '../../../common/state/session_provider.dart';
import '../../../common/widgets/app_background.dart';
import '../../../common/widgets/role_badge.dart';
import '../../../common/widgets/switch_role_menu.dart';
import '../../../common/widgets/upgrade_card.dart';
import '../../../core/net/supa_retry.dart';
import '../../../services/supa_client.dart';
import '../../../services/supabase_safe.dart';
import '../../ai/route_prediction_panel.dart';
import '../../alerts/alerts_drawer.dart';
import '../../fleet/analytics/ops_profit_detention_screen.dart';
import '../../fleet/widgets/outbox_health_card.dart';
import '../../fuel/fuel_anomaly_panel.dart';
import '../../geofencing/geofence_panel.dart';
import '../../maintenance/maintenance_cost_panel.dart';
import '../../matching/load_matching_panel.dart';
import '../../pricing/market_rates_service.dart';
import '../../profitability/profit_panel.dart';
import '../../safety/safety_panel.dart';
import '../../terminals/terminal_filter_bar.dart';
import '../../vetting/vetting_service.dart';
import '../services/kpi_order_service.dart';
import '../services/kpi_service.dart';
import '../services/live_alerts_provider.dart';
import '_kpis_refresh_strip.dart';
import 'widgets/driver_telemetry_card.dart';

class FleetHome extends ConsumerWidget {
  static bool _mountedLogged = false;
  final bool isPremium;
  const FleetHome({super.key, required this.isPremium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_mountedLogged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        app_log.AppLogger.info('[mounted] FleetHome');
      });
      _mountedLogged = true;
    }
    return Scaffold(
      // 1) Top Navigation Bar (Persistent)
      appBar: AppBar(
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(160),
          child: _HeaderKpiStrip(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            // TruckerCore logo (use text placeholder or your Image.asset)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'TruckerCore',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Navigation dropdown (placeholder)
            PopupMenuButton<String>(
              tooltip: 'Navigation',
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'overview', child: Text('Overview')),
                const PopupMenuItem(value: 'loads', child: Text('Loads')),
                const PopupMenuItem(value: 'drivers', child: Text('Drivers')),
                const PopupMenuItem(
                  value: 'maintenance',
                  child: Text('Maintenance'),
                ),
                const PopupMenuItem(
                  value: 'finance',
                  child: Text('Financials'),
                ),
                const PopupMenuItem(
                  value: 'compliance',
                  child: Text('Compliance'),
                ),
                const PopupMenuItem(
                  value: 'route_planning',
                  child: Text('📂 Route Planning (Premium)'),
                ),
                const PopupMenuItem(value: 'team', child: Text('Team Comms')),
              ],
              onSelected: (v) {
                if (v == 'route_planning') {
                  GoRouter.of(context).push('/route-planning');
                  return;
                }
                // For now we stay on same screen; could scroll to sections if using ScrollController/Keys.
              },
              child: const Row(
                children: [
                  Icon(Icons.menu),
                  SizedBox(width: 6),
                  Text('Menu'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Verify Carrier',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => const _VettingSheetFM(),
              );
            },
          ),
          const SwitchRoleMenu(),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: RoleBadge()),
          ),
          if (isPremium)
            IconButton(
              tooltip: 'RoadDogg Assistant',
              icon: const Icon(Icons.smart_toy_outlined),
              onPressed: () => context.push('/roaddogg'),
            ),
          const AlertsBell(),
          IconButton(
            tooltip: 'App Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon')),
              );
            },
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final cfg = ref.read(appConfigProvider);
              final configured =
                  cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty;
              if (configured) {
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

      // 2) Main Dashboard Sections (desktop-friendly with scrollable cards)
      body: AppBackground(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeftNav(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // (Plan overview removed from dashboard to keep UI clean per new onboarding flow)
                        // Quick Actions row
                        _QuickActionsRow(isPremium: isPremium),

                        const SizedBox(height: 12),
                        // Terminal filter (All terminals by default)
                        const TerminalFilterBar(),

                        const SizedBox(height: 16),
                        // A) Fleet Overview (Free)
                        const _SectionCard(
                          title: 'Fleet Overview',
                          subtitle: 'Realtime metrics and alerts',
                          child: _OverviewGrid(),
                        ),

                        // Driver Telemetry (MVP)
                        Builder(
                          builder: (context) {
                            final userId = SupabaseSafe.clientOrNull?.auth.currentUser?.id;
                            if (userId == null) return const SizedBox.shrink();
                            return _SectionCard(
                              title: 'Driver Telemetry',
                              subtitle: 'Speeding • Idle • Harsh events',
                              child: DriverTelemetryCard(driverUserId: userId),
                            );
                          },
                        ),

                        _SectionCard(
                          title: 'Marketplace Offers',
                          subtitle: 'Manage offers on your posted loads',
                          child: ListTile(
                            leading: const Icon(Icons.handshake_outlined),
                            title: const Text('Open Manage Offers'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/fleet/manage-offers'),
                          ),
                        ),

                        // Exceptions & Alerts Lane
                        const _SectionCard(
                          title: 'Exceptions & Alerts',
                          subtitle:
                              'One place for problems — acknowledge, assign, snooze',
                          child: _ExceptionsLane(),
                        ),

                        // AI Route Prediction (Premium)
                        _SectionCard(
                          title: 'AI Route Prediction & Delay Forecasting',
                          subtitle:
                              'Predict late deliveries; suggest reroutes in real time (Premium)',
                          child: isPremium
                              ? const RoutePredictionPanel()
                              : UpgradeCard(
                                  title: 'Unlock AI delay forecasts (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // B) Live GPS Tracker (Free) - placeholder map and legend
                        _SectionCard(
                          title: 'Live GPS Tracker',
                          subtitle: 'World map with truck pins and routes',
                          child: _GpsTrackerWithFocus(
                            onOpenMap: () => context.push('/gps'),
                          ),
                        ),

                        const _SectionCard(
                          title: 'Rate Insights',
                          subtitle:
                              'Market spot/contract benchmarks (90d) — Pro+',
                          child: _RateInsightsFmPanel(),
                        ),

                        _SectionCard(
                          title: 'Geofencing & Yard Management',
                          subtitle:
                              'Entries/exits, dwell time, and dock assignment (Premium)',
                          child: isPremium
                              ? const GeofencePanel()
                              : UpgradeCard(
                                  title:
                                      'Unlock Geofencing & Yard Management (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // C) Load & Dispatch (Free + Premium)
                        _SectionCard(
                          title: 'Load & Dispatch Management',
                          subtitle:
                              'View/assign loads • Drag-and-drop dispatch (Premium)',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Create / Import actions
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add_box_outlined),
                                    label: const Text('Create Load'),
                                    onPressed: () =>
                                        _createLoadDialog(context, ref),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.file_upload_outlined,
                                    ),
                                    label: const Text('Import CSV (MVP)'),
                                    onPressed: () =>
                                        _importCsvDialog(context, ref),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _LoadsListPlaceholder(),
                              const SizedBox(height: 12),
                              // Smart Load Matching (Premium)
                              if (isPremium) ...[
                                const _PremiumBadgeRow(
                                  text: 'Smart Load Matching Suggestions',
                                ),
                                const SizedBox(height: 8),
                                // Insert the panel
                                const LoadMatchingPanel(),
                                const SizedBox(height: 12),
                                const _PremiumBadgeRow(
                                  text:
                                      'Premium tools enabled: Drag-and-drop dispatch, Load board, Smart routing',
                                ),
                              ] else
                                UpgradeCard(
                                  title:
                                      'Unlock dispatch automation & route optimization (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // D) Driver Management (Free)
                        _SectionCard(
                          title: 'Driver Management',
                          subtitle: 'Statuses, HOS, and communication',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DriversListPlaceholder(), // keep your basic list for now
                              const SizedBox(height: 12),
                              // Safety & Behavior Scoring (Premium)
                              isPremium
                                  ? const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _PremiumBadgeRow(
                                          text:
                                              'Driver Safety & Behavior Scoring',
                                        ),
                                        SizedBox(height: 8),
                                        SafetyPanel(),
                                      ],
                                    )
                                  : UpgradeCard(
                                      title:
                                          'Unlock Driver Safety Scoring (Premium)',
                                      onUpgrade: () =>
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Upgrade flow coming soon',
                                              ),
                                            ),
                                          ),
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // E) Maintenance & Safety (Premium)
                        _SectionCard(
                          title: 'Maintenance & Safety',
                          subtitle: 'Scheduler, DVIRs, breakdowns, DTC alerts',
                          child: isPremium
                              ? const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _PremiumBadgeRow(
                                      text: 'Maintenance Cost Analyzer',
                                    ),
                                    SizedBox(height: 8),
                                    MaintenanceCostPanel(),
                                  ],
                                )
                              : UpgradeCard(
                                  title:
                                      'Enable fleet maintenance scheduler (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                        ),
                        // NEW: Engine Diagnostics & ELD section (Premium)
                        _SectionCard(
                          title: 'Engine Diagnostics & ELD',
                          subtitle:
                              'Active DTCs, driver behavior, HOS & ELD logs (Premium)',
                          child: isPremium
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _DiagnosticsAndEldPlaceholder(),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.link_outlined),
                                        label: const Text('Connect ELD'),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Connect ELD Provider'),
                                              content: const _EldPartnersListDialog(),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text('Close'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : UpgradeCard(
                                  title:
                                      'Unlock Diagnostics & ELD integrations (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                        ),

                        _SectionCard(
                          title: 'Fuel Theft & Waste Detection',
                          subtitle:
                              'GPS + fuel sensor tracking to detect siphoning and waste (Premium)',
                          child: isPremium
                              ? const FuelAnomalyPanel()
                              : UpgradeCard(
                                  title:
                                      'Unlock Fuel Theft & Waste Detection (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // F) Financial Insights (Premium)
                        _SectionCard(
                          title: 'Financial Insights',
                          subtitle: 'Expenses, fuel, mileage & profitability',
                          child: isPremium
                              ? const ProfitPanel()
                              : UpgradeCard(
                                  title:
                                      'Unlock fuel & financial reports (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                        ),

                        // G) Compliance & Docs (Free + Premium)
                        _SectionCard(
                          title: 'Compliance & Docs Hub',
                          subtitle: 'HOS/ELD logs, driver docs, audit support',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ComplianceFreePlaceholder(),
                              const SizedBox(height: 12),
                              if (isPremium)
                                const _PremiumBadgeRow(
                                  text:
                                      'Premium: Auto reminders, uploads, DOT inspection records',
                                )
                              else
                                UpgradeCard(
                                  title:
                                      'Enable automated compliance reminders (Premium)',
                                  onUpgrade: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Upgrade flow coming soon',
                                          ),
                                        ),
                                      ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // H) Team Communication (Free)
                        _SectionCard(
                          title: 'Team Communication',
                          subtitle: 'Chat, announcements, load notes, alerts',
                          child: _TeamCommsPlaceholder(),
                        ),

                        // Ads banner for Free tier dispatchers
                        if (!isPremium) const _DispatcherAdsBanner(),
                      ],
                    ),
                  );
                },
              ), // end LayoutBuilder
            ), // end Expanded
          ],
        ),
      ),
    );
  }
}

// ========== Left Navigation & Header KPI Strip ==========

class _LeftNav extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.role != AppRole.fleetManager) {
      return const SizedBox.shrink();
    }
    final flags = ref.watch(featureFlagsProvider);
    final items = <_NavItem>[
      _NavItem(
        'Fleet Map & Status',
        Icons.map_outlined,
        () => context.push('/gps'),
      ),
      _NavItem('Drivers', Icons.badge_outlined, () => context.push('/drivers')),
      _NavItem(
        'Loads & Dispatch',
        Icons.assignment_outlined,
        () => context.push('/loads'),
      ),
      _NavItem(
        'Analytics',
        Icons.insights_outlined,
        () => _comingSoon(context),
      ),
      _NavItem('ROI + Detention', Icons.query_stats_outlined, () {
        final url = const String.fromEnvironment('SUPABASE_URL');
        final key = const String.fromEnvironment('SUPABASE_ANON') != ''
            ? const String.fromEnvironment('SUPABASE_ANON')
            : const String.fromEnvironment('SUPABASE_ANON_KEY');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OpsProfitDetentionScreen(
              client: SupaClient(supabaseUrl: url, anonKey: key),
            ),
          ),
        );
      }),
      if (flags.vehiclesMaintenance)
        _NavItem(
          'Vehicles & Maintenance',
          Icons.build_circle_outlined,
          () => _comingSoon(context),
        ),
      if (flags.compliance)
        _NavItem(
          'Compliance',
          Icons.verified_user_outlined,
          () => context.push('/compliance/inspections'),
        ),
      if (flags.fuelSpend)
        _NavItem(
          'Fuel & Spend',
          Icons.local_gas_station_outlined,
          () => _comingSoon(context),
        ),
      if (flags.helpTraining)
        _NavItem(
          'Help & Training',
          Icons.support_outlined,
          () => context.push('/help'),
        ),
      _NavItem(
        'Settings',
        Icons.settings_outlined,
        () => context.push('/profile'),
      ),
    ];

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (c, i) {
            final it = items[i];
            return ListTile(
              dense: true,
              leading: Icon(it.icon),
              title: Text(it.label),
              onTap: it.onTap,
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: items.length,
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Coming soon')));
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _NavItem(this.label, this.icon, this.onTap);
}

class _HeaderKpiStrip extends ConsumerWidget {
  const _HeaderKpiStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    final kpisAsync = ref.watch(orderedKpisProvider);
    final live = ref.watch(liveAlertsProvider);

    Widget kpiCard(KpiCardData d) {
      final Color badgeColor = d.badgeColor ?? Theme.of(context).cardColor;
      return InkWell(
        onTap: () {
          switch (d.slug) {
            case 'exceptions_now':
              context.push('/exceptions?filter=current');
              break;
            case 'on_time_today':
              context.push('/loads?due=today');
              break;
            case 'assigned_ratio_today':
              context.push('/loads?assigned=unassigned');
              break;
            case 'hos_approaching':
              context.push('/compliance?tab=hos&filter=approaching');
              break;
            case 'deadhead_7d':
              context.push('/analytics?panel=deadhead');
              break;
            case 'vehicles_attention':
              context.push('/vehicles');
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(d.title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            d.slug == 'exceptions_now'
                                ? '${live.exceptionsCount}'
                                : d.value,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (d.trend != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              d.trend == 'down'
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 16,
                              color: d.trend == 'down'
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ],
                          if (d.icon != null) ...[
                            const SizedBox(width: 6),
                            Icon(d.icon, color: Colors.amber, size: 16),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Outbox health summary
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SizedBox(height: 44, child: OutboxHealthCard()),
          ),
          if (live.pollingFallback)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Live updating paused — polling every 30s',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: KpisRefreshStrip(),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: kpisAsync.when(
              data: (list) {
                // Feature fallback replacement: if maintenance disabled, swap vehicles_attention for fuel spend card
                final items = <KpiCardData>[];
                for (final d in list) {
                  if (d.slug == 'vehicles_attention' &&
                      !flags.vehiclesMaintenance) {
                    items.add(
                      const KpiCardData(
                        slug: 'fuel_spend_30d',
                        title: 'Fuel Spend (30d)',
                        value: '0',
                      ),
                    );
                  } else {
                    items.add(d);
                  }
                }
                return Row(children: [for (final d in items) kpiCard(d)]);
              },
              loading: () => const Row(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: SizedBox(
                      width: 160,
                      height: 24,
                      child: _ShimmerBar(),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: SizedBox(
                      width: 160,
                      height: 24,
                      child: _ShimmerBar(),
                    ),
                  ),
                ],
              ),
              error: (e, st) => const Row(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Chip(label: Text('KPIs unavailable')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VettingSheetFM extends ConsumerStatefulWidget {
  const _VettingSheetFM();
  @override
  ConsumerState<_VettingSheetFM> createState() => _VettingSheetFMState();
}

class _VettingSheetFMState extends ConsumerState<_VettingSheetFM> {
  final _dotCtrl = TextEditingController(text: '1234562');
  CarrierVettingCardData? _data;
  bool _busy = false;
  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(vettingServiceProvider);
      final v = await svc.check(dotNumber: _dotCtrl.text.trim());
      setState(() => _data = CarrierVettingCardData.fromV(v));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify Carrier',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dotCtrl,
                  decoration: const InputDecoration(
                    labelText: 'DOT Number',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _run,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Check'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_data != null) _CarrierVettingCard(data: _data!),
        ],
      ),
    );
  }
}

class CarrierVettingCardData {
  final String dot;
  final String? mc;
  final String rating;
  final bool fraud;
  final DateTime? insuranceExp;
  final DateTime last;
  final Color color;
  CarrierVettingCardData({
    required this.dot,
    this.mc,
    required this.rating,
    required this.fraud,
    this.insuranceExp,
    required this.last,
    required this.color,
  });
  factory CarrierVettingCardData.fromV(CarrierVetting v) {
    return CarrierVettingCardData(
      dot: v.dotNumber,
      mc: v.mcNumber,
      rating: v.safetyRating ?? '—',
      fraud: v.fraudFlag,
      insuranceExp: v.insuranceExpiry,
      last: v.lastVerifiedAt,
      color: v.statusColor,
    );
  }
}

class _CarrierVettingCard extends StatelessWidget {
  final CarrierVettingCardData data;
  const _CarrierVettingCard({required this.data});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: data.color.withValues(alpha: 0.15),
      child: ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: Text('DOT ${data.dot}  •  MC ${data.mc ?? '—'}'),
        subtitle: Text(
          'Safety: ${data.rating}  •  Insurance exp: ${data.insuranceExp?.toIso8601String() ?? '—'}\nLast verified: ${data.last.toLocal()}',
        ),
        trailing: data.fraud
            ? const Chip(
                label: Text('FRAUD'),
                backgroundColor: Colors.redAccent,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _RateInsightsFmPanel extends ConsumerStatefulWidget {
  const _RateInsightsFmPanel();
  @override
  ConsumerState<_RateInsightsFmPanel> createState() =>
      _RateInsightsFmPanelState();
}

class _RateInsightsFmPanelState extends ConsumerState<_RateInsightsFmPanel> {
  final _ozip = TextEditingController(text: '30301');
  final _dzip = TextEditingController(text: '75201');
  bool _busy = false;
  double? _spot;
  double? _contract;
  int? _sample;
  @override
  void dispose() {
    _ozip.dispose();
    _dzip.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(marketRatesServiceProvider);
      final s = await svc.getLaneRates(
        originZip: _ozip.text.trim(),
        destZip: _dzip.text.trim(),
      );
      setState(() {
        _spot = s.latestSpot;
        _contract = s.latestContract;
        _sample = s.sampleSize;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 100,
              child: TextField(
                controller: _ozip,
                decoration: const InputDecoration(
                  labelText: 'Origin ZIP',
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _dzip,
                decoration: const InputDecoration(
                  labelText: 'Dest ZIP',
                  isDense: true,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _load,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.trending_up),
              label: const Text('Load'),
            ),
            if (ref.watch(phase2FlagsProvider).mock)
              const Chip(label: Text('Demo data')),
            if (_spot != null)
              Chip(label: Text('Spot: \$${_spot!.toStringAsFixed(2)}/mi')),
            if (_contract != null)
              Chip(
                label: Text('Contract: \$${_contract!.toStringAsFixed(2)}/mi'),
              ),
            if (_sample != null) Chip(label: Text('Sample: $_sample')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Market rates are based on recent transactions and partner data.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
// ========== Widgets & placeholders ==========

class _QuickActionsRow extends StatelessWidget {
  final bool isPremium;
  const _QuickActionsRow({required this.isPremium});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _QuickButton(
          icon: Icons.add_box_outlined,
          label: 'Create Load',
          onTap: () => context.push('/loads'),
        ),
        _QuickButton(
          icon: Icons.local_shipping_outlined,
          label: 'Add Truck',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Truck coming soon')),
          ),
        ),
        _QuickButton(
          icon: Icons.public,
          label: 'Fleet Map',
          onTap: () => context.push('/fleet-map'),
        ),
        _QuickButton(
          icon: Icons.people_outline,
          label: 'Drivers',
          onTap: () => context.push('/drivers'),
        ),
        _QuickButton(
          icon: Icons.edit_road_outlined,
          label: 'Trucks Admin',
          onTap: () => context.push('/trucks-admin'),
        ),
        _QuickButton(
          icon: Icons.assignment_ind_outlined,
          label: 'Assign Driver',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assign Driver coming soon')),
          ),
        ),
        _QuickButton(
          icon: Icons.home_repair_service_outlined,
          label: 'Roadside Assist',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isPremium
                    ? 'Roadside Assist action coming soon'
                    : 'Roadside Assist is a Premium feature',
              ),
            ),
          ),
        ),
        // NEW: CPM Calculator quick action (free)
        _QuickButton(
          icon: Icons.calculate_outlined,
          label: 'CPM Calculator',
          onTap: () => _openCpmCalculator(context),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PremiumBadgeRow extends StatelessWidget {
  final String text;
  const _PremiumBadgeRow({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.workspace_premium, color: Colors.amber),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _OverviewGrid extends ConsumerStatefulWidget {
  const _OverviewGrid();
  @override
  ConsumerState<_OverviewGrid> createState() => _OverviewGridState();
}

class _OverviewGridState extends ConsumerState<_OverviewGrid> {
  DashboardRange _range = DashboardRange.today();
  late Future<DashboardKpis?> _future;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<DashboardKpis?> _fetch() async {
    final res = await ref.read(kpiServiceProvider).fetchKpis(range: _range);
    setState(() => _lastUpdated = DateTime.now());
    return res;
  }

  void _setRange(DashboardRange r) {
    setState(() {
      _range = r;
      _future = _fetch();
    });
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: _range.start, end: _range.end),
    );
    if (res != null) {
      _setRange(DashboardRange(start: res.start, end: res.end));
    }
  }

  String _rangeLabel() {
    final s = _range.start;
    final e = _range.end;
    if (s.year == e.year && s.month == e.month && s.day == e.day) {
      return 'Today';
    }
    final days = e.difference(s).inDays + 1;
    if (days == 7) {
      return 'Last 7d';
    }
    if (days == 30) {
      return 'Last 30d';
    }
    return '${s.month}/${s.day}/${s.year} – ${e.month}/${e.day}/${e.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Today'),
              selected: _rangeLabel() == 'Today',
              onSelected: (_) => _setRange(DashboardRange.today()),
            ),
            ChoiceChip(
              label: const Text('Last 7d'),
              selected: _rangeLabel() == 'Last 7d',
              onSelected: (_) => _setRange(DashboardRange.lastDays(7)),
            ),
            ChoiceChip(
              label: const Text('Last 30d'),
              selected: _rangeLabel() == 'Last 30d',
              onSelected: (_) => _setRange(DashboardRange.lastDays(30)),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: const Text('Custom'),
              onPressed: () => _pickCustomRange(context),
            ),
            if (_lastUpdated != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Last updated: ${_timeAgo(_lastUpdated!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<DashboardKpis?>(
          future: _future,
          builder: (context, snap) {
            final kpis = snap.data;
            return LayoutBuilder(
              builder: (context, c) {
                final isWide = c.maxWidth >= 800;
                final cross = isWide ? 4 : 2;
                String trendPct(num current, num prior) {
                  if (prior <= 0) return '—';
                  final pct = ((current - prior) / prior) * 100;
                  final arrow = pct >= 0 ? '▲' : '▼';
                  return '$arrow ${pct.abs().toStringAsFixed(0)}% vs prior';
                }

                final items = [
                  _StatTile(
                    title: 'Active Trucks',
                    value: kpis?.activeTrucks.toString() ?? '—',
                  ),
                  _StatTile(
                    title: 'Deliveries',
                    value: kpis?.deliveries.toString() ?? '—',
                    subtitle: kpis == null
                        ? null
                        : trendPct(kpis.deliveries, kpis.deliveriesPrior),
                  ),
                  _StatTile(
                    title: 'On-Time Rate',
                    value: kpis == null
                        ? '—'
                        : '${(kpis.onTimeRate * 100).toStringAsFixed(0)}%',
                    subtitle: kpis == null
                        ? null
                        : trendPct(kpis.onTimeRate, kpis.onTimeRatePrior),
                  ),
                  _StatTile(
                    title: 'Km',
                    value: kpis?.km.toStringAsFixed(0) ?? '—',
                    subtitle: kpis == null
                        ? null
                        : trendPct(kpis.km, kpis.kmPrior),
                  ),
                ];
                return GridView.count(
                  crossAxisCount: cross,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: items,
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  const _StatTile({required this.title, required this.value, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _GpsTrackerPlaceholder extends StatelessWidget {
  final VoidCallback onOpenMap;
  const _GpsTrackerPlaceholder({required this.onOpenMap});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Placeholder(fallbackHeight: 200),
        const SizedBox(height: 8),
        Row(
          children: [
            const _LegendDot(color: Colors.green, label: 'Moving'),
            const SizedBox(width: 12),
            const _LegendDot(color: Colors.amber, label: 'Idle'),
            const SizedBox(width: 12),
            const _LegendDot(color: Colors.grey, label: 'Offline'),
            const Spacer(),
            TextButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map),
              label: const Text('Open Live Map'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GpsTrackerWithFocus extends ConsumerStatefulWidget {
  final VoidCallback onOpenMap;
  const _GpsTrackerWithFocus({required this.onOpenMap});
  @override
  ConsumerState<_GpsTrackerWithFocus> createState() =>
      _GpsTrackerWithFocusState();
}

class _GpsTrackerWithFocusState extends ConsumerState<_GpsTrackerWithFocus> {
  final _driverCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _driverCtrl.dispose();
    super.dispose();
  }

  Future<void> _fire(String type) async {
    setState(() => _busy = true);
    try {
      final cfg = ref.read(appConfigProvider);
      if (cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty) {
        await withRetry(() => SupabaseSafe.runIfReady((c) => c.from('dispatch_events').insert({
          'event_type': type,
          'details': {'driver_id': _driverCtrl.text.trim()},
        })));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${type.replaceAll('_', ' ')} requested')),
        );
      }
    } catch (e, st) {
      app_log.AppLogger.warn('dispatch_events action failed', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to perform action now')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GpsTrackerPlaceholder(onOpenMap: widget.onOpenMap),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _driverCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Driver/Truck ID',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.center_focus_strong),
              label: const Text('Focus Driver'),
              onPressed: _busy ? null : () => _fire('focus_driver'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.timeline),
              label: const Text('Track Breadcrumb'),
              onPressed: _busy ? null : () => _fire('track_driver'),
            ),
          ],
        ),
      ],
    );
  }
}

// ===== Exceptions & Alerts Lane (scaffold) =====
class _ExceptionItem {
  final String id;
  final String title;
  final String severity; // critical|warning|info
  final DateTime ts;
  bool acknowledged;
  DateTime? snoozedUntil;
  String? assignee;
  _ExceptionItem({
    required this.id,
    required this.title,
    required this.severity,
    required this.ts,
    this.acknowledged = false,
    this.snoozedUntil,
    this.assignee,
  });
}

final _exceptionsProvider =
    StateNotifierProvider<_ExceptionsController, List<_ExceptionItem>>(
      (ref) => _ExceptionsController(ref),
    );

class _ExceptionsController extends StateNotifier<List<_ExceptionItem>> {
  _ExceptionsController(this._ref) : super(_seed());
  final Ref _ref;
  static List<_ExceptionItem> _seed() {
    final now = DateTime.now();
    return [
      _ExceptionItem(
        id: 'ex1',
        title: 'Load #123 at risk (ETA +32m)',
        severity: 'warning',
        ts: now.subtract(const Duration(minutes: 5)),
      ),
      _ExceptionItem(
        id: 'ex2',
        title: 'Truck TX-45 stalled ping 18m',
        severity: 'critical',
        ts: now.subtract(const Duration(minutes: 18)),
      ),
      _ExceptionItem(
        id: 'ex3',
        title: 'Geofence breach: DC-7',
        severity: 'warning',
        ts: now.subtract(const Duration(minutes: 9)),
      ),
    ];
  }

  void acknowledge(String id) {
    state = [
      for (final e in state)
        if (e.id == id)
          _ExceptionItem(
            id: e.id,
            title: e.title,
            severity: e.severity,
            ts: e.ts,
            acknowledged: true,
            snoozedUntil: e.snoozedUntil,
            assignee: e.assignee,
          )
        else
          e,
    ];
    _persist('exception_ack', {'id': id});
  }

  void snooze(String id, Duration dur) {
    final until = DateTime.now().add(dur);
    state = [
      for (final e in state)
        if (e.id == id)
          _ExceptionItem(
            id: e.id,
            title: e.title,
            severity: e.severity,
            ts: e.ts,
            acknowledged: e.acknowledged,
            snoozedUntil: until,
            assignee: e.assignee,
          )
        else
          e,
    ];
    _persist('exception_snoozed', {'id': id, 'for_min': dur.inMinutes});
  }

  void assign(String id, String assignee) {
    state = [
      for (final e in state)
        if (e.id == id)
          _ExceptionItem(
            id: e.id,
            title: e.title,
            severity: e.severity,
            ts: e.ts,
            acknowledged: e.acknowledged,
            snoozedUntil: e.snoozedUntil,
            assignee: assignee,
          )
        else
          e,
    ];
    _persist('exception_assigned', {'id': id, 'assignee': assignee});
  }

  Future<void> _persist(String type, Map<String, dynamic> details) async {
    try {
      final cfg = _ref.read(appConfigProvider);
      if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) return;
      await withRetry(() => SupabaseSafe.runIfReady((c) => c.from('dispatch_events').insert({
        'event_type': type,
        'details': details,
      })));
    } catch (e, st) { app_log.AppLogger.warn('persist dispatch_events failed', e, st); }
  }
}

class _ExceptionsLane extends ConsumerStatefulWidget {
  const _ExceptionsLane();
  @override
  ConsumerState<_ExceptionsLane> createState() => _ExceptionsLaneState();
}

class _ExceptionsLaneState extends ConsumerState<_ExceptionsLane> {
  String _filter = 'all'; // all|critical|warning|info
  @override
  Widget build(BuildContext context) {
    final items = ref.watch(_exceptionsProvider);
    final now = DateTime.now();
    final List<_ExceptionItem> list = items.where((e) {
      if (_filter != 'all' && e.severity != _filter) return false;
      if (e.snoozedUntil != null && e.snoozedUntil!.isAfter(now)) return false;
      return true;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _filter == 'all',
              onSelected: (_) => setState(() => _filter = 'all'),
            ),
            ChoiceChip(
              label: const Text('Critical'),
              selected: _filter == 'critical',
              onSelected: (_) => setState(() => _filter = 'critical'),
            ),
            ChoiceChip(
              label: const Text('Warning'),
              selected: _filter == 'warning',
              onSelected: (_) => setState(() => _filter = 'warning'),
            ),
            ChoiceChip(
              label: const Text('Info'),
              selected: _filter == 'info',
              onSelected: (_) => setState(() => _filter = 'info'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (list.isEmpty) const Text('No exceptions right now.'),
        for (final e in list)
          Card(
            child: ListTile(
              leading: Icon(
                e.severity == 'critical'
                    ? Icons.error
                    : e.severity == 'warning'
                    ? Icons.warning_amber
                    : Icons.info,
                color: e.severity == 'critical'
                    ? Colors.red
                    : e.severity == 'warning'
                    ? Colors.orange
                    : Colors.blue,
              ),
              title: Text(e.title),
              subtitle: Text(
                'Age: ${_age(e.ts)}${e.assignee == null ? '' : ' • Assigned to ${e.assignee}'}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'ack':
                      ref.read(_exceptionsProvider.notifier).acknowledge(e.id);
                      break;
                    case 'snooze15':
                      ref
                          .read(_exceptionsProvider.notifier)
                          .snooze(e.id, const Duration(minutes: 15));
                      break;
                    case 'snooze60':
                      ref
                          .read(_exceptionsProvider.notifier)
                          .snooze(e.id, const Duration(minutes: 60));
                      break;
                    case 'assign':
                      final a = await _promptAssign(context);
                      if (a != null) {
                        ref.read(_exceptionsProvider.notifier).assign(e.id, a);
                      }
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'ack', child: Text('Acknowledge')),
                  PopupMenuItem(
                    value: 'snooze15',
                    child: Text('Snooze 15 min'),
                  ),
                  PopupMenuItem(
                    value: 'snooze60',
                    child: Text('Snooze 60 min'),
                  ),
                  PopupMenuItem(value: 'assign', child: Text('Assign…')),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _age(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }

  Future<String?> _promptAssign(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assign follow-up'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Assignee'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _LoadsListPlaceholder extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadsSvc = ref.read(loadsServiceProvider);
    return FutureBuilder<List<LoadItem>>(
      future: loadsSvc.listLoads(),
      builder: (context, snap) {
        final items = snap.data ?? const <LoadItem>[];
        if (items.isEmpty) {
          // Fallback placeholder when no data
          return Column(
            children: List.generate(
              3,
              (i) => ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text('Load #${1000 + i} — Origin → Destination'),
                subtitle: const Text('Driver: —   Status: —'),
                trailing: TextButton(
                  onPressed: () => _assignDialog(context, ref, null),
                  child: const Text('Assign'),
                ),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final l in items)
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text('${l.origin} → ${l.destination}'),
                subtitle: Text(
                  'Pickup ${l.pickupAt.toLocal()} • Status: ${l.status}',
                ),
                trailing: TextButton(
                  onPressed: () => _assignDialog(context, ref, l.id),
                  child: const Text('Assign'),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _assignDialog(
    BuildContext context,
    WidgetRef ref,
    String? loadId,
  ) async {
    final ctrl = TextEditingController();
    final driver = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Assign Driver'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Driver User ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dctx,
              ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (driver == null) return;
    try {
      final loadsSvc = ref.read(loadsServiceProvider);
      if (loadId != null) {
        await loadsSvc.assignDriver(loadId: loadId, driverUserId: driver);
      } else {
        // If we don't have a real load id (placeholder), just log event
        final cfg = ref.read(appConfigProvider);
        if (cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty) {
          await Supabase.instance.client.from('dispatch_events').insert({
            'event_type': 'assign_driver_clicked',
            'details': {'driver_id': driver},
          });
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assigned successfully')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to assign (check connection)')),
        );
      }
    }
  }
}

// ---- Mock HOS provider for driver list ----
class _HosMiniState {
  final String duty;
  final int drivingMin;
  final int shiftMin;
  final DateTime lastLog;
  const _HosMiniState(this.duty, this.drivingMin, this.shiftMin, this.lastLog);
}

final _hosMiniProvider = Provider<List<_HosMiniState>>((ref) {
  final now = DateTime.now();
  return [
    _HosMiniState(
      'Driving',
      130,
      300,
      now.subtract(const Duration(minutes: 2)),
    ),
    _HosMiniState('On-duty', 75, 240, now.subtract(const Duration(minutes: 7))),
    _HosMiniState(
      'Off-duty',
      480,
      600,
      now.subtract(const Duration(minutes: 22)),
    ),
    _HosMiniState(
      'Sleeper',
      460,
      590,
      now.subtract(const Duration(minutes: 50)),
    ),
  ];
});

Color _hosColorFor(int drivingMin) {
  if (drivingMin > 120) return Colors.green;
  if (drivingMin >= 60) return Colors.amber;
  return Colors.red;
}

String _fmtMin(int m) {
  final h = m ~/ 60;
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h:${mm}h';
}

class _DriversListPlaceholder extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hos = ref.watch(_hosMiniProvider);
    return Column(
      children: List.generate(hos.length, (i) {
        final h = hos[i];
        final color = _hosColorFor(h.drivingMin);
        final stale = DateTime.now().difference(h.lastLog).inMinutes > 15;
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text('Driver ${i + 1}'),
          subtitle: Row(
            children: [
              Chip(label: Text(h.duty)),
              const SizedBox(width: 6),
              Chip(
                label: Text('Drive ${_fmtMin(h.drivingMin)}'),
                backgroundColor: color.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 6),
              Chip(label: Text('Shift ${_fmtMin(h.shiftMin)}')),
              if (stale) const SizedBox(width: 6),
              if (stale)
                const Chip(
                  label: Text('Stale'),
                  backgroundColor: Colors.orangeAccent,
                ),
            ],
          ),
          trailing: Tooltip(
            message: 'Last log ${h.lastLog.toLocal()}',
            child: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Chat',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat coming soon')),
                  ),
                ),
                IconButton(
                  tooltip: 'Call',
                  icon: const Icon(Icons.phone_outlined),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Call coming soon')),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ComplianceFreePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.rule_folder_outlined),
          title: Text('HOS & ELD Logs'),
          subtitle: Text('View logs • Review HOS violations'),
        ),
        ListTile(
          leading: Icon(Icons.folder_shared_outlined),
          title: Text('Driver Files'),
          subtitle: Text('CDL, medical, certifications'),
        ),
      ],
    );
  }
}

class _DispatcherAdsBanner extends StatelessWidget {
  const _DispatcherAdsBanner();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade50,
      child: const ListTile(
        leading: Icon(Icons.campaign),
        title: Text('Sponsored: Tools for Dispatchers'),
        subtitle: Text('Upgrade to Dispatcher Pro to remove ads.'),
        trailing: Icon(Icons.chevron_right),
      ),
    );
  }
}

class _TeamCommsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.campaign_outlined),
          title: Text('Announcements'),
          subtitle: Text('Broadcast fleet notices'),
          trailing: Icon(Icons.chevron_right),
        ),
        ListTile(
          leading: Icon(Icons.chat_outlined),
          title: Text('Driver Chat'),
          subtitle: Text('Conversations and load notes'),
          trailing: Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

Future<void> _createLoadDialog(BuildContext context, WidgetRef ref) async {
  final origin = TextEditingController();
  final dest = TextEditingController();
  DateTime pick = DateTime.now().add(const Duration(hours: 6));
  DateTime drop = pick.add(const Duration(hours: 24));
  Future<void> pickDate(bool isPickup) async {
    final init = isPickup ? pick : drop;
    final res = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (res != null) {
      if (isPickup) {
        pick = DateTime(res.year, res.month, res.day, pick.hour);
      } else {
        drop = DateTime(res.year, res.month, res.day, drop.hour);
      }
    }
  }

  final ok =
      await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Create Load'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: origin,
                decoration: const InputDecoration(labelText: 'Origin'),
              ),
              TextField(
                controller: dest,
                decoration: const InputDecoration(labelText: 'Destination'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => pickDate(true),
                    child: const Text('Pickup Date'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => pickDate(false),
                    child: const Text('Drop Date'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ) ??
      false;
  if (!ok) return;
  try {
    final svc = ref.read(loadsServiceProvider);
    final item = await svc.createLoad(
      origin: origin.text.trim(),
      destination: dest.text.trim(),
      pickupAt: pick,
      dropoffAt: drop,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created load ${item.id}')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to create load')));
    }
  }
}

Future<void> _importCsvDialog(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController(
    text:
        'origin,destination,pickup_utc,dropoff_utc\nDallas, TX,2025-09-03T12:00:00Z,2025-09-04T12:00:00Z',
  );
  final ok =
      await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Import Loads CSV (MVP)'),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: ctrl,
              maxLines: 10,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ??
      false;
  if (!ok) return;
  int success = 0, failed = 0;
  try {
    final svc = ref.read(loadsServiceProvider);
    final lines = ctrl.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    // Skip header row if present
    final rows = lines.skip(1);
    for (final r in rows) {
      final cols = r.split(',');
      try {
        if (cols.length < 4) throw Exception('Not enough columns');
        final item = await svc.createLoad(
          origin: cols[0].trim(),
          destination: cols[1].trim(),
          pickupAt: DateTime.parse(cols[2].trim()),
          dropoffAt: DateTime.parse(cols[3].trim()),
        );
        success++;
        // Log import
        try {
          final cfg = ref.read(appConfigProvider);
          if (cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty) {
            await SupabaseSafe.runIfReady((c) => c.from('import_logs').insert({
              'kind': 'loads_csv',
              'row_text': r,
              'status': 'ok',
              'details': {'load_id': item.id},
            }));
          }
        } catch (_) {}
      } catch (e) {
        failed++;
        try {
          final cfg = ref.read(appConfigProvider);
          if (cfg.supabaseUrl.isNotEmpty && cfg.supabaseAnonKey.isNotEmpty) {
            await SupabaseSafe.runIfReady((c) => c.from('import_logs').insert({
              'kind': 'loads_csv',
              'row_text': r,
              'status': 'error',
              'details': {'error': e.toString()},
            }));
          }
        } catch (_) {}
      }
    }
  } catch (_) {}
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Import complete: $success ok, $failed failed')),
    );
  }
}


// NEW: Simple CPM calculator dialog (scratch-pad, no persistence)
Future<void> _openCpmCalculator(BuildContext context) async {
  final milesCtrl = TextEditingController();
  final revenueCtrl = TextEditingController();
  final fuelCtrl = TextEditingController();
  final tollsCtrl = TextEditingController();
  final otherCtrl = TextEditingController();

  double p(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0.0;

  await showDialog<void>(
    context: context,
    builder: (dctx) {
      double? cpm, cpmNet;
      return StatefulBuilder(
        builder: (ctx, setState) {
          void recalc() {
            final miles = p(milesCtrl);
            final rev = p(revenueCtrl);
            final fuel = p(fuelCtrl);
            final tolls = p(tollsCtrl);
            final other = p(otherCtrl);
            cpm = miles > 0 ? (rev / miles) : null;
            final net = rev - (fuel + tolls + other);
            cpmNet = miles > 0 ? (net / miles) : null;
            setState(() {});
          }

          InputDecoration dec(String l) =>
              InputDecoration(labelText: l, isDense: true);

          return AlertDialog(
            title: const Text('Cost Per Mile Calculator'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: milesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: dec('Miles'),
                    onChanged: (_) => recalc(),
                  ),
                  TextField(
                    controller: revenueCtrl,
                    keyboardType: TextInputType.number,
                    decoration: dec('Revenue (USD)'),
                    onChanged: (_) => recalc(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fuelCtrl,
                          keyboardType: TextInputType.number,
                          decoration: dec('Fuel (USD)'),
                          onChanged: (_) => recalc(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: tollsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: dec('Tolls (USD)'),
                          onChanged: (_) => recalc(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherCtrl,
                    keyboardType: TextInputType.number,
                    decoration: dec('Other Expenses (USD)'),
                    onChanged: (_) => recalc(),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CPM: ${cpm == null ? '—' : '\$${cpm!.toStringAsFixed(2)}'}'),
                        Text('Net CPM: ${cpmNet == null ? '—' : '\$${cpmNet!.toStringAsFixed(2)}'}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}

// NEW: Placeholder widget for diagnostics + ELD until integrations are wired
class _DiagnosticsAndEldPlaceholder extends StatelessWidget {
  const _DiagnosticsAndEldPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.memory_outlined),
          title: Text('Engine DTCs'),
          subtitle: Text('No active faults • Last scan: —'),
        ),
        ListTile(
          leading: Icon(Icons.directions_car_filled_outlined),
          title: Text('Driver Behavior'),
          subtitle: Text('Scores: speeding, harsh brake/accel • Last 7d'),
        ),
        ListTile(
          leading: Icon(Icons.rule_folder_outlined),
          title: Text('HOS/ELD Logs'),
          subtitle: Text('View logs • Violations summary • Edits audit trail'),
        ),
      ],
    );
  }
}


// NEW: Simple partners list dialog for ELD integrations (placeholder)
class _EldPartnersListDialog extends StatelessWidget {
  const _EldPartnersListDialog();

  @override
  Widget build(BuildContext context) {
    final partners = const [
      'Geotab',
      'Samsara',
      'Motive / KeepTruckin',
      'Verizon Connect',
      'Trimble',
    ];
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose a provider to connect (informational only):'),
          const SizedBox(height: 8),
          ...partners.map((p) => ListTile(
                leading: const Icon(Icons.link_outlined),
                title: Text(p),
                subtitle: const Text('Integration coming soon'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connecting to $p (stub)')),
                  );
                },
              )),
        ],
      ),
    );
  }
}
