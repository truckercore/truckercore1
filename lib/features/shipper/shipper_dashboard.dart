import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/widgets/app_background.dart';
import '../../widgets/state/async_state_widgets.dart';
import '../pricing/market_rates_service.dart';
import 'shipper_service.dart';

/// Shipper portal shell with nested Navigator and scrollable NavigationRail.
class ShipperDashboardScreen extends ConsumerWidget {
  const ShipperDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_roaddogg_shipper',
        icon: Builder(builder: (context){
          final b = Theme.of(context).brightness;
          return SizedBox(width:24,height:24, child: SvgPicture.asset(b==Brightness.dark ? 'assets/roaddogg/roaddogg_mark_light.svg' : 'assets/roaddogg/roaddogg_mark_dark.svg'));
        }),
        label: const Text('RoadDogg'),
        onPressed: () => context.push('/roaddogg'),
      ),
      appBar: AppBar(title: const Text('Shipper')),
      body: AppBackground(child: _ShipperShell()),
    );
  }
}

final GlobalKey<NavigatorState> _shipperShellNavKey = GlobalKey<NavigatorState>();

class _ShipperShell extends StatefulWidget {
  @override
  State<_ShipperShell> createState() => _ShipperShellState();
}

class _ShipperShellState extends State<_ShipperShell> {
  int _selected = 0;

  bool get _shouldUseDrawer {
    final h = MediaQuery.sizeOf(context).height;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return h < 560 || viewInsets > 0;
  }

  void _push(String route, {bool replace = false}) {
    if (replace) {
      _shipperShellNavKey.currentState?.pushReplacementNamed(route);
    } else {
      _shipperShellNavKey.currentState?.pushNamed(route);
    }
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    Widget screen;
    switch (settings.name) {
      case '/shipper/loads':
        screen = const _ShipperSection(title: 'Loads');
        break;
      case '/shipper/appointments':
        screen = const _ShipperSection(title: 'Appointments');
        break;
      case '/shipper/visibility':
        screen = const _ShipperSection(title: 'Visibility');
        break;
      case '/shipper/settings':
        screen = const _ShipperSection(title: 'Settings');
        break;
      case '/shipper/dashboard':
      default:
        screen = const _ShipperHome();
    }
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => PopScope(
        canPop: !(_shipperShellNavKey.currentState?.canPop() ?? false),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            final canPop = _shipperShellNavKey.currentState?.canPop() ?? false;
            if (canPop) {
              _shipperShellNavKey.currentState?.pop();
            }
          }
        },
        child: screen,
      ),
    );
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
                  _push('/shipper/dashboard', replace: true);
                  break;
                case 1:
                  _push('/shipper/loads');
                  break;
                case 2:
                  _push('/shipper/appointments');
                  break;
                case 3:
                  _push('/shipper/visibility');
                  break;
                case 4:
                  _push('/shipper/settings');
                  break;
              }
            },
            labelType: compact ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home_outlined), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.assignment_outlined), label: Text('Loads')),
              NavigationRailDestination(icon: Icon(Icons.event_outlined), label: Text('Appointments')),
              NavigationRailDestination(icon: Icon(Icons.visibility_outlined), label: Text('Visibility')),
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

    final row = Row(
      children: [
        if (!_shouldUseDrawer) rail else const SizedBox.shrink(),
        if (!_shouldUseDrawer) const VerticalDivider(width: 1),
        Expanded(
          child: Navigator(
            key: _shipperShellNavKey,
            initialRoute: '/shipper/dashboard',
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
              const DrawerHeader(child: Text('Shipper')),
              ListTile(leading: const Icon(Icons.home_outlined), title: const Text('Dashboard'), onTap: () { Navigator.pop(context); _push('/shipper/dashboard', replace: true); }),
              ListTile(leading: const Icon(Icons.assignment_outlined), title: const Text('Loads'), onTap: () { Navigator.pop(context); _push('/shipper/loads'); }),
              ListTile(leading: const Icon(Icons.event_outlined), title: const Text('Appointments'), onTap: () { Navigator.pop(context); _push('/shipper/appointments'); }),
              ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('Visibility'), onTap: () { Navigator.pop(context); _push('/shipper/visibility'); }),
              const Divider(),
              ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), onTap: () { Navigator.pop(context); _push('/shipper/settings'); }),
            ],
          ),
        ),
        body: row,
      );
    }
    return row;
  }
}

class _ShipperSection extends StatelessWidget {
  final String title;
  const _ShipperSection({required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shipper — $title')),
      body: AppBackground(
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$title (stub page) — content coming soon'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShipperHome extends ConsumerStatefulWidget {
  const _ShipperHome();
  @override
  ConsumerState<_ShipperHome> createState() => _ShipperHomeState();
}

class _ShipperHomeState extends ConsumerState<_ShipperHome> {
  // Home page content (existing dashboard)
  final _o = TextEditingController(text: '30301');
  final _d = TextEditingController(text: '75201');
  final _eq = TextEditingController(text: 'van');
  final DateTime _p = DateTime.now().add(const Duration(days: 1));
  final DateTime _dl = DateTime.now().add(const Duration(days: 3));
  final _rate = TextEditingController(text: '1200');
  bool _busy = false;
  double? _spot;
  double? _contract;
  int? _sample;
  @override
  void dispose() {
    _o.dispose();
    _d.dispose();
    _eq.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _hint() async {
    setState(() => _busy = true);
    try {
      final s = await ref
          .read(marketRatesServiceProvider)
          .getLaneRates(originZip: _o.text.trim(), destZip: _d.text.trim());
      setState(() {
        _spot = s.latestSpot;
        _contract = s.latestContract;
        _sample = s.sampleSize;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    final cents = ((double.tryParse(_rate.text.trim()) ?? 0) * 100).round();
    if (cents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter offered rate')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(shipperServiceProvider)
          .createLoad(
            originZip: _o.text.trim(),
            destZip: _d.text.trim(),
            equipment: _eq.text.trim(),
            pickupDate: _p,
            deliveryDate: _dl,
            offeredCents: cents,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Posted (mock).')));
      }
      setState(() => {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadsFut = ref.watch(shipperServiceProvider).listMyLoads();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipper Portal (Mock)'),
        actions: [
          IconButton(
            tooltip: 'RoadDogg Assistant',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.push('/roaddogg'),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Post Load',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _post,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.publish),
                          label: const Text('Post'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _hint,
                          icon: const Icon(Icons.trending_up),
                          label: const Text('Market hint'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final csvCtrl = TextEditingController();
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Bulk Post (CSV)'),
                                      content: SizedBox(
                                        width: 520,
                                        child: TextField(
                                          controller: csvCtrl,
                                          maxLines: 10,
                                          decoration: const InputDecoration(
                                            hintText:
                                                'origin,destination,pickup_at,dropoff_at,equipment_type,linehaul_cents,estimated_miles',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Upload'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    try {
                                      setState(() => _busy = true);
                                      final c = Supabase.instance.client;
                                      await c.functions.invoke(
                                        'shipper_bulk_post',
                                        body: {'csv': csvCtrl.text},
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Bulk posted'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Failed: $e')),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setState(() => _busy = false);
                                      }
                                    }
                                  }
                                },
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Bulk Post (CSV)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _o,
                            decoration: const InputDecoration(
                              labelText: 'Origin ZIP',
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _d,
                            decoration: const InputDecoration(
                              labelText: 'Dest ZIP',
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _eq,
                            decoration: const InputDecoration(
                              labelText: 'Equipment',
                              isDense: true,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _rate,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Offered USD',
                              isDense: true,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _busy ? null : _post,
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.publish),
                          label: const Text('Post'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _hint,
                          icon: const Icon(Icons.trending_up),
                          label: const Text('Market hint'),
                        ),
                        if (_spot != null)
                          Chip(
                            label: Text('Spot ${_spot!.toStringAsFixed(2)}/mi'),
                          ),
                        if (_contract != null)
                          Chip(
                            label: Text(
                              'Contract ${_contract!.toStringAsFixed(2)}/mi',
                            ),
                          ),
                        if (_sample != null)
                          Chip(label: Text('Sample: $_sample')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Loads',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder(
                      future: loadsFut,
                      builder: (context, snap) {
                                              if (snap.hasError) {
                                                return const AsyncErrorBanner(errorText: 'Failed to load loads');
                                              }
                        final items = snap.data ?? const <ShipperLoad>[];
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (items.isEmpty) {
                          return const EmptyPlaceholder(message: 'No loads yet.');
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final l = items[i];
                            return ListTile(
                              leading: const Icon(Icons.assignment_outlined),
                              title: Text(
                                '${l.originZip} → ${l.destZip} • ${l.equipment}',
                              ),
                              subtitle: Text(
                                'Pickup ${l.pickupDate.toLocal()} • Delivery ${l.deliveryDate.toLocal()} • Offered: \$${(l.offeredCents / 100).toStringAsFixed(0)} • ${l.status}',
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
