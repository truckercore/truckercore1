import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/models/app_role.dart';
import '../../common/state/combo_roles.dart';
import '../../common/state/phase2_flags.dart';
import '../../common/state/session_provider.dart';
import '../../common/telemetry/perf_tracing.dart';
import '../../common/widgets/app_background.dart';
import '../../common/widgets/role_badge.dart';
import '../../common/widgets/switch_role_menu.dart';
import '../../common/widgets/upgrade_card.dart';
import '../../core/flags/rollout_flags.dart';
import '../../core/formatters/time_format.dart';
import '../../services/ranker/ranker_service.dart';
import '../ai/trihaul_service.dart';
import '../alerts/alerts_drawer.dart';
import '../pricing/market_rates_service.dart';
import '../suggestions/explainability_chip.dart';
import '../vetting/vetting_service.dart';

class BrokerDashboardScreen extends ConsumerWidget {
  const BrokerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref
        .watch(sessionProvider)
        .isPremium; // treat premium as Broker Pro

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_roaddogg_broker',
        icon: Builder(builder: (context){
          final b = Theme.of(context).brightness;
          return SizedBox(width:24,height:24, child: SvgPicture.asset(b==Brightness.dark ? 'assets/roaddogg/roaddogg_mark_light.svg' : 'assets/roaddogg/roaddogg_mark_dark.svg'));
        }),
        label: const Text('RoadDogg'),
        onPressed: () => context.push('/roaddogg'),
      ),
      appBar: AppBar(
        title: const Text('Freight Broker Dashboard'),
        actions: [
          if (isPro)
            IconButton(
              tooltip: 'RoadDogg Assistant',
              icon: const Icon(Icons.smart_toy_outlined),
              onPressed: () => context.push('/roaddogg'),
            ),
          IconButton(
            tooltip: 'Verify Carrier',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => const _VettingSheet(),
              );
            },
          ),
          const AlertsBell(),
          const SizedBox(width: 8),
          const SwitchRoleMenu(),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: RoleBadge()),
          ),
        ],
      ),
      body: AppBackground(
        child: _BrokerShell(),
      ),
    );
  }
}

class _BrokerShell extends StatefulWidget {
  @override
  State<_BrokerShell> createState() => _BrokerShellState();
}

final GlobalKey<NavigatorState> _brokerShellNavKey = GlobalKey<NavigatorState>();

class _BrokerShellState extends State<_BrokerShell> {
  int _selected = 0;

  bool get _shouldUseDrawer {
    final h = MediaQuery.sizeOf(context).height;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return h < 560 || viewInsets > 0;
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget screen;
    switch (settings.name) {
      case '/broker/loads':
        screen = const BrokerSectionScreen(title: 'Loads');
        break;
      case '/broker/carriers':
        screen = const BrokerSectionScreen(title: 'Carriers & Drivers');
        break;
      case '/broker/matches':
        screen = const BrokerSectionScreen(title: 'Matches & Outreach');
        break;
      case '/broker/contracts':
        screen = const BrokerSectionScreen(title: 'Contracts & Docs');
        break;
      case '/broker/billing':
        screen = const BrokerSectionScreen(title: 'Billing & Invoices');
        break;
      case '/broker/analytics':
        screen = const BrokerSectionScreen(title: 'Analytics');
        break;
      case '/broker/messages':
        screen = const BrokerSectionScreen(title: 'Messages');
        break;
      case '/broker/marketplace':
        screen = const BrokerSectionScreen(title: 'Marketplace');
        break;
      case '/broker/settings':
        screen = const BrokerSectionScreen(title: 'Settings');
        break;
      case '/broker/dashboard':
      default:
        screen = const _BrokerHome();
    }
    return MaterialPageRoute(builder: (_) => PopScope(
      canPop: !(_brokerShellNavKey.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final canPop = _brokerShellNavKey.currentState?.canPop() ?? false;
          if (canPop) {
            _brokerShellNavKey.currentState?.pop();
          }
        }
      },
      child: screen,
    ), settings: settings);
  }

  void _push(String route, {bool replace = false}) {
    if (replace) {
      _brokerShellNavKey.currentState?.pushReplacementNamed(route);
    } else {
      _brokerShellNavKey.currentState?.pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final compact = height < 700;

    final rail = LayoutBuilder(
      builder: (context, constraints) {
        final railContent = IntrinsicHeight(
          child: NavigationRail(
            selectedIndex: _selected,
            onDestinationSelected: (i) {
              setState(() => _selected = i);
              switch (i) {
                case 0:
                  _push('/broker/dashboard', replace: true);
                  break;
                case 1:
                  _push('/broker/loads');
                  break;
                case 2:
                  _push('/broker/carriers');
                  break;
                case 3:
                  _push('/broker/matches');
                  break;
                case 4:
                  _push('/broker/contracts');
                  break;
                case 5:
                  _push('/broker/billing');
                  break;
                case 6:
                  _push('/broker/analytics');
                  break;
                case 7:
                  _push('/broker/messages');
                  break;
                case 8:
                  _push('/broker/marketplace');
                  break;
                case 9:
                  _push('/broker/settings');
                  break;
              }
            },
            labelType: compact ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.assignment_outlined), label: Text('Loads')),
              NavigationRailDestination(icon: Icon(Icons.badge_outlined), label: Text('Carriers & Drivers')),
              NavigationRailDestination(icon: Icon(Icons.lightbulb_outline), label: Text('Matches & Outreach')),
              NavigationRailDestination(icon: Icon(Icons.description_outlined), label: Text('Contracts & Docs')),
              NavigationRailDestination(icon: Icon(Icons.request_quote_outlined), label: Text('Billing & Invoices')),
              NavigationRailDestination(icon: Icon(Icons.analytics_outlined), label: Text('Analytics')),
              NavigationRailDestination(icon: Icon(Icons.chat_outlined), label: Text('Messages')),
              NavigationRailDestination(icon: Icon(Icons.public), label: Text('Marketplace')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), label: Text('Settings')),
            ],
          ),
        );
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: railContent,
          ),
        );
      },
    );

    final shellRow = Row(
      children: [
        if (!_shouldUseDrawer) rail else const SizedBox.shrink(),
        if (!_shouldUseDrawer) const VerticalDivider(width: 1),
        Expanded(
          child: Navigator(
            key: _brokerShellNavKey,
            initialRoute: '/broker/dashboard',
            onGenerateRoute: _onGenerateRoute,
          ),
        ),
      ],
    );

    if (_shouldUseDrawer) {
      return Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(child: Text('Broker')),
              ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Dashboard'), onTap: () { Navigator.pop(context); _push('/broker/dashboard', replace: true); }),
              ListTile(leading: const Icon(Icons.assignment_outlined), title: const Text('Loads'), onTap: () { Navigator.pop(context); _push('/broker/loads'); }),
              ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Carriers & Drivers'), onTap: () { Navigator.pop(context); _push('/broker/carriers'); }),
              ListTile(leading: const Icon(Icons.lightbulb_outline), title: const Text('Matches & Outreach'), onTap: () { Navigator.pop(context); _push('/broker/matches'); }),
              ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Contracts & Docs'), onTap: () { Navigator.pop(context); _push('/broker/contracts'); }),
              ListTile(leading: const Icon(Icons.request_quote_outlined), title: const Text('Billing & Invoices'), onTap: () { Navigator.pop(context); _push('/broker/billing'); }),
              ListTile(leading: const Icon(Icons.analytics_outlined), title: const Text('Analytics'), onTap: () { Navigator.pop(context); _push('/broker/analytics'); }),
              ListTile(leading: const Icon(Icons.chat_outlined), title: const Text('Messages'), onTap: () { Navigator.pop(context); _push('/broker/messages'); }),
              ListTile(leading: const Icon(Icons.public), title: const Text('Marketplace'), onTap: () { Navigator.pop(context); _push('/broker/marketplace'); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), onTap: () { Navigator.pop(context); _push('/broker/settings'); }),
            ],
          ),
        ),
        body: shellRow,
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_roaddogg_broker',
        icon: Builder(builder: (context){
          final b = Theme.of(context).brightness;
          return SizedBox(width:24,height:24, child: SvgPicture.asset(b==Brightness.dark ? 'assets/roaddogg/roaddogg_mark_light.svg' : 'assets/roaddogg/roaddogg_mark_dark.svg'));
        }),
        label: const Text('RoadDogg'),
        onPressed: () => context.push('/roaddogg'),
      ),
      body: shellRow,
    );
  }
}

class _BrokerHome extends ConsumerWidget {
  const _BrokerHome();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(sessionProvider).isPremium;
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderRow(isPro: isPro),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.arrow_right, size: 16),
                    Text('Dashboard', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 12),
                if (!isPro)
                  Card(
                    color: Colors.amber.shade50,
                    child: const ListTile(
                      leading: Icon(Icons.workspace_premium),
                      title: Text('Unlock AI matching & e-sign'),
                      subtitle: Text('Upgrade to Broker Pro (\$199/mo) to access premium tools.'),
                    ),
                  ),
                const SizedBox(height: 12),
                const _KpiRibbon(),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 1000;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: wide ? (c.maxWidth - 16) * 0.6 : c.maxWidth,
                          child: Column(
                            children: [
                              _SectionCard(title: 'Quick Post Load', subtitle: 'Draft a load in seconds', child: _QuickPostLoad(isPro: isPro)),
                              _SectionCard(title: 'Match Suggestions (AI)', subtitle: 'Top carriers by lane/equipment/HOS window + proximity', child: isPro ? const _MatchSuggestions() : UpgradeCard(title: 'AI matching (Broker Pro)', onUpgrade: () { ref.read(sessionProvider.notifier).setPremium(true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgraded to Broker Pro (demo).'))); })),
                              const _SectionCard(title: 'Rate Insights', subtitle: 'Market rate benchmarks by lane', child: _RateInsightsPanel()),
                              _SectionCard(title: 'AI TriHaul', subtitle: 'Suggest profitable 3-leg alternatives', child: isPro ? const _TrihaulPanel() : UpgradeCard(title: 'TriHaul (Broker Pro+)', onUpgrade: () { ref.read(sessionProvider.notifier).setPremium(true); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgraded to Broker Pro (demo).'))); })),
                              const _SectionCard(title: 'Exceptions Lane', subtitle: 'Expiring pickups, missing docs, declined offers', child: _ExceptionsStub()),
                              const _SectionCard(title: 'Compliance Snapshot', subtitle: 'Expiring COI, authority lapses, safety alerts', child: _ComplianceStub()),
                              const _SectionCard(title: 'HOS Verification', subtitle: 'Request DOT logs and verify contracted drivers', child: _HosVerifyStub()),
                              const _SectionCard(title: 'Billing Snapshot', subtitle: 'Draft invoices, unpaid aging, detention/accessorial review', child: _BillingStub()),
                              const _SectionCard(title: 'Load Activity Feed', subtitle: 'Quotes, counters, assignments, docs uploaded', child: _ActivityFeedStub()),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: wide ? (c.maxWidth - 16) * 0.4 : c.maxWidth,
                          child: const Column(
                            children: [
                              _SectionCard(title: 'Per-Load Messages', subtitle: 'Last active threads', child: _MessagesStub()),
                              _SectionCard(title: 'Saved Searches / Watchlists', subtitle: 'E.g., NJ→IL reefers, Fri pickups', child: _WatchlistsStub()),
                              _SectionCard(title: 'RoadDogg (Broker) Quick Prompts', subtitle: 'Rate guidance, benchmarks, shortlist drafts', child: _RoadDoggStub()),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends ConsumerWidget {
  final bool isPro;
  const _HeaderRow({required this.isPro});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avail = ref.watch(availableRolesProvider);
    final sessionCtrl = ref.read(sessionProvider.notifier);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        DropdownButton<AppRole>(
          value: ref.watch(sessionProvider).role,
          items: [
            for (final r in avail.roles)
              DropdownMenuItem(
                value: r,
                child: Text(
                  r == AppRole.fleetManager ? 'Carrier Mode' : r.name,
                ),
              ),
          ],
          onChanged: (r) {
            if (r != null) sessionCtrl.setRole(r, userChosen: true);
          },
        ),
        Chip(
          label: Text(
            ref.watch(sessionProvider).role == AppRole.fleetManager
                ? 'You are in Carrier Mode'
                : 'You are in Broker Mode',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.date_range),
          label: const Text('Today'),
        ),
        Text(
          'Last updated: just now',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Post Load'),
        ),
        OutlinedButton.icon(
          onPressed: () => GoRouter.of(context).push('/route-planning'),
          icon: const Icon(Icons.folder_open),
          label: const Text('📂 Route Planning'),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Invite Carrier'),
        ),
      ],
    );
  }
}

class _KpiRibbon extends StatefulWidget {
  const _KpiRibbon();
  @override
  State<_KpiRibbon> createState() => _KpiRibbonState();
}

class _KpiRibbonState extends State<_KpiRibbon> {
  // [DEBUG_LOG] KPI ribbon state; actions in dashboard can call these via a GlobalKey if needed
  int openLoads = 14;
  int docsPending = 5;
  String ratePerMi = '\$2.41';
  int fillRate = 92;
  int activeCarriers = 87;
  int ttaMedianMin = 28;
  void bumpForPostLoad() {
    setState(() => openLoads += 1);
  }

  void bumpForOffer() {
    setState(() => fillRate = (fillRate + 1).clamp(0, 100));
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String value) => Chip(
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
    final items = [
      chip('Open Loads', '$openLoads'),
      chip('Fill Rate (7d)', '$fillRate%'),
      chip('Avg Rate/mi', ratePerMi),
      chip('Time-to-Assign (median)', '${ttaMedianMin}m'),
      chip('Active Approved Carriers', '$activeCarriers'),
      chip('Docs Pending', '$docsPending'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                items.expand((w) => [w, const SizedBox(width: 8)]).toList()
                  ..removeLast(),
          ),
        ),
      ),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _QuickPostLoad extends StatelessWidget {
  final bool isPro;
  const _QuickPostLoad({required this.isPro});
  @override
  Widget build(BuildContext context) {
    final originCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final rpmCtrl = TextEditingController();
    final milesCtrl = TextEditingController();
    String equipment = 'dry_van';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: originCtrl,
          decoration: const InputDecoration(labelText: 'Origin', isDense: true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: destCtrl,
          decoration: const InputDecoration(
            labelText: 'Destination',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: equipment,
                items: const [
                  DropdownMenuItem(value: 'dry_van', child: Text('Dry Van')),
                  DropdownMenuItem(value: 'reefer', child: Text('Reefer')),
                  DropdownMenuItem(value: 'flatbed', child: Text('Flatbed')),
                ],
                onChanged: (v) {
                  equipment = v ?? equipment;
                },
                decoration: const InputDecoration(
                  labelText: 'Equipment',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: rpmCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rate USD/mi',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: TextField(
                controller: milesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Est. miles',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Post (draft)'),
            onPressed: () async {
              try {
                final c = Supabase.instance.client;
                final now = DateTime.now().toUtc();
                final rpm = double.tryParse(rpmCtrl.text.trim());
                final miles = int.tryParse(milesCtrl.text.trim());
                int revenueCents = 0;
                if (rpm != null && miles != null && miles > 0) {
                  revenueCents = (rpm * miles * 100).round();
                }
                await c
                    .from('loads')
                    .insert({
                      'origin': originCtrl.text.trim(),
                      'destination': destCtrl.text.trim(),
                      'pickup_at': now
                          .add(const Duration(days: 1))
                          .toIso8601String(),
                      'dropoff_at': now
                          .add(const Duration(days: 2))
                          .toIso8601String(),
                      'status': 'draft',
                      'assigned_driver_id': null,
                      if (revenueCents > 0) 'revenue_cents': revenueCents,
                      if (rpm != null) 'posted_rate_usd_per_mi': rpm,
                      if (miles != null) 'estimated_miles': miles,
                      'vehicle_type': equipment,
                    })
                    .select()
                    .single();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Load drafted.')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to draft (check connection)'),
                    ),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }
}

class _MatchSuggestions extends ConsumerStatefulWidget {
  const _MatchSuggestions();
  @override
  ConsumerState<_MatchSuggestions> createState() => _MatchSuggestionsState();
}

class _MatchSuggestionsState extends ConsumerState<_MatchSuggestions> {
  bool _loading = false;
  String? _error;
  String _equipment = 'van';
  double? _minCpm = 2.0;
  double _radius = 100; // mi
  List<({String id, String candidateId, int? trust, int? sla, List<String> reasons})> _items = const [];
  DateTime? _lastUpdated;

  Future<void> _load({bool revalidate = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = ref.read(rankerServiceProvider);
      final items = await svc.findRanked(
        input: QueryInput(
          query: 'lane match',
          filters: {
            if (_equipment.isNotEmpty) 'equipment': _equipment,
            if (_minCpm != null) 'min_cpm': _minCpm,
            'radius': _radius,
          },
        ),
      );
      setState(() {
        _items = items
            .map((s) => (id: s.id, candidateId: s.candidateId, trust: s.brokerTrustScore, sla: s.slaReplyMinutes, reasons: s.topReasons))
            .toList(growable: false);
        _lastUpdated = DateTime.now().toUtc();
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial load (cache-first behavior is handled in service)
    // ignore: discarded_futures
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(rolloutFlagsProvider);
    if (!flags.rankerV1Enabled) {
      return const ListTile(title: Text('AI suggestions disabled')); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: _equipment,
                    items: const [
                      DropdownMenuItem(value: 'van', child: Text('Dry Van')),
                      DropdownMenuItem(value: 'reefer', child: Text('Reefer')),
                      DropdownMenuItem(value: 'flatbed', child: Text('Flatbed')),
                    ],
                    onChanged: (v) => setState(() => _equipment = v ?? 'van'),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Min \$ / mi'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _minCpm = double.tryParse(v),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Radius mi'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _radius = double.tryParse(v) ?? _radius,
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                  if (_lastUpdated != null)
                    Text('Updated just now', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        if (kDebugMode) Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Builder(builder: (context) {
            final s = PerfTracer.instance.statsFor('ranker.search');
            final lastMs = s.last?.ms ?? 0;
            final cache = s.last?.cache ?? '-';
            Color? badge;
            if (lastMs > 1500) {
              badge = Colors.redAccent;
            } else if (lastMs > 1000) {
              badge = Colors.amberAccent;
            }
            return Row(
              children: [
                Text('p50/p95 recent: ${s.p50.toStringAsFixed(0)} / ${s.p95.toStringAsFixed(0)} ms • Last: $lastMs ms • cache: $cache', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Chip(label: const Text('SLOW'), backgroundColor: badge),
                ],
              ],
            );
          }),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Failed: \\u26A0\\uFE0F \\n$_error', style: const TextStyle(color: Colors.red)),
          ),
        if (_items.isEmpty && !_loading)
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() { _minCpm = (_minCpm ?? 2.0) - 0.25; });
                  _load();
                },
                child: const Text('Lower min CPM'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() { _radius += 50; });
                  _load();
                },
                child: const Text('Expand radius'),
              ),
            ],
          ),
        for (final it in _items)
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text('Candidate ${it.id}'),
            subtitle: ExplainabilityChips(reasons: it.reasons, dense: true),
            trailing: it.sla != null ? Text('Replies in ~${it.sla}m', style: const TextStyle(fontSize: 12)) : null,
          ),
      ],
    );
  }
}

class _ExceptionsStub extends StatelessWidget {
  const _ExceptionsStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.warning_amber),
          title: Text('Load #432 expiring pickup window'),
        ),
        ListTile(
          leading: Icon(Icons.hourglass_bottom),
          title: Text('Load #210 uncontacted > 30m'),
        ),
      ],
    );
  }
}

class _ComplianceStub extends StatelessWidget {
  const _ComplianceStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.rule_folder_outlined),
          title: Text('COI expiring soon (4)'),
        ),
        ListTile(
          leading: Icon(Icons.gavel_outlined),
          title: Text('Authority lapse risk (1)'),
        ),
      ],
    );
  }
}

class _VettingSheet extends ConsumerStatefulWidget {
  const _VettingSheet();
  @override
  ConsumerState<_VettingSheet> createState() => _VettingSheetState();
}

class _VettingSheetState extends ConsumerState<_VettingSheet> {
  final _dotCtrl = TextEditingController(text: '1234561');
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
          'Safety: ${data.rating}  •  Insurance exp: ${fmtDateTime(data.insuranceExp)}\nLast verified: ${fmtDateTime(data.last)}',
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

class _HosVerifyStub extends StatelessWidget {
  const _HosVerifyStub();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.verified_user_outlined),
          title: const Text('Request DOT logs'),
          trailing: ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('DOT log request sent (MVP).')),
            ),
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('Request'),
          ),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.person),
          title: Text('Driver: J. Smith'),
          subtitle: Text('Load #557'),
          trailing: Chip(
            label: Text('Verified HOS'),
            backgroundColor: Colors.greenAccent,
          ),
        ),
        const ListTile(
          leading: Icon(Icons.person),
          title: Text('Driver: A. Garcia'),
          subtitle: Text('Load #432'),
          trailing: Chip(
            label: Text('Pending'),
            backgroundColor: Colors.amberAccent,
          ),
        ),
      ],
    );
  }
}

class _TrihaulPanel extends ConsumerStatefulWidget {
  const _TrihaulPanel();
  @override
  ConsumerState<_TrihaulPanel> createState() => _TrihaulPanelState();
}

class _TrihaulPanelState extends ConsumerState<_TrihaulPanel> {
  final _orig = TextEditingController(text: 'ATL');
  final _dest = TextEditingController(text: 'DFW');
  bool _busy = false;
  List<String> _opts = const [];

  @override
  void dispose() {
    _orig.dispose();
    _dest.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(trihaulServiceProvider);
      final sug = await svc.suggest(
        origin: _orig.text.trim(),
        dest: _dest.text.trim(),
        equipment: 'van',
      );
      setState(() {
        _opts = sug.options.map((o) {
          final legs = o.legs.join(' • ');
          final mi = o.estMiles.toStringAsFixed(0);
          final rev = o.estRevenue.toStringAsFixed(0);
          final ppm = o.estPpm.toStringAsFixed(2);
          return '$legs — $mi mi • \$$rev • $ppm/mi';
        }).toList();
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
              width: 120,
              child: TextField(
                controller: _orig,
                decoration: const InputDecoration(
                  labelText: 'Origin',
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _dest,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  isDense: true,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _run,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Suggest'),
            ),
            if (ref.watch(phase2FlagsProvider).mock)
              const Chip(label: Text('Demo data')),
          ],
        ),
        const SizedBox(height: 6),
        if (_opts.isEmpty)
          const Text(
            'TriHaul finds profitable midpoints; verify appointment windows.',
          ),
        for (final s in _opts)
          ListTile(leading: const Icon(Icons.alt_route), title: Text(s)),
      ],
    );
  }
}

class _RateInsightsPanel extends ConsumerStatefulWidget {
  const _RateInsightsPanel();
  @override
  ConsumerState<_RateInsightsPanel> createState() => _RateInsightsPanelState();
}

class _RateInsightsPanelState extends ConsumerState<_RateInsightsPanel> {
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

class _BillingStub extends StatelessWidget {
  const _BillingStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.request_quote_outlined),
          title: Text('Draft invoices (3)'),
        ),
        ListTile(
          leading: Icon(Icons.toll_outlined),
          title: Text('Detention/accessorials to review (2)'),
        ),
      ],
    );
  }
}

class _ActivityFeedStub extends StatelessWidget {
  const _ActivityFeedStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(leading: Icon(Icons.history)),
        ListTile(title: Text('8:41 AM • Offer sent to Carrier A')),
        ListTile(title: Text('8:55 AM • Counteroffer received (\$2.52/mi)')),
        ListTile(title: Text('9:07 AM • Docs uploaded on Load #557')),
      ],
    );
  }
}

class _MessagesStub extends StatelessWidget {
  const _MessagesStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.chat_bubble_outline),
          title: Text('Load #557 • Carrier A'),
        ),
        ListTile(
          leading: Icon(Icons.chat_bubble_outline),
          title: Text('Load #432 • Carrier B'),
        ),
      ],
    );
  }
}

class _WatchlistsStub extends StatelessWidget {
  const _WatchlistsStub();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.bookmark_border),
          title: Text('NJ → IL reefers (Fri pickups)'),
        ),
        ListTile(
          leading: Icon(Icons.bookmark_border),
          title: Text('TX → CA flatbeds (Mon pickups)'),
        ),
      ],
    );
  }
}

class _RoadDoggStub extends ConsumerWidget {
  const _RoadDoggStub();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(sessionProvider).isPremium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.summarize_outlined),
              label: const Text('Summarize load'),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.message_outlined),
              label: const Text('Draft outreach'),
            ),
            if (isPro)
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.star),
                label: const Text('Top carriers today'),
              )
            else
              const Row(
                children: [
                  Icon(Icons.lock, size: 16),
                  SizedBox(width: 4),
                  Text('Upgrade for carrier shortlists'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// Generic broker section screen (stub) for routable pages
class BrokerSectionScreen extends StatelessWidget {
  final String title;
  const BrokerSectionScreen({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Freight Broker — $title'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: RoleBadge()),
          ),
        ],
      ),
      body: AppBackground(
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '$title (stub page) — navigation and content coming soon',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
