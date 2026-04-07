import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/gating/feature_gate.dart';
import '../../common/services/loads_service.dart';
import '../../common/state/session_provider.dart';
import '../../common/utils/retry.dart';
import '../../core/flags/rollout_flags.dart';
import '../../features/matching/backhaul/backhaul_service.dart';
import '../../services/roaddogg_service.dart';
import '../../services/supa_client.dart';
import '../../services/tracking_link_service.dart';
import '../broker/bid_assist/bid_assist_panel.dart';
import '../drivers/driver_picker_sheet.dart';
import '../fleet/loads/roaddogg_match_screen.dart';
import '../paywall/paywall_card.dart';
import 'edit_loads_financials_sheet.dart';

class LoadDetailsScreen extends ConsumerStatefulWidget {
  final String loadId;
  const LoadDetailsScreen({super.key, required this.loadId});

  @override
  ConsumerState<LoadDetailsScreen> createState() => _LoadDetailsScreenState();
}

class _LoadDetailsScreenState extends ConsumerState<LoadDetailsScreen> {
  Future<void> _shareTrackingForLoad(
    BuildContext context,
    String loadId,
  ) async {
    final svc = TrackingLinkService(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON') != ''
          ? const String.fromEnvironment('SUPABASE_ANON')
          : const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
    try {
      final token = await svc.ensureTokenForLoad(loadId);
      if (!context.mounted) return;
      if (token == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to create tracking link')),
          );
        }
        return;
      }
      final url = 'https://yourapp.com/#/track?token=$token';
      await Share.share('Track this shipment: $url');
      await FlutterClipboard.copy(url);
      if (!context.mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tracking link copied')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  LoadItem? _load;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(loadsServiceProvider);
      _load = await svc.getLoad(widget.loadId);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDriverPicker() async {
    final picked = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const DriverPickerSheet(),
    );
    if (picked == null) return;
    // Support either a simple Map or a typed driver with id/userId
    String? id;
    if (picked is Map) {
      final m = Map<String, dynamic>.from(picked);
      id = (m['id'] as String?) ?? (m['userId'] as String?);
    } else {
      // Best-effort: use .toJson() if available
      try {
        // ignore: avoid_dynamic_calls
        final json = (picked as dynamic).toJson() as Map<String, dynamic>;
        id = (json['id'] as String?) ?? (json['userId'] as String?);
      } catch (_) {}
    }
    if (id == null) return;
    await _assignDriverId(id);
  }

  Future<void> _assignDriverId(String driverUserId) async {
    final svc = ref.read(loadsServiceProvider);
    try {
      await svc.assignDriver(loadId: widget.loadId, driverUserId: driverUserId);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Driver assigned')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Assign failed: $e')));
      }
    }
  }

  Future<void> _setStatus(String status) async {
    final svc = ref.read(loadsServiceProvider);
    try {
      await svc.updateStatus(
        loadId: widget.loadId,
        status: status,
        idempotencyKey: 'st_${widget.loadId}_$status',
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  Future<void> _openFinancials() async {
    if (_load == null) return;
    final l = _load!;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditLoadFinancialsSheet(
        loadId: l.id,
        revenueCents: l.revenueCents,
        fuelCents: l.fuelCents,
        tollsCents: l.tollsCents,
        maintenanceCents: l.maintenanceCents,
        wageCents: l.wageCents,
      ),
    );
    if (ok == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = _load;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Load Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.attach_money),
            tooltip: 'Edit financials',
            onPressed: _loading ? null : _openFinancials,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
          IconButton(
            tooltip: 'Share Tracking Link',
            icon: const Icon(Icons.link),
            onPressed: _loading
                ? null
                : () => _shareTrackingForLoad(context, widget.loadId),
          ),
          IconButton(
            tooltip: 'Roaddogg',
            icon: const Icon(Icons.pets),
            onPressed: _loading
                ? null
                : () {
                    final url = const String.fromEnvironment('SUPABASE_URL');
                    final key = const String.fromEnvironment('SUPABASE_ANON') != ''
                        ? const String.fromEnvironment('SUPABASE_ANON')
                        : const String.fromEnvironment('SUPABASE_ANON_KEY');
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoaddoggMatchScreen(
                          rd: RoaddoggService(
                            SupaClient(supabaseUrl: url, anonKey: key),
                          ),
                          loadId: widget.loadId,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : l == null
          ? const Center(child: Text('Not found'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text('${l.origin} → ${l.destination}'),
                    subtitle: Text(
                      'Pickup: ${l.pickupAt.toLocal()} • Drop: ${l.dropoffAt.toLocal()}',
                    ),
                    trailing: Chip(label: Text(l.status)),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Assigned Driver'),
                    subtitle: Text(l.assignedDriverId ?? '—'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.person_search),
                          label: const Text('Pick Driver'),
                          onPressed: _openDriverPicker,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // AI Match Drivers panel
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _AiMatchGate(
                        child: _AiMatchDriversInline(
                          loadId: widget.loadId,
                          onAssign: _assignDriverId,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Market Rate Benchmark
                  const SizedBox(height: 12),
                  FutureBuilder<bool>(
                    future: FeatureGate.has('roi'),
                    builder: (context, snap) {
                      final allowed = snap.data == true;
                      if (!allowed) {
                        FeatureGate.logPaywall('roi');
                        return const PaywallCard(
                          title: 'Market Benchmark (Pro)',
                          description:
                              'Unlock market average and forecast to price faster.',
                        );
                      }
                      return _MarketRateBenchmark(load: l);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Bid Assist (inline)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('Bid Assist'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.85,
                                  child: BidAssistPanel(
                                    props: BidAssistPanelProps(
                                      origin: l.origin,
                                      destination: l.destination,
                                      equipment: l.vehicleType ?? 'dry van',
                                      pickupAt: l.pickupAt.toUtc(),
                                      loadId: l.id,
                                      isPremium: ref.read(sessionProvider).isPremium,
                                      onApply: (v) {
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Backhaul suggestions (compact)
                  _BackhaulSuggestionsCompact(
                    current: l,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _setStatus('in_transit'),
                        child: const Text('Mark In Transit'),
                      ),
                      ElevatedButton(
                        onPressed: () => _setStatus('delivered'),
                        child: const Text('Mark Delivered'),
                      ),
                      TextButton(
                        onPressed: () => _setStatus('canceled'),
                        child: const Text('Cancel Load'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _AiMatchGate extends StatelessWidget {
  final Widget child;
  const _AiMatchGate({required this.child});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: FeatureGate.has('ai_match'),
      builder: (context, snap) {
        final allowed = snap.data == true;
        if (!allowed) {
          FeatureGate.logPaywall('ai_match');
          return const PaywallCard(
            title: 'AI Match (Pro)',
            description:
                'Unlock AI driver matching with rationale and scoring.',
          );
        }
        return child;
      },
    );
  }
}

class _AiMatchDriversInline extends StatefulWidget {
  final String loadId;
  final Future<void> Function(String driverUserId) onAssign;
  const _AiMatchDriversInline({required this.loadId, required this.onAssign});

  @override
  State<_AiMatchDriversInline> createState() => _AiMatchDriversInlineState();
}

class _AiMatchDriversInlineState extends State<_AiMatchDriversInline> {
  bool _busy = false;
  List<_AiResult> _results = const [];

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      // retry invoke with small backoff
      final res = await retry(
        () => client.functions
            .invoke('ai_matchmaker', body: {'load_id': widget.loadId})
            .timeout(const Duration(seconds: 10)),
      );
      final data = res.data is Map ? res.data as Map : {};
      final list = (data['results'] as List? ?? [])
          .cast<Map>()
          .map(
            (e) => _AiResult(
              driverUserId: e['driver_user_id'] as String,
              score: (e['score'] as num).toDouble(),
              rationale: e['rationale'] as String? ?? '',
            ),
          )
          .toList();
      setState(() => _results = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI match timed out or failed. Please try again.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _busy ? () {} : _run,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _busy ? null : _run,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_busy ? 'Matching…' : 'AI Match Drivers'),
        ),
        if (_results.isNotEmpty) const SizedBox(height: 8),
        if (_results.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _results.map((m) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline),
                title: Text(m.driverUserId),
                subtitle: Text(m.rationale),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      m.score.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    OutlinedButton(
                      onPressed: () => widget.onAssign(m.driverUserId),
                      child: const Text('Assign'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _BackhaulSuggestionsCompact extends ConsumerStatefulWidget {
  final LoadItem current;
  const _BackhaulSuggestionsCompact({required this.current});
  @override
  ConsumerState<_BackhaulSuggestionsCompact> createState() => _BackhaulSuggestionsCompactState();
}

class _BackhaulSuggestionsCompactState extends ConsumerState<_BackhaulSuggestionsCompact> {
  bool _busy = false;
  List<BackhaulItem> _items = const [];
  String? _error;
  int _radius = 100;

  Future<void> _load({int? radiusOverride}) async {
    final flags = ref.read(rolloutFlagsProvider);
    if (!flags.backhaulV1Enabled) return;
    setState(() { _busy = true; _error = null; });
    try {
      final svc = ref.read(backhaulServiceProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final l = widget.current;
      final items = await svc.suggest(
        userId: userId,
        currentLoadId: l.id,
        dropoffLat: l.originLat ?? 0, // if dropoff lat/lng stored elsewhere, swap; fallback to 0
        dropoffLng: l.originLon ?? 0,
        dropoffEta: l.dropoffAt,
        equipment: l.vehicleType,
        searchRadiusMi: radiusOverride ?? _radius,
      );
      setState(() {
        _items = items;
        _radius = radiusOverride ?? _radius;
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final flags = ref.watch(rolloutFlagsProvider);
    if (!flags.backhaulV1Enabled) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.u_turn_left_outlined),
                const SizedBox(width: 8),
                const Text('Backhaul suggestions', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _busy ? null : () => _load(),
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('$_error', style: const TextStyle(color: Colors.red)),
              ),
            if (_items.isEmpty && _error == null && !_busy)
              Row(
                children: [
                  const Expanded(child: Text('No strong backhauls — try expanding radius.')),
                  TextButton(
                    onPressed: () => _load(radiusOverride: _radius + 50),
                    child: Text('Expand +50mi (to ${_radius + 50})'),
                  ),
                ],
              ),
            if (_items.isNotEmpty)
              Column(
                children: [
                  for (final it in _items.take(2)) _BackhaulRow(it: it),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        builder: (_) => _BackhaulSheet(items: _items.take(10).toList()),
                        isScrollControlled: true,
                      ),
                      child: const Text('See more'),
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

class _BackhaulRow extends StatelessWidget {
  final BackhaulItem it;
  const _BackhaulRow({required this.it});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.local_shipping_outlined),
      title: Text('${it.origin} → ${it.dest}'),
      subtitle: Text('CPM ${it.cpmEst.toStringAsFixed(2)} • Deadhead ${it.deadheadMi.toStringAsFixed(0)} mi • ${it.etaFit ? 'ETA fit' : 'Tight'} • ΔCPH ~\$${it.incrementalCph.toStringAsFixed(0)}'),
    );
  }
}

class _BackhaulSheet extends StatelessWidget {
  final List<BackhaulItem> items;
  const _BackhaulSheet({required this.items});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Top backhauls', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) => _BackhaulRow(it: items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketRateBenchmark extends StatelessWidget {
  final LoadItem load;
  const _MarketRateBenchmark({required this.load});
  @override
  Widget build(BuildContext context) {
    // Minimal placeholder: in a full impl, query market rate service
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Benchmark',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Lane: ${load.origin} → ${load.destination}'),
            const SizedBox(height: 4),
            const Text('Avg PPM: —  •  7d Trend: —'),
          ],
        ),
      ),
    );
  }
}

class _AiResult {
  final String driverUserId;
  final double score;
  final String rationale;
  _AiResult({
    required this.driverUserId,
    required this.score,
    required this.rationale,
  });
}
